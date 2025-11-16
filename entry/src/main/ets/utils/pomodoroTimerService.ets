import { getStorageInstance } from './preferencesStorage';
import { NotificationService } from './notificationService';

/**
 * 番茄钟状态枚举
 */
export enum PomodoroState {
  IDLE = 'idle',
  FOCUSING = 'focusing',
  SHORT_BREAK = 'short_break',
  LONG_BREAK = 'long_break'
}

/**
 * 番茄钟设置接口
 */
export interface PomodoroSettings {
  focusDuration: number;     // 专注时长（分钟）
  shortBreakDuration: number; // 短休息时长（分钟）
  longBreakDuration: number;  // 长休息时长（分钟）
  longBreakInterval: number;  // 长休息间隔（几个专注钟后）
  autoStartBreak: boolean;    // 专注结束后自动开始休息
  autoStartFocus: boolean;    // 休息结束后自动开始专注
  enableSound: boolean;       // 启用声音提醒
  enableVibration: boolean;   // 启用震动提醒
}

/**
 * 番茄钟统计信息接口
 */
export interface PomodoroStats {
  completedToday: number;     // 今日完成番茄钟数量
  totalFocusTime: number;     // 总专注时间（分钟）
  currentStreak: number;      // 当前连续专注天数
  completedPomodoros: number; // 总完成番茄钟数量
}

/**
 * 番茄钟事件回调接口
 */
export interface PomodoroEventCallbacks {
  onTimerTick?: (remainingTime: number, totalTime: number) => void;
  onStateChange?: (newState: PomodoroState) => void;
  onPomodoroComplete?: (type: 'focus' | 'break') => void;
  onSessionComplete?: () => void;
}

/**
 * 番茄钟计时器服务类
 * 管理番茄钟的核心逻辑，包括计时、状态转换、设置管理等
 */
export class PomodoroTimerService {
  private static instance: PomodoroTimerService | null = null;

  private currentState: PomodoroState = PomodoroState.IDLE;
  private currentTimerId: number = -1;
  private remainingTime: number = 0;
  private completedPomodoros: number = 0;
  private currentSessionPomodoros: number = 0;

  private settings: PomodoroSettings = {
    focusDuration: 25,
    shortBreakDuration: 5,
    longBreakDuration: 15,
    longBreakInterval: 4,
    autoStartBreak: false,
    autoStartFocus: false,
    enableSound: true,
    enableVibration: true
  };

  private eventCallbacks: PomodoroEventCallbacks = {};
  private isPaused: boolean = false;
  private storage = getStorageInstance();
  private notificationService: NotificationService;
  private currentTask: string = ''; // 当前任务

  private constructor() {
    this.notificationService = NotificationService.getInstance();
    this.initializeData();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): PomodoroTimerService {
    if (!PomodoroTimerService.instance) {
      PomodoroTimerService.instance = new PomodoroTimerService();
    }
    return PomodoroTimerService.instance;
  }

  /**
   * 初始化数据
   */
  private async initializeData(): Promise<void> {
    try {
      await this.storage.initialize();
      await this.loadSettings();
      await this.loadStats();
    } catch (error) {
      console.error('PomodoroTimerService: Failed to initialize data', error);
    }
  }

  /**
   * 加载用户设置
   */
  private async loadSettings(): Promise<void> {
    try {
      this.settings = await this.storage.getObject('pomodoro_settings', this.settings);
      console.info('PomodoroTimerService: Settings loaded', JSON.stringify(this.settings));
    } catch (error) {
      console.error('PomodoroTimerService: Failed to load settings', error);
    }
  }

  /**
   * 保存用户设置
   */
  private async saveSettings(): Promise<void> {
    try {
      await this.storage.saveObject('pomodoro_settings', this.settings);
      console.info('PomodoroTimerService: Settings saved', JSON.stringify(this.settings));
    } catch (error) {
      console.error('PomodoroTimerService: Failed to save settings', error);
    }
  }

  /**
   * 加载统计信息
   */
  private async loadStats(): Promise<void> {
    try {
      // 获取今日日期
      const today = new Date().toDateString();
      const lastResetDate = await this.storage.getString('last_reset_date', '');

      // 如果是新的一天，重置今日统计
      if (lastResetDate !== today) {
        await this.resetTodayStats();
        await this.storage.saveString('last_reset_date', today);
      } else {
        this.completedPomodoros = await this.storage.getNumber('completed_today', 0);
      }

      console.info('PomodoroTimerService: Stats loaded');
    } catch (error) {
      console.error('PomodoroTimerService: Failed to load stats', error);
    }
  }

