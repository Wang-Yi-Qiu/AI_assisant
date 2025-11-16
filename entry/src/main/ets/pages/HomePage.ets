import router from '@ohos.router';
import { PomodoroTimerService, PomodoroState } from '../utils/pomodoroTimerService';
import { getStorageInstance } from '../utils/preferencesStorage';
import { TaskManager, Task } from '../utils/taskManager';
import common from '@ohos.app.ability.common';

@Component
export struct HomePage {
  private pomodoroTimer: PomodoroTimerService = PomodoroTimerService.getInstance();
  private taskManager: TaskManager = TaskManager.getInstance();

  @State timerValue: number = 25 * 60; // 25分钟的秒数
  @State pomodoroTarget: number = 8;
  @State pomodoroCompleted: number = 0;
  @State currentProgress: number = 0;
  @State isTimerRunning: boolean = false;
  @State currentTimerState: PomodoroState = PomodoroState.IDLE;

  @State tasks: Task[] = [];
  @State newTaskText: string = '';
  @State selectedTaskId: number = -1; // 当前选中的任务ID

  aboutToAppear() {
    // 设置存储Context
    const context = getContext(this) as common.UIAbilityContext;
    getStorageInstance().setContext(context);

    this.initializeTimer();
    this.initializeTasks();
  }

  private async initializeTasks(): Promise<void> {
    try {
      await this.taskManager.initialize();
      this.tasks = this.taskManager.getTasks();

      // 自动选择第一个未完成的任务
      const firstIncompleteTask = this.tasks.find(task => !task.completed);
      if (firstIncompleteTask) {
        this.selectedTaskId = firstIncompleteTask.id;
      }
    } catch (error) {
      console.error('HomePage: Failed to initialize tasks', error);
      // 如果加载失败，使用默认任务
      this.tasks = [
        new Task(1, '设计番茄钟界面', false),
        new Task(2, '准备周会演示文稿', true)
      ];
      // 自动选择第一个未完成的默认任务
      this.selectedTaskId = 1;
    }
  }

  aboutToDisappear() {
    this.pomodoroTimer.destroy();
  }

  private initializeTimer() {
    // 初始化计时器状态
    const stats = this.pomodoroTimer.getStats();
    this.pomodoroCompleted = stats.completedToday;
    this.timerValue = this.pomodoroTimer.getRemainingTime();

    // 设置事件回调
    this.pomodoroTimer.setEventCallbacks({
      onTimerTick: (remainingTime: number, totalTime: number) => {
        this.timerValue = remainingTime;
        this.currentProgress = this.pomodoroTimer.getProgress();
        // 同步运行状态
        this.isTimerRunning = this.pomodoroTimer.isRunning();
      },
      onStateChange: (newState: PomodoroState) => {
        this.currentTimerState = newState;
        this.timerValue = this.pomodoroTimer.getRemainingTime();
        this.currentProgress = 0;
        this.isTimerRunning = false; // 状态变化时重置运行状态
      },
      onPomodoroComplete: (type: 'focus' | 'break') => {
        if (type === 'focus') {
          const stats = this.pomodoroTimer.getStats();
          this.pomodoroCompleted = stats.completedToday;
        }
        // 完成时重置运行状态
        this.isTimerRunning = false;
      }
    });

    // 检查当前状态
    this.currentTimerState = this.pomodoroTimer.getCurrentState();
    this.isTimerRunning = this.pomodoroTimer.isRunning();
    this.currentProgress = this.pomodoroTimer.getProgress();
  }

  // 添加任务
  async addTask() {
    if (this.newTaskText.trim() === '') return;

    try {
      const newTask = await this.taskManager.addTask(this.newTaskText);
      this.tasks = this.taskManager.getTasks(); // 刷新任务列表
      this.newTaskText = ''; // 清空输入框
    } catch (error) {
      console.error('HomePage: Failed to add task', error);
    }
  }

  // 删除任务
  async deleteTask(taskId: number) {
    try {
      const success = await this.taskManager.deleteTask(taskId);
      if (success) {
        this.tasks = this.taskManager.getTasks(); // 刷新任务列表

        // 如果删除的是当前选中的任务，重新选择第一个未完成的任务
        if (taskId === this.selectedTaskId) {
          const firstIncompleteTask = this.tasks.find(task => !task.completed);
          this.selectedTaskId = firstIncompleteTask ? firstIncompleteTask.id : -1;
        }
      }
    } catch (error) {
      console.error('HomePage: Failed to delete task', error);
    }
  }

