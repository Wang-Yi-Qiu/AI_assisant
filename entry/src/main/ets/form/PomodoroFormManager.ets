import FormProvider from '@ohos.app.form.formProvider';
import formBindingData from '@ohos.app.form.formBindingData';
import hilog from '@ohos.hilog';
import { PomodoroTimerService, PomodoroState } from '../utils/pomodoroTimerService';

/**
 * 番茄钟卡片管理器
 * 负责卡片状态管理和数据同步
 */
export class PomodoroFormManager {
  private static instance: PomodoroFormManager | null = null;
  private static readonly TAG = 'PomodoroFormManager';
  private static readonly DOMAIN = 0xFF01;

  private pomodoroService: PomodoroTimerService;
  private formIds: Set<string> = new Set();
  private isMonitoring: boolean = false;

  private constructor() {
    this.pomodoroService = PomodoroTimerService.getInstance();
    this.setupEventListeners();
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): PomodoroFormManager {
    if (!PomodoroFormManager.instance) {
      PomodoroFormManager.instance = new PomodoroFormManager();
    }
    return PomodoroFormManager.instance;
  }

  /**
   * 注册卡片
   */
  public registerForm(formId: string): void {
    this.formIds.add(formId);
    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `Form ${formId} registered`);

    if (!this.isMonitoring) {
      this.startMonitoring();
    }