  /**
   * 保存统计信息
   */
  private async saveStats(): Promise<void> {
    try {
      await this.storage.saveNumber('completed_today', this.completedPomodoros);
      await this.storage.saveNumber('total_completed', this.completedPomodoros); // 简化实现
      console.info('PomodoroTimerService: Stats saved');
    } catch (error) {
      console.error('PomodoroTimerService: Failed to save stats', error);
    }
  }

  /**
   * 设置事件回调
   */
  setEventCallbacks(callbacks: PomodoroEventCallbacks): void {
    // 手动合并对象，避免使用spread语法
    if (callbacks.onTimerTick) {
      this.eventCallbacks.onTimerTick = callbacks.onTimerTick;
    }
    if (callbacks.onStateChange) {
      this.eventCallbacks.onStateChange = callbacks.onStateChange;
    }
    if (callbacks.onPomodoroComplete) {
      this.eventCallbacks.onPomodoroComplete = callbacks.onPomodoroComplete;
    }
    if (callbacks.onSessionComplete) {
      this.eventCallbacks.onSessionComplete = callbacks.onSessionComplete;
    }
  }

  /**
   * 触发事件回调
   */
  // 分别为每个事件定义方法
  private triggerOnTimerTick(remainingTime: number, totalTime: number): void {
    const callback = this.eventCallbacks.onTimerTick;
    if (callback) {
      callback(remainingTime, totalTime);
    }
  }

  private triggerOnStateChange(newState: PomodoroState): void {
    const callback = this.eventCallbacks.onStateChange;
    if (callback) {
      callback(newState);
    }
  }

  private triggerOnPomodoroComplete(type: 'focus' | 'break'): void {
    const callback = this.eventCallbacks.onPomodoroComplete;
    if (callback) {
      callback(type);
    }
  }

  private triggerOnSessionComplete(): void {
    const callback = this.eventCallbacks.onSessionComplete;
    if (callback) {
      callback();
    }
  }

  /**
   * 获取当前状态
   */
  getCurrentState(): PomodoroState {
    return this.currentState;
  }

  /**
   * 获取剩余时间（秒）
   */
  getRemainingTime(): number {
    return this.remainingTime;
  }

  /**
   * 获取当前状态的总时间（秒）
   */
  getTotalTime(): number {
    switch (this.currentState) {
      case PomodoroState.FOCUSING:
        return this.settings.focusDuration * 60;
      case PomodoroState.SHORT_BREAK:
        return this.settings.shortBreakDuration * 60;
      case PomodoroState.LONG_BREAK:
        return this.settings.longBreakDuration * 60;
      default:
        return 0;
    }
  }

  /**
   * 获取设置
   */
  getSettings(): PomodoroSettings {
    // 手动复制对象，避免使用spread语法
    return {
      focusDuration: this.settings.focusDuration,
      shortBreakDuration: this.settings.shortBreakDuration,
      longBreakDuration: this.settings.longBreakDuration,
      longBreakInterval: this.settings.longBreakInterval,
      autoStartBreak: this.settings.autoStartBreak,
      autoStartFocus: this.settings.autoStartFocus,
      enableSound: this.settings.enableSound,
      enableVibration: this.settings.enableVibration
    };
  }

  /**
   * 更新设置
   */
  async updateSettings(newSettings: Partial<PomodoroSettings>): Promise<void> {
    // 手动合并对象，避免使用spread语法
    if (newSettings.focusDuration !== undefined) {
      this.settings.focusDuration = newSettings.focusDuration;
    }
    if (newSettings.shortBreakDuration !== undefined) {
      this.settings.shortBreakDuration = newSettings.shortBreakDuration;
    }
    if (newSettings.longBreakDuration !== undefined) {
      this.settings.longBreakDuration = newSettings.longBreakDuration;
    }
    if (newSettings.longBreakInterval !== undefined) {
      this.settings.longBreakInterval = newSettings.longBreakInterval;
    }
    if (newSettings.autoStartBreak !== undefined) {
      this.settings.autoStartBreak = newSettings.autoStartBreak;
    }
    if (newSettings.autoStartFocus !== undefined) {
      this.settings.autoStartFocus = newSettings.autoStartFocus;
    }
    if (newSettings.enableSound !== undefined) {
      this.settings.enableSound = newSettings.enableSound;
    }
    if (newSettings.enableVibration !== undefined) {
      this.settings.enableVibration = newSettings.enableVibration;
    }

    await this.saveSettings();

    // 如果当前没有运行，重置时间以反映新设置
    if (this.currentState === PomodoroState.IDLE) {
      this.remainingTime = this.settings.focusDuration * 60;
    }
  }