  // 开始/暂停计时器
  toggleTimer() {
    if (this.isTimerRunning) {
      this.pomodoroTimer.pause();
      this.isTimerRunning = false;
    } else {
      if (this.currentTimerState === PomodoroState.IDLE) {
        this.pomodoroTimer.startFocus();
      } else {
        this.pomodoroTimer.resume();
      }
      this.isTimerRunning = true;
    }
  }

  // 重置计时器
  resetTimer() {
    this.pomodoroTimer.reset();
    this.isTimerRunning = false;
  }

  // 获取当前状态文本
  getCurrentStateText(): string {
    switch (this.currentTimerState) {
      case PomodoroState.FOCUSING:
        return '专注中';
      case PomodoroState.SHORT_BREAK:
        return '短休息';
      case PomodoroState.LONG_BREAK:
        return '长休息';
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

  // 获取当前选中的任务
  getCurrentSelectedTask(): string {
    if (this.selectedTaskId !== -1) {
      const selectedTask = this.tasks.find(task => task.id === this.selectedTaskId);
      return selectedTask ? selectedTask.text : '未选中任务';
    }
    return '未选中任务';
  }

  // 选择任务
  selectTask(taskId: number): void {
    this.selectedTaskId = taskId;
  }

  // 将秒格式化为 MM:SS
  formatTime(seconds: number): string {
    return PomodoroTimerService.formatTime(seconds);
  }

  build() {
    Column() {
      // 顶部栏: 标题和设置
      Row() {
        Text('番茄钟')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Blank()

        Text('⚙️')
          .fontSize(28)
          .onClick(() => {
            console.info('点击设置图标');
            router.pushUrl({ url: 'pages/SettingsPage' });
          })
      }
      .width('90%')
      .padding({ top: 20, bottom: 40 })

      // 计时器圆环
      Stack({ alignContent: Alignment.Center }) {
        // 背景圆环
        Progress({ value: 100, type: ProgressType.Ring })
          .width(280)
          .style({ strokeWidth: 20 })
          .color('#1F3C53')

        // 进度圆环
        Progress({ value: this.currentProgress, total: 100, type: ProgressType.Ring })
          .width(280)
          .style({ strokeWidth: 20 })
          .color(this.getCurrentStateColor())

        // 时间和状态
        Column() {
          Text(this.formatTime(this.timerValue))
            .fontSize(60)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Text(this.getCurrentStateText())
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 5 })
        }
      }
      .margin({ bottom: 50 })

      // 控制按钮
      Row() {
        Button('重置', { type: ButtonType.Capsule, stateEffect: true })
          .width('25%')
          .height(50)
          .fontSize(16)
          .backgroundColor('#252525')
          .onClick(() => this.resetTimer())

        Button(this.isTimerRunning ? '暂停' : (this.currentTimerState === PomodoroState.IDLE ? '开始' : '继续'), { type: ButtonType.Capsule, stateEffect: true })
          .width('45%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(this.getCurrentStateColor())
          .onClick(() => this.toggleTimer())

        Button('专注', { type: ButtonType.Capsule, stateEffect: true })
          .width('25%')
          .height(50)
          .fontSize(16)
          .backgroundColor('#007DFF')
          .onClick(() => {
            // 设置当前任务到番茄钟服务
            const currentTaskText = this.getCurrentSelectedTask();
            this.pomodoroTimer.setCurrentTask(currentTaskText);

            // 通过参数传递选中的任务ID
            router.pushUrl({
              url: 'pages/FocusProgressPage',
              params: {
                selectedTaskId: this.selectedTaskId,
                selectedTaskText: currentTaskText
              }
            });
          })
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 40 })

      Scroll() {
        Column() {
          // 今日番茄数卡片
          this.PomodoroStatsCard()

          // 今日任务卡片
          this.TasksCard()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 20 }) // 添加底部内边距，确保内容不被底部导航栏遮挡
      }
      .width('100%')
      .layoutWeight(1) // 添加布局权重，确保滚动区域占据剩余空间
      .scrollable(ScrollDirection.Vertical) // 明确指定垂直滚动
      .scrollBar(BarState.Auto) // 自动显示滚动条
      .edgeEffect(EdgeEffect.Spring) // 添加弹性滚动效果

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
    .padding({ left: 15, right: 15 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  PomodoroStatsCard(){
    Column() {
      Row() {
        Text('今日番茄数')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Blank()
      }
      .margin({ bottom: 10 })

      Row().alignItems(VerticalAlign.Center) {
        Text(`已完成 ${this.pomodoroCompleted} 个，目标 ${this.pomodoroTarget} 个`)
          .fontSize(14)
          .fontColor(Color.Gray)
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: (this.pomodoroCompleted / this.pomodoroTarget) * 100, type: ProgressType.Ring })
            .width(50)
            .style({ strokeWidth: 8 })
            .color('#007DFF')
          Text(`${this.pomodoroCompleted}/${this.pomodoroTarget}`)
            .fontSize(12)
            .fontColor(Color.White)
        }
      }
    }
    .padding(20)
    .width('90%')
    .backgroundColor('#252525')
    .borderRadius(15)
    .margin({ bottom: 20 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/PomodoroStatsPage' });
    })
  }

