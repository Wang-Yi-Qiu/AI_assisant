import router from '@ohos.router';
import { PomodoroTimerService, PomodoroState } from '../utils/pomodoroTimerService';
import { getStorageInstance } from '../utils/preferencesStorage';
import { TaskManager, Task } from '../utils/taskManager';
import { handleStorageError, handleValidationError, showSuccess } from '../utils/errorService';
import { fileDataParser, ParsedData } from '../utils/fileDataParser';
import { dataVisualizationService } from '../utils/dataVisualizationService';
import common from '@ohos.app.ability.common';

// 任务数据接口
interface TaskData {
  id: number;
  text: string;
  completed: boolean;
}

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

  // 数据可视化相关状态
  @State isProcessingFile: boolean = false;
  @State lastParsedData: ParsedData | null = null;

  aboutToAppear() {
    // 设置存储Context
    const context = getContext(this) as common.UIAbilityContext;
    getStorageInstance().setContext(context);

    // 设置通知服务Context
    this.pomodoroTimer.getNotificationService().setContext(context);

    this.initializeTimer();
    this.initializeTasks();
    this.setupPomodoroCallbacks();
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
      handleStorageError(error, 'HomePage初始化任务');
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
    try {
      // 确保定时器被正确清理
      if (this.pomodoroTimer.isTimerActive()) {
        console.warn('HomePage: Timer is still active, cleaning up');
      }
      this.pomodoroTimer.destroy();
      console.info('HomePage: About to disappear, resources cleaned up');
    } catch (error) {
      console.error('HomePage: Error during cleanup', error);
      // 即使出错也要强制清理
      try {
        this.pomodoroTimer.forceCleanup();
      } catch (cleanupError) {
        console.error('HomePage: Force cleanup failed', cleanupError);
      }
    }
  }

  private initializeTimer() {
    // 初始化计时器状态
    const stats = this.pomodoroTimer.getStats();
    this.pomodoroCompleted = stats.completedToday;
    this.timerValue = this.pomodoroTimer.getRemainingTime();

    // 检查当前状态
    this.currentTimerState = this.pomodoroTimer.getCurrentState();
    this.isTimerRunning = this.pomodoroTimer.isRunning();
    this.currentProgress = this.pomodoroTimer.getProgress();
  }

  private setupPomodoroCallbacks() {
    // 设置事件回调
    this.pomodoroTimer.setEventCallbacks({
      onTimerTick: (remainingTime: number, totalTime: number) => {
        this.timerValue = remainingTime;
        this.currentProgress = this.pomodoroTimer.getProgress();
      },
      onStateChange: (newState: PomodoroState) => {
        this.currentTimerState = newState;
        this.isTimerRunning = this.pomodoroTimer.isRunning();
      },
      onSessionComplete: () => {
        // 番茄钟完成后，自动选择下一个任务
        this.handlePomodoroComplete();
      }
    });
  }

  private handlePomodoroComplete() {
    // 更新完成计数
    const stats = this.pomodoroTimer.getStats();
    this.pomodoroCompleted = stats.completedToday;

    // 自动切换到下一个未完成的任务
    const nextTask = this.tasks.find(task => !task.completed);
    if (nextTask) {
      this.selectedTaskId = nextTask.id;
      console.info(`专注完成，自动切换到下一个任务: ${nextTask.text}`);
    } else {
      this.selectedTaskId = -1;
      console.info('所有任务已完成，清除任务选择');
    }
  }

  // 格式化时间显示
  private formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  // 重置计时器
  private resetTimer() {
    try {
      this.pomodoroTimer.reset();
      this.timerValue = this.pomodoroTimer.getRemainingTime();
      this.currentProgress = 0;
      this.currentTimerState = PomodoroState.IDLE;
      this.isTimerRunning = false;
    } catch (error) {
      console.error('重置计时器失败:', error);
    }
  }

  // 开始或暂停计时器
  private toggleTimer() {
    try {
      if (this.isTimerRunning) {
        this.pomodoroTimer.pause();
      } else {
        // 检查是否有选中的任务
        if (this.selectedTaskId === -1) {
          const firstIncompleteTask = this.tasks.find(task => !task.completed);
          if (firstIncompleteTask) {
            this.selectedTaskId = firstIncompleteTask.id;
            console.info(`自动选择任务: ${firstIncompleteTask.text}`);
          } else {
            console.warn('没有可专注的任务');
            return;
          }
        }

        const selectedTaskText = this.tasks.find(task => task.id === this.selectedTaskId)?.text || '未知任务';
        this.pomodoroTimer.startFocus();
        console.info(`开始专注任务: ${selectedTaskText} (ID: ${this.selectedTaskId})`);
      }
    } catch (error) {
      console.error('计时器操作失败:', error);
    }
  }

  // 添加任务
  private async addTask() {
    const trimmedText = this.newTaskText.trim();
    if (!trimmedText) {
      handleValidationError('任务内容不能为空');
      return;
    }

    try {
      const success = await this.taskManager.addTask(trimmedText);
      if (success) {
        this.newTaskText = '';
        this.tasks = this.taskManager.getTasks();
        showSuccess('任务添加成功');

        // 如果这是第一个未完成的任务且当前没有选中任务，自动选择它
        if (this.selectedTaskId === -1) {
          const firstIncompleteTask = this.tasks.find(task => !task.completed);
          if (firstIncompleteTask) {
            this.selectedTaskId = firstIncompleteTask.id;
          }
        }
      }
    } catch (error) {
      handleStorageError(error, '添加任务');
    }
  }

  // 删除任务
  private async deleteTask(taskId: number) {
    try {
      const success = await this.taskManager.deleteTask(taskId);
      if (success) {
        this.tasks = this.taskManager.getTasks();
        // 如果删除的是当前选中的任务，清除选择
        if (taskId === this.selectedTaskId) {
          this.selectedTaskId = -1;
          // 自动选择另一个未完成的任务
          const firstIncompleteTask = this.tasks.find(task => !task.completed);
          if (firstIncompleteTask) {
            this.selectedTaskId = firstIncompleteTask.id;
          }
        }
        showSuccess('任务删除成功');
      }
    } catch (error) {
      handleStorageError(error, '删除任务');
    }
  }

  // 选择任务
  private selectTask(taskId: number) {
    this.selectedTaskId = taskId;
    console.info(`选择任务ID: ${taskId}`);
  }

  // 任务完成状态切换
  private async toggleTaskComplete(taskId: number) {
    try {
      const success = await this.taskManager.toggleTaskComplete(taskId);
      if (success) {
        this.tasks = this.taskManager.getTasks(); // 刷新任务列表
        // 如果选择的任务被完成了，清除选择
        if (taskId === this.selectedTaskId) {
          this.selectedTaskId = -1;
          // 自动选择下一个未完成的任务
          const firstIncompleteTask = this.tasks.find(task => !task.completed);
          if (firstIncompleteTask) {
            this.selectedTaskId = firstIncompleteTask.id;
          }
        }
      }
    } catch (error) {
      console.error('切换任务完成状态失败:', error);
    }
  }

  // 选择并解析数据文件
  private async selectAndParseDataFile() {
    if (this.isProcessingFile) {
      return;
    }

    this.isProcessingFile = true;

    try {
      // 选择并解析文件
      const parsedData = await fileDataParser.selectAndParseFile();

      // 验证解析结果
      const validation = fileDataParser.validateParsedData(parsedData);
      if (!validation.isValid) {
        handleValidationError('文件解析失败:\n' + validation.errors.join('\n'));
        return;
      }

      // 保存解析结果
      this.lastParsedData = parsedData;
      showSuccess(`成功解析文件: ${parsedData.fileName}\n数据行数: ${parsedData.rowCount}, 列数: ${parsedData.columnCount}`);

      // 跳转到图表类型选择页面
      router.pushUrl({
        url: 'pages/ChartTypeSelectorPage',
        params: {
          parsedData: parsedData
        }
      });

    } catch (error) {
      console.error('[HomePage] 文件处理失败:', error);
      handleValidationError('文件处理失败: ' + (error as Error).message);
    } finally {
      this.isProcessingFile = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        // 顶部标题栏
        Row() {
          Text('番茄助手')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)

          Button('设置')
            .fontSize(16)
            .fontColor('#007DFF')
            .backgroundColor('transparent')
            .onClick(() => {
              router.pushUrl({ url: 'pages/SettingsPage' });
            })
        }
        .width('100%')
        .padding({ top: 20, bottom: 40 })

        // 主计时器卡片
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: 100, type: ProgressType.Ring })
              .width(200)
              .height(200)
              .style({ strokeWidth: 20 })
              .color('#333333')

            Progress({ value: this.currentProgress, total: 100, type: ProgressType.Ring })
              .width(200)
              .height(200)
              .style({ strokeWidth: 20 })
              .color('#007DFF')

            Column() {
              Text(this.formatTime(this.timerValue))
                .fontSize(40)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)

              Text(this.currentTimerState === PomodoroState.FOCUSING ? '专注中' : '休息中')
                .fontSize(16)
                .fontColor('#CCCCCC')
                .margin({ top: 5 })
            }
          }
          .margin({ bottom: 50 })

          // 控制按钮
          Row() {
            Button('重置', { type: ButtonType.Capsule, stateEffect: true })
              .width(80)
              .height(40)
              .fontSize(14)
              .backgroundColor('#666666')
              .onClick(() => this.resetTimer())

            Button(this.isTimerRunning ? '暂停' : (this.currentTimerState === PomodoroState.IDLE ? '开始' : '继续'), { type: ButtonType.Capsule, stateEffect: true })
              .width(80)
              .height(40)
              .fontSize(14)
              .backgroundColor(this.isTimerRunning ? '#FF6B6B' : '#4CAF50')
              .margin({ left: 20, right: 20 })
              .onClick(() => this.toggleTimer())

            Button('专注', { type: ButtonType.Capsule, stateEffect: true })
              .width(80)
              .height(40)
              .fontSize(14)
              .backgroundColor('#007DFF')
              .onClick(() => {
                if (this.selectedTaskId === -1) {
                  const firstIncompleteTask = this.tasks.find(task => !task.completed);
                  if (firstIncompleteTask) {
                    this.selectedTaskId = firstIncompleteTask.id;
                  }
                }

                const selectedTask = this.tasks.find(task => task.id === this.selectedTaskId);
                if (selectedTask) {
                  const taskData: TaskData = { id: selectedTask.id, text: selectedTask.text, completed: selectedTask.completed };
                  console.info(`开始专注任务: ${selectedTask.text} (ID: ${this.selectedTaskId})`);

                  router.pushUrl({
                    url: 'pages/FocusProgressPage',
                    params: {
                      taskData: taskData,
                      taskId: this.selectedTaskId
                    }
                  });
                } else {
                  console.warn('没有选中的任务');
                }
              })
          }
        }
        .margin({ bottom: 40 })

        // 番茄钟统计
        Column() {
          Text('今日进度')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 10 })

          Text(`已完成 ${this.pomodoroCompleted} 个，目标 ${this.pomodoroTarget} 个`)
            .fontSize(16)
            .fontColor('#CCCCCC')
            .margin({ bottom: 15 })

          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: (this.pomodoroCompleted / this.pomodoroTarget) * 100, type: ProgressType.Ring })
              .width(100)
              .height(100)
              .style({ strokeWidth: 8 })
              .color('#007DFF')

            Text(`${this.pomodoroCompleted}/${this.pomodoroTarget}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .margin({ bottom: 20 })

        // 今日任务跳转按钮
        Button() {
          Row() {
            Text('🍅 今日番茄记录')
              .fontSize(18)
              .fontColor(Color.White)
              .layoutWeight(1)
            Text('→')
              .fontSize(18)
              .fontColor('#007DFF')
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .type(ButtonType.Normal)
        .backgroundColor('#2A2A2A')
        .borderRadius(12)
        .height(50)
        .margin({ bottom: 15 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/PomodoroHistoryPage' });
        })

        // 数据可视化入口按钮
        Button() {
          Row() {
            Text('📊 数据可视化')
              .fontSize(18)
              .fontColor(Color.White)
              .layoutWeight(1)
            if (this.isProcessingFile) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#007DFF')
            } else {
              Text('→')
                .fontSize(18)
                .fontColor('#007DFF')
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .type(ButtonType.Normal)
        .backgroundColor(this.isProcessingFile ? '#333333' : '#2A2A2A')
        .borderRadius(12)
        .height(50)
        .margin({ bottom: 20 })
        .enabled(!this.isProcessingFile)
        .onClick(() => {
          this.selectAndParseDataFile();
        })

        // 任务管理
        Column() {
          Text('今日任务')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })

          // 任务列表
          Column() {
            ForEach(this.tasks, (item: Task) => {
              Row() {
                // 任务选择和内容
                Row() {
                  // 选择指示器
                  Circle({ width: 8, height: 8 })
                    .fill(this.selectedTaskId === item.id ? '#007DFF' : '#666666')
                    .margin({ right: 10 })

                  // 任务文本
                  Text(item.text)
                    .fontSize(16)
                    .fontColor(item.completed ? '#888888' : Color.White)
                    .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
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
                .width('100%')
                .padding({ top: 8, bottom: 8 })
                .backgroundColor(this.selectedTaskId === item.id ? '#2A2A2A' : 'transparent')
                .borderRadius(8)
                .padding({ left: 8, right: 8 })
              }
            }, (item: Task) => item.id.toString())

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
            .width('100%')
            .margin({ top: 20, bottom: 10 })
          }
          .width('100%')
        }
        .width('90%')
        .padding(20)
        .backgroundColor('#252525')
        .borderRadius(15)
      }
      .width('100%')
      .padding({ left: 15, right: 15, bottom: 20 }) // 添加底部内边距，确保内容不被底部导航栏遮挡
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .backgroundColor('#1C1C1C')
    .height('100%')
  }
}