  /**
   * 获取统计信息
   */
  getStats(): PomodoroStats {
    return {
      completedToday: this.completedPomodoros,
      totalFocusTime: this.completedPomodoros * this.settings.focusDuration,
      currentStreak: 1, // 简化实现
      completedPomodoros: this.completedPomodoros
    };
  }

  /**
   * 开始专注模式
   */
  startFocus(): void {
    this.startTimer(PomodoroState.FOCUSING);
  }

  /**
   * 开始短休息
   */
  startShortBreak(): void {
    this.startTimer(PomodoroState.SHORT_BREAK);
  }

  /**
   * 开始长休息
   */
  startLongBreak(): void {
    this.startTimer(PomodoroState.LONG_BREAK);
  }

  /**
   * 开始计时器
   */
  private startTimer(state: PomodoroState): void {
    // 停止当前计时器
    this.stopTimer();

    // 更新状态
    this.currentState = state;
    this.isPaused = false;

    // 设置时间
    switch (state) {
      case PomodoroState.FOCUSING:
        this.remainingTime = this.settings.focusDuration * 60;
        break;
      case PomodoroState.SHORT_BREAK:
        this.remainingTime = this.settings.shortBreakDuration * 60;
        break;
      case PomodoroState.LONG_BREAK:
        this.remainingTime = this.settings.longBreakDuration * 60;
        break;
    }

    // 触发状态变化事件
    this.triggerOnStateChange(state);

    // 开始计时
    this.currentTimerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  /**
   * 计时器tick
   */
  private tick(): void {
    if (this.isPaused) return;

    this.remainingTime--;

    // 触发计时器tick事件
    this.triggerOnTimerTick(this.remainingTime, this.getTotalTime());

    // 检查是否完成
    if (this.remainingTime <= 0) {
      this.onTimerComplete();
    }
  }

  /**
   * 计时器完成处理
   */
  private async onTimerComplete(): Promise<void> {
    this.stopTimer();

    switch (this.currentState) {
      case PomodoroState.FOCUSING:
        this.completedPomodoros++;
        this.currentSessionPomodoros++;
        await this.saveStats();
        this.triggerOnPomodoroComplete('focus');

        // 检查是否需要长休息
        if (this.currentSessionPomodoros >= this.settings.longBreakInterval) {
          this.currentSessionPomodoros = 0;
          if (this.settings.autoStartBreak) {
            this.startLongBreak();
          }
        } else {
          if (this.settings.autoStartBreak) {
            this.startShortBreak();
          }
        }
        break;

      case PomodoroState.SHORT_BREAK:
      case PomodoroState.LONG_BREAK:
        this.triggerOnPomodoroComplete('break');
        this.triggerOnSessionComplete();

        if (this.settings.autoStartFocus) {
          this.startFocus();
        }
        break;
    }

    // 播放提醒
    this.playNotification();
  }

  /**
   * 公共方法：手动触发计时器完成（用于跳过功能）
   */
  async triggerTimerComplete(): Promise<void> {
    // 跳过时强制进入下一个阶段，不考虑自动开始设置
    await this.onTimerCompleteForSkip();
  }

  /**
   * 跳过专用的计时器完成处理（强制进入下一个阶段）
   */
  private async onTimerCompleteForSkip(): Promise<void> {
    this.stopTimer();

    switch (this.currentState) {
      case PomodoroState.FOCUSING:
        this.completedPomodoros++;
        this.currentSessionPomodoros++;
        await this.saveStats();
        this.triggerOnPomodoroComplete('focus');

        // 检查是否需要长休息
        if (this.currentSessionPomodoros >= this.settings.longBreakInterval) {
          this.currentSessionPomodoros = 0;
          this.startLongBreak(); // 跳过时强制开始长休息
        } else {
          this.startShortBreak(); // 跳过时强制开始短休息
        }
        break;

      case PomodoroState.SHORT_BREAK:
      case PomodoroState.LONG_BREAK:
        this.triggerOnPomodoroComplete('break');
        this.triggerOnSessionComplete();
        this.startFocus(); // 跳过时强制开始专注
        break;
    }

    // 播放提醒
    this.playNotification();
  }

  /**
   * 播放通知提醒
   */
  private async playNotification(): Promise<void> {
    try {
      if (this.settings.enableSound || this.settings.enableVibration) {
        // 根据当前状态播放相应提醒
        if (this.currentState === PomodoroState.FOCUSING) {
          await this.notificationService.playPomodoroCompleteNotification('focus');
        } else {
          await this.notificationService.playPomodoroCompleteNotification('break');
        }
      }
    } catch (error) {
      console.error('PomodoroTimerService: Failed to play notification', error);
    }
  }

  /**
   * 暂停计时器
   */
  pause(): void {
    this.isPaused = true;
  }

  /**
   * 恢复计时器
   */
  resume(): void {
    this.isPaused = false;
  }

  /**
   * 重置当前计时器
   */
  reset(): void {
    this.stopTimer();

    switch (this.currentState) {
      case PomodoroState.FOCUSING:
        this.remainingTime = this.settings.focusDuration * 60;
        break;
      case PomodoroState.SHORT_BREAK:
        this.remainingTime = this.settings.shortBreakDuration * 60;
        break;
      case PomodoroState.LONG_BREAK:
        this.remainingTime = this.settings.longBreakDuration * 60;
        break;
      default:
        this.remainingTime = this.settings.focusDuration * 60;
        this.currentState = PomodoroState.IDLE;
    }

    this.isPaused = false;
    this.triggerOnTimerTick(this.remainingTime, this.getTotalTime());
  }

  /**
   * 停止计时器
   */
  private stopTimer(): void {
    if (this.currentTimerId !== -1) {
      clearInterval(this.currentTimerId);
      this.currentTimerId = -1;
    }
  }

  /**
   * 停止并重置到空闲状态
   */
  stop(): void {
    this.stopTimer();
    this.currentState = PomodoroState.IDLE;
    this.isPaused = false;
    this.remainingTime = this.settings.focusDuration * 60;
    this.triggerOnStateChange(PomodoroState.IDLE);
    this.triggerOnTimerTick(this.remainingTime, this.getTotalTime());
  }

  /**
   * 跳过当前阶段
   */
  async skip(): Promise<void> {
    console.info(`PomodoroTimerService: Skipping from state ${this.currentState}`);
    this.stopTimer();
    await this.triggerTimerComplete();
    console.info(`PomodoroTimerService: Skip completed, new state ${this.currentState}`);
  }

  /**
   * 是否正在运行
   */
  isRunning(): boolean {
    return this.currentTimerId !== -1 && !this.isPaused;
  }

  /**
   * 是否已暂停
   */
  isPausedState(): boolean {
    return this.isPaused;
  }

  /**
   * 格式化时间显示
   */
  static formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    const formattedMinutes = String(minutes).padStart(2, '0');
    const formattedSeconds = String(remainingSeconds).padStart(2, '0');
    return `${formattedMinutes}:${formattedSeconds}`;
  }

  /**
   * 获取进度百分比
   */
  getProgress(): number {
    const totalTime = this.getTotalTime();
    if (totalTime === 0) return 0;
    return ((totalTime - this.remainingTime) / totalTime) * 100;
  }

  /**
   * 重置今日统计
   */
  async resetTodayStats(): Promise<void> {
    this.completedPomodoros = 0;
    this.currentSessionPomodoros = 0;
    await this.storage.saveNumber('completed_today', 0);
  }

  /**
   * 设置当前任务
   */
  setCurrentTask(task: string): void {
    this.currentTask = task;
  }

  /**
   * 获取当前任务
   */
  getCurrentTask(): string {
    return this.currentTask;
  }

  /**
   * 销毁服务
   */
  destroy(): void {
    this.stopTimer();
    this.eventCallbacks = {};
  }
}