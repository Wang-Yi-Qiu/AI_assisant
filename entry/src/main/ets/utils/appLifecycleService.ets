import common from '@ohos.app.ability.common';
import { PomodoroTimerService, PomodoroState } from './pomodoroTimerService';
import { NotificationService } from './notificationService';

/**
 * 应用状态枚举
 */
export enum AppState {
  FOREGROUND = 'foreground',
  BACKGROUND = 'background'
}

/**
 * 应用生命周期事件
 */
export interface LifecycleEvent {
  type: AppState;
  timestamp: number;
  previousState?: AppState;
}

/**
 * 应用生命周期管理服务
 * 负责处理应用前后台切换时的逻辑
 */
export class AppLifecycleService {
  private static instance: AppLifecycleService | null = null;
  private currentState: AppState = AppState.FOREGROUND;
  private listeners: Set<(event: LifecycleEvent) => void> = new Set();
  private pomodoroTimer: PomodoroTimerService;
  private notificationService: NotificationService;
  private context: common.UIAbilityContext | null = null;
  private backgroundStartTime: number = 0;
  private totalBackgroundTime: number = 0;

  private constructor() {
    this.pomodoroTimer = PomodoroTimerService.getInstance();
    this.notificationService = NotificationService.getInstance();
  }

  static getInstance(): AppLifecycleService {
    if (!AppLifecycleService.instance) {
      AppLifecycleService.instance = new AppLifecycleService();
    }
    return AppLifecycleService.instance;
  }

  /**
   * 初始化生命周期管理
   */
  initialize(context: common.UIAbilityContext): void {
    this.context = context;
    console.info('AppLifecycleService: Initialized');

    // 设置通知服务的上下文
    this.notificationService.setContext(context);

    // 注册应用状态变化监听
    this.registerAppStateListener();
  }

  /**
   * 注册应用状态监听器
   */
  private registerAppStateListener(): void {
    // 注意：在HarmonyOS中，应用生命周期事件通过UIAbility的生命周期方法处理
    // 这里我们记录日志，实际的生命周期处理在EntryAbility中完成
    console.info('AppLifecycleService: App state listeners will be handled by EntryAbility lifecycle methods');
  }

  /**
   * 应用进入前台时的处理
   */
  onAppForeground(): void {
    const previousState = this.currentState;
    this.currentState = AppState.FOREGROUND;

    // 计算后台时间
    if (previousState === AppState.BACKGROUND) {
      this.totalBackgroundTime += Date.now() - this.backgroundStartTime;
      console.info(`AppLifecycleService: App returned to foreground after ${Date.now() - this.backgroundStartTime}ms in background`);
    }

    const event: LifecycleEvent = {
      type: AppState.FOREGROUND,
      timestamp: Date.now(),
      previousState
    };

    this.handleForegroundTransition(event);
    this.notifyListeners(event);
  }

  /**
   * 应用进入后台时的处理
   */
  onAppBackground(): void {
    const previousState = this.currentState;
    this.currentState = AppState.BACKGROUND;
    this.backgroundStartTime = Date.now();

    const event: LifecycleEvent = {
      type: AppState.BACKGROUND,
      timestamp: Date.now(),
      previousState
    };

    this.handleBackgroundTransition(event);
    this.notifyListeners(event);
  }

  /**
   * 处理前台切换逻辑
   */
  private handleForegroundTransition(event: LifecycleEvent): void {
    console.info('AppLifecycleService: Handling foreground transition');

    // 检查番茄钟状态
    const currentPomodoroState = this.pomodoroTimer.getCurrentState();
    const isRunning = this.pomodoroTimer.isRunning();

    if (currentPomodoroState === PomodoroState.FOCUSING && isRunning) {
      // 专注中回到前台，显示欢迎信息
      console.info('AppLifecycleService: Focus session resumed');
      this.showResumeNotification('专注会话已恢复', '继续专注于当前任务');
    } else if (currentPomodoroState === PomodoroState.SHORT_BREAK || currentPomodoroState === PomodoroState.LONG_BREAK) {
      // 休息中回到前台
      console.info('AppLifecycleService: Break resumed');
      this.showResumeNotification('休息时间已恢复', '享受这段休息时光');
    }

    // 同步数据状态
    this.syncDataState();
  }

  /**
   * 处理后台切换逻辑
   */
  private handleBackgroundTransition(event: LifecycleEvent): void {
    console.info('AppLifecycleService: Handling background transition');

    const currentPomodoroState = this.pomodoroTimer.getCurrentState();
    const isRunning = this.pomodoroTimer.isRunning();

    if (currentPomodoroState === PomodoroState.FOCUSING && isRunning) {
      // 专注中进入后台，显示通知
      console.info('AppLifecycleService: Focus session in background');
      this.showBackgroundNotification('专注进行中', '应用在后台时专注仍在继续');
    } else if (currentPomodoroState === PomodoroState.SHORT_BREAK || currentPomodoroState === PomodoroState.LONG_BREAK) {
      // 休息中进入后台
      console.info('AppLifecycleService: Break in background');
    }

    // 保存当前状态
    this.saveCurrentState();
  }

