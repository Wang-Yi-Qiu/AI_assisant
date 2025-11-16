import router from '@ohos.router';
import { PomodoroTimerService, PomodoroState } from '../utils/pomodoroTimerService';
import { getStorageInstance } from '../utils/preferencesStorage';
import { TaskManager } from '../utils/taskManager';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct FocusProgressPage {
  private pomodoroTimer: PomodoroTimerService = PomodoroTimerService.getInstance();
  private taskManager: TaskManager = TaskManager.getInstance();

  @State timerValue: number = 25 * 60; // 25分钟
  @State isPaused: boolean = false;
  @State currentTask: string = "准备开始专注"; // 当前任务
  @State currentProgress: number = 0;
  @State currentTimerState: PomodoroState = PomodoroState.IDLE;
  @State showSkipConfirmDialog: boolean = false; // 跳过确认对话框
  @State skipDialogTitle: string = ''; // 对话框标题
  @State skipDialogContent: string = ''; // 对话框内容

  aboutToAppear() {
    // 设置存储Context
    const context = getContext(this) as common.UIAbilityContext;
    getStorageInstance().setContext(context);

    this.initializeTasks();
    this.initializeTimer();
  }

  aboutToDisappear() {
    this.pomodoroTimer.destroy();
  }

  private async initializeTasks(): Promise<void> {
    try {
      await this.taskManager.initialize();
      // 获取当前选中的任务并设置到计时器
      const currentSelectedTask = this.taskManager.getCurrentSelectedTask();
      if (currentSelectedTask) {
        this.pomodoroTimer.setCurrentTask(currentSelectedTask.text);
      }
    } catch (error) {
      console.error('FocusProgressPage: Failed to initialize tasks', error);
    }
  }

  private initializeTimer() {
    // 初始化计时器状态
    this.timerValue = this.pomodoroTimer.getRemainingTime();
    this.currentTimerState = this.pomodoroTimer.getCurrentState();
    this.isPaused = this.pomodoroTimer.isPausedState();
    this.currentProgress = this.pomodoroTimer.getProgress();
    this.currentTask = this.pomodoroTimer.getCurrentTask();

    // 如果计时器未运行，开始专注
    if (this.currentTimerState === PomodoroState.IDLE) {
      this.pomodoroTimer.startFocus();
      this.currentTimerState = PomodoroState.FOCUSING;
    }

    // 设置事件回调
    this.pomodoroTimer.setEventCallbacks({
      onTimerTick: (remainingTime: number, totalTime: number) => {
        this.timerValue = remainingTime;
        this.currentProgress = this.pomodoroTimer.getProgress();
        // 同步暂停状态
        this.isPaused = this.pomodoroTimer.isPausedState();
      },
      onStateChange: (newState: PomodoroState) => {
        this.currentTimerState = newState;
        this.timerValue = this.pomodoroTimer.getRemainingTime();
        this.currentProgress = 0;
        this.isPaused = false; // 状态变化时重置暂停状态
      },
      onPomodoroComplete: (type: 'focus' | 'break') => {
        if (type === 'focus') {
          // 专注完成，显示完成提示
          console.info('专注时间完成！');
        }
        // 完成时重置暂停状态
        this.isPaused = false;
      }
    });

    this.isPaused = this.pomodoroTimer.isPausedState();
  }

  // 格式化时间 MM:SS
  formatTime(seconds: number): string {
    return PomodoroTimerService.formatTime(seconds);
  }

  // 暂停/继续
  togglePause() {
    if (this.isPaused) {
      this.pomodoroTimer.resume();
    } else {
      this.pomodoroTimer.pause();
    }
    this.isPaused = !this.isPaused;
  }

  // 放弃
  abandonFocus() {
    this.pomodoroTimer.stop();
    router.pushUrl({ url: 'pages/Index' });
  }

  // 显示跳过确认对话框
  showSkipDialog() {
    switch (this.currentTimerState) {
      case PomodoroState.FOCUSING:
        this.skipDialogTitle = '跳过专注时间';
        this.skipDialogContent = '确定要跳过当前的专注时间吗？\n这将标记当前专注为完成，并进入休息时间。';
        break;
      case PomodoroState.SHORT_BREAK:
        this.skipDialogTitle = '跳过短休息';
        this.skipDialogContent = '确定要跳过当前的短休息吗？\n这将直接进入下一个专注时间。';
        break;
      case PomodoroState.LONG_BREAK:
        this.skipDialogTitle = '跳过长休息';
        this.skipDialogContent = '确定要跳过当前的长休息吗？\n这将直接进入下一个专注时间。';
        break;
      default:
        return;
    }
    this.showSkipConfirmDialog = true;
  }

  // 确认跳过
  async confirmSkip() {
    this.showSkipConfirmDialog = false;
    console.info('FocusProgressPage: User confirmed skip');
    try {
      await this.pomodoroTimer.skip();
      console.info('FocusProgressPage: Skip completed successfully');
    } catch (error) {
      console.error('FocusProgressPage: Skip failed', error);
    }
  }

  // 取消跳过
  cancelSkip() {
    this.showSkipConfirmDialog = false;
    console.info('FocusProgressPage: User cancelled skip');
  }

  // 跳过当前阶段
  async skipCurrentPhase() {
    this.showSkipDialog();
  }

  // 获取当前状态文本
  getCurrentStateText(): string {
    switch (this.currentTimerState) {
      case PomodoroState.FOCUSING:
        return '专注时间';
      case PomodoroState.SHORT_BREAK:
        return '短休息时间';
      case PomodoroState.LONG_BREAK:
        return '长休息时间';
      default:
        return '准备开始';
    }
  }

  // 获取当前状态颜色
  getCurrentStateColor(): string {
    switch (this.currentTimerState) {
      case PomodoroState.FOCUSING:
        return '#FF6B6B';
      case PomodoroState.SHORT_BREAK:
        return '#4ECDC4';
      case PomodoroState.LONG_BREAK:
        return '#45B7D1';
      default:
        return '#007DFF';
    }
  }

  build() {
    Column() {
      // 状态指示器
      Text(this.getCurrentStateText())
        .fontSize(18)
        .fontColor(this.getCurrentStateColor())
        .margin({ top: '10%' })

      // 进度圆环
      Stack({ alignContent: Alignment.Center }) {
        // 背景圆环
        Progress({ value: 100, type: ProgressType.Ring })
          .width(220)
          .style({ strokeWidth: 15 })
          .color('#1F3C53')

        // 进度圆环
        Progress({ value: this.currentProgress, total: 100, type: ProgressType.Ring })
          .width(220)
          .style({ strokeWidth: 15 })
          .color(this.getCurrentStateColor())

        // 时间显示
        Text(this.formatTime(this.timerValue))
          .fontSize(60)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .margin({ top: 30, bottom: 30 })

      // 当前任务
      Column() {
        Text('当前任务')
          .fontSize(14)
          .fontColor(Color.Gray)

        Text(this.currentTask)
          .fontSize(18)
          .fontColor(Color.White)
          .margin({ top: 5 })
      }
      .margin({ bottom: '15%' })

      // 环境音效（暂不实现）
      Row() {
        Text('🌧️ 雨声')
          .fontColor(Color.White).fontSize(14).margin({right:15})
        Text('💨 风声')
          .fontColor(Color.White).fontSize(14).margin({right:15})
        Text('☕️ 咖啡馆')
          .fontColor(Color.White).fontSize(14)
      }
      .margin({ bottom: 40 })

      // 控制按钮
      Row() {
        Button('放弃', { type: ButtonType.Capsule, stateEffect: true })
          .width('25%')
          .height(50)
          .fontSize(14)
          .backgroundColor('#252525')
          .onClick(() => this.abandonFocus())

        Button('跳过', { type: ButtonType.Capsule, stateEffect: true })
          .width('25%')
          .height(50)
          .fontSize(14)
          .backgroundColor('#333333')
          .onClick(() => this.skipCurrentPhase())

        Button(this.isPaused ? '继续' : '暂停', { type: ButtonType.Capsule, stateEffect: true })
          .width('45%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.getCurrentStateColor())
          .onClick(() => this.togglePause())
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 跳过确认对话框
    if (this.showSkipConfirmDialog) {
      Stack({ alignContent: Alignment.Center }) {
        // 半透明背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => this.cancelSkip())

        // 对话框内容
        Column() {
          Text(this.skipDialogTitle)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ bottom: 20 })

          Text(this.skipDialogContent)
            .fontSize(16)
            .fontColor('#E0E0E0')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 30 })

          // 按钮
          Row() {
            Button('取消', { type: ButtonType.Capsule })
              .width('45%')
              .height(45)
              .fontSize(16)
              .backgroundColor('#666666')
              .onClick(() => this.cancelSkip())

            Button('确定', { type: ButtonType.Capsule })
              .width('45%')
              .height(45)
              .fontSize(16)
              .backgroundColor(this.getCurrentStateColor())
              .onClick(() => this.confirmSkip())
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('80%')
        .padding(24)
        .backgroundColor('#2C2C2C')
        .borderRadius(12)
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 }) // 使用绝对定位确保对话框覆盖整个屏幕
      .zIndex(1000) // 确保对话框在最上层
    }
  }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
    .alignItems(HorizontalAlign.Center)
  }
}