  @Builder
  TasksCard(){
    Column() {
      Text('今日任务')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 15 })

      // 任务列表
      Column() {
        ForEach(this.tasks, (item: Task) => {
          Row() {
            // 任务选择按钮
            Button({
              type: ButtonType.Circle,
              stateEffect: false
            }) {
              Text(this.selectedTaskId === item.id ? '✓' : '')
                .fontSize(16)
                .fontColor(Color.White)
            }
            .width(24)
            .height(24)
            .backgroundColor(this.selectedTaskId === item.id ? '#007DFF' : '#333333')
            .margin({ right: 10 })
            .onClick(() => {
              this.selectTask(item.id);
            })

            // 任务文本
            Text(item.text)
              .fontSize(14)
              .fontColor(item.completed ? Color.Gray : Color.White)
              .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
              .layoutWeight(1)
              .onClick(() => {
                // 点击任务文本也可以选择任务
                if (!item.completed) {
                  this.selectTask(item.id);
                }
              })

            // 完成状态复选框
            Checkbox({ name: `task_complete_${item.id}`, group: 'task_completion' })
              .select(item.completed)
              .selectedColor('#4CAF50')
              .onChange(async (isSelected: boolean) => {
                try {
                  const success = await this.taskManager.toggleTaskComplete(item.id);
                  if (success) {
                    this.tasks = this.taskManager.getTasks(); // 刷新任务列表
                    // 如果选择的任务被完成了，清除选择
                    if (item.id === this.selectedTaskId && isSelected) {
                      this.selectedTaskId = -1;
                    }
                  }
                } catch (error) {
                  console.error('HomePage: Failed to toggle task completion', error);
                }
              })

            // 删除按钮
            Text('×')
              .fontSize(20)
              .fontColor(Color.Gray)
              .margin({ left: 10 })
              .onClick(() => this.deleteTask(item.id))
          }
          .alignItems(VerticalAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .backgroundColor(this.selectedTaskId === item.id ? '#2A2A2A' : 'transparent')
          .borderRadius(8)
          .padding({ left: 8, right: 8 })
        }, (item: Task) => item.id.toString())
      }

      // 添加新任务
      Row() {
        TextInput({ placeholder: '添加新任务...', text: this.newTaskText })
          .onChange((value: string) => {
            this.newTaskText = value;
          })
          .onSubmit(() => {
            this.addTask();
          })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#333333')
          .fontColor(Color.White)
          .placeholderColor(Color.Gray)
          .borderRadius(20)
          .padding({left:15})

        Button('+')
          .width(40)
          .height(40)
          .fontSize(20)
          .margin({ left: 10 })
          .type(ButtonType.Circle)
          .backgroundColor('#007DFF')
          .onClick(() => this.addTask())
      }
      .margin({ top: 15 })

    }
    .padding(20)
    .width('90%')
    .backgroundColor('#252525')
    .borderRadius(15)
  }
}