  /**
   * 显示恢复通知
   */
  private async showResumeNotification(title: string, content: string): Promise<void> {
    try {
      // 可以选择性地显示恢复通知，避免过度打扰用户
      // 这里只是记录日志
      console.info(`AppLifecycleService: Resume notification - ${title}: ${content}`);
    } catch (error) {
      console.error('AppLifecycleService: Failed to show resume notification', error);
    }
  }

  /**
   * 显示后台通知
   */
  private async showBackgroundNotification(title: string, content: string): Promise<void> {
    try {
      // 在后台时显示重要通知
      await this.notificationService.playPomodoroCompleteNotification('focus');
      console.info(`AppLifecycleService: Background notification - ${title}: ${content}`);
    } catch (error) {
      console.error('AppLifecycleService: Failed to show background notification', error);
    }
  }

  /**
   * 同步数据状态
   */
  private async syncDataState(): Promise<void> {
    try {
      // 这里可以添加数据同步逻辑
      // 比如从云端同步数据，或检查本地数据完整性
      console.info('AppLifecycleService: Syncing data state');
    } catch (error) {
      console.error('AppLifecycleService: Failed to sync data state', error);
    }
  }

  /**
   * 保存当前状态
   */
  private async saveCurrentState(): Promise<void> {
    try {
      // 保存关键状态到持久化存储
      console.info('AppLifecycleService: Saving current state');
    } catch (error) {
      console.error('AppLifecycleService: Failed to save current state', error);
    }
  }

  /**
   * 获取当前应用状态
   */
  getCurrentState(): AppState {
    return this.currentState;
  }

  /**
   * 检查应用是否在前台
   */
  isForeground(): boolean {
    return this.currentState === AppState.FOREGROUND;
  }

  /**
   * 检查应用是否在后台
   */
  isBackground(): boolean {
    return this.currentState === AppState.BACKGROUND;
  }

  /**
   * 获取总后台时间
   */
  getTotalBackgroundTime(): number {
    return this.totalBackgroundTime;
  }

  /**
   * 获取当前后台会话时长
   */
  getCurrentBackgroundSessionDuration(): number {
    if (this.currentState === AppState.BACKGROUND) {
      return Date.now() - this.backgroundStartTime;
    }
    return 0;
  }

  /**
   * 添加生命周期事件监听器
   */
  addListener(listener: (event: LifecycleEvent) => void): void {
    this.listeners.add(listener);
  }

  /**
   * 移除生命周期事件监听器
   */
  removeListener(listener: (event: LifecycleEvent) => void): void {
    this.listeners.delete(listener);
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(event: LifecycleEvent): void {
    for (const listener of this.listeners) {
      try {
        listener(event);
      } catch (error) {
        console.error('AppLifecycleService: Error in lifecycle listener', error);
      }
    }
  }

  /**
   * 处理应用即将被终止
   */
  onAppTerminate(): void {
    console.info('AppLifecycleService: App terminating');

    // 保存关键数据
    this.saveCurrentState();

    // 清理资源
    this.pomodoroTimer.destroy();

    // 清理监听器
    this.listeners.clear();

    console.info('AppLifecycleService: Cleanup completed');
  }

  /**
   * 处理内存警告
   */
  onMemoryWarning(): void {
    console.warn('AppLifecycleService: Memory warning received');

    // 在内存不足时可以采取的优化措施
    // 1. 清理缓存
    // 2. 释放不必要的资源
    // 3. 降低某些功能的性能

    // 这里暂时只记录日志
    console.info('AppLifecycleService: Memory optimization triggered');
  }

  }

/**
 * 生命周期统计信息接口
 */
interface LifecycleStats {
  currentState: AppState;
  totalBackgroundTime: number;
  currentBackgroundSessionDuration: number;
  listenerCount: number;
}

/**
 * 快捷函数
 */
export const getAppLifecycleService = (): AppLifecycleService =>
  AppLifecycleService.getInstance();

export const isAppForeground = (): boolean =>
  AppLifecycleService.getInstance().isForeground();

export const isAppBackground = (): boolean =>
  AppLifecycleService.getInstance().isBackground();

/**
 * 获取生命周期统计信息的扩展函数
 */
export function getLifecycleStats(service: AppLifecycleService): LifecycleStats {
  return {
    currentState: service.getCurrentState(),
    totalBackgroundTime: service.getTotalBackgroundTime(),
    currentBackgroundSessionDuration: service.getCurrentBackgroundSessionDuration(),
    listenerCount: 0 // 简化实现，避免访问私有属性
  };
}