    // 立即更新卡片数据
    this.updateForm(formId);
  }

  /**
   * 注销卡片
   */
  public unregisterForm(formId: string): void {
    this.formIds.delete(formId);
    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `Form ${formId} unregistered`);

    if (this.formIds.size === 0 && this.isMonitoring) {
      this.stopMonitoring();
    }
  }

  /**
   * 更新指定卡片
   */
  public updateForm(formId: string): void {
    try {
      const formData = this.createFormData();
      const formBindingDataObj = formBindingData.createFormBindingData(formData);

      FormProvider.updateForm(formId, formBindingDataObj).then(() => {
        hilog.debug(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `Form ${formId} updated successfully`);
      }).catch((error: Error) => {
        hilog.error(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG,
          `Failed to update form ${formId}: ${error.message}`);
      });
    } catch (error) {
      hilog.error(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `updateForm error: ${error}`);
    }
  }

  /**
   * 更新所有卡片
   */
  public updateAllForms(): void {
    if (this.formIds.size === 0) {
      return;
    }

    hilog.debug(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG,
      `Updating ${this.formIds.size} forms`);

    this.formIds.forEach(formId => {
      this.updateForm(formId);
    });
  }

  /**
   * 开始监控番茄钟服务状态
   */
  private startMonitoring(): void {
    if (this.isMonitoring) {
      return;
    }

    this.isMonitoring = true;
    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, 'Started monitoring Pomodoro service');

    // 设置事件监听器
    this.pomodoroService.setEventCallbacks({
      onTimerTick: (remainingTime: number, totalTime: number) => {
        // 每秒更新一次
        this.updateAllForms();
      },
      onStateChange: (newState: PomodoroState) => {
        // 状态变化时立即更新
        this.updateAllForms();
      },
      onPomodoroComplete: (type: 'focus' | 'break') => {
        // 完成时立即更新
        this.updateAllForms();
      },
      onSessionComplete: () => {
        // 会话完成时立即更新
        this.updateAllForms();
      }
    });
  }

  /**
   * 停止监控
   */
  private stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;

    // 清理事件监听器
    this.pomodoroService.setEventCallbacks({});

    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, 'Stopped monitoring Pomodoro service');
  }

  /**
   * 创建卡片数据
   */
  public createFormData(): Record<string, any> {
    try {
      const currentState = this.pomodoroService.getCurrentState();
      const remainingTime = this.pomodoroService.getRemainingTime();
      const totalTime = this.pomodoroService.getTotalTime();
      const progress = this.pomodoroService.getProgress();
      const stats = this.pomodoroService.getStats();
      const currentTask = this.pomodoroService.getCurrentTask();
      const isRunning = this.pomodoroService.isRunning();
      const isPaused = this.pomodoroService.isPausedState();

      return {
        formId: '',
        currentState: currentState,
        formattedTime: PomodoroTimerService.formatTime(remainingTime),
        progress: progress.toFixed(1),
        totalProgress: totalTime,
        currentTask: currentTask || '专注中',
        isRunning: isRunning,
        isPaused: isPaused,
        completedToday: stats.completedToday,
        stateText: this.getStateText(currentState),
        stateColor: this.getStateColor(currentState),
        actionButtonText: this.getActionButtonText(currentState, isRunning, isPaused),
        secondaryActionButtonText: this.getSecondaryActionButtonText(currentState),
        timestamp: Date.now()
      };
    } catch (error) {
      hilog.error(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `createFormData error: ${error}`);
      return this.getDefaultFormData();
    }
  }

  /**
   * 获取默认卡片数据
   */
  private getDefaultFormData(): Record<string, any> {
    return {
      formId: '',
      currentState: PomodoroState.IDLE,
      formattedTime: '25:00',
      progress: '0.0',
      totalProgress: 1500,
      currentTask: '准备开始',
      isRunning: false,
      isPaused: false,
      completedToday: 0,
      stateText: '空闲',
      stateColor: '#9E9E9E',
      actionButtonText: '开始专注',
      secondaryActionButtonText: '',
      timestamp: Date.now()
    };
  }

  /**
   * 获取状态文本
   */
  private getStateText(state: PomodoroState): string {
    switch (state) {
      case PomodoroState.IDLE:
        return '空闲';
      case PomodoroState.FOCUSING:
        return '专注中';
      case PomodoroState.SHORT_BREAK:
        return '短休息';
      case PomodoroState.LONG_BREAK:
        return '长休息';
      default:
        return '未知';
    }
  }

  /**
   * 获取状态颜色
   */
  private getStateColor(state: PomodoroState): string {
    switch (state) {
      case PomodoroState.IDLE:
        return '#9E9E9E';
      case PomodoroState.FOCUSING:
        return '#F44336';
      case PomodoroState.SHORT_BREAK:
        return '#4CAF50';
      case PomodoroState.LONG_BREAK:
        return '#2196F3';
      default:
        return '#9E9E9E';
    }
  }

  /**
   * 获取操作按钮文本
   */
  private getActionButtonText(state: PomodoroState, isRunning: boolean, isPaused: boolean): string {
    if (!isRunning) {
      if (state === PomodoroState.IDLE) {
        return '开始专注';
      } else {
        return '继续';
      }
    } else {
      return isPaused ? '继续' : '暂停';
    }
  }

  /**
   * 获取次要操作按钮文本
   */
  private getSecondaryActionButtonText(state: PomodoroState): string {
    if (state === PomodoroState.IDLE) {
      return '';
    } else {
      return '跳过';
    }
  }

  /**
   * 处理卡片事件
   */
  public handleFormEvent(action: string, parameters?: Record<string, any>): void {
    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `Handling form event: ${action}`);

    try {
      switch (action) {
        case 'start_focus':
          this.pomodoroService.startFocus();
          break;
        case 'pause':
          this.pomodoroService.pause();
          break;
        case 'resume':
          this.pomodoroService.resume();
          break;
        case 'reset':
          this.pomodoroService.reset();
          break;
        case 'start_break':
          const breakType = parameters?.breakType || 'short';
          if (breakType === 'long') {
            this.pomodoroService.startLongBreak();
          } else {
            this.pomodoroService.startShortBreak();
          }
          break;
        case 'skip':
          this.pomodoroService.skip();
          break;
        case 'abandon':
          this.pomodoroService.abandon();
          break;
        default:
          hilog.warn(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `Unknown action: ${action}`);
          break;
      }
    } catch (error) {
      hilog.error(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `handleFormEvent error: ${error}`);
    }
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    // 监听应用生命周期变化
    try {
      // 这里可以添加应用生命周期监听
      hilog.debug(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, 'Event listeners setup completed');
    } catch (error) {
      hilog.error(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, `setupEventListeners error: ${error}`);
    }
  }

  /**
   * 获取卡片统计信息
   */
  public getFormStats(): {
    activeFormsCount: number;
    isMonitoring: boolean;
    serviceState: PomodoroState;
  } {
    return {
      activeFormsCount: this.formIds.size,
      isMonitoring: this.isMonitoring,
      serviceState: this.pomodoroService.getCurrentState()
    };
  }

  /**
   * 销毁管理器
   */
  public destroy(): void {
    hilog.info(PomodoroFormManager.DOMAIN, PomodoroFormManager.TAG, 'Destroying PomodoroFormManager');

    this.stopMonitoring();
    this.formIds.clear();

    if (PomodoroFormManager.instance === this) {
      PomodoroFormManager.instance = null;
    }
  }
}