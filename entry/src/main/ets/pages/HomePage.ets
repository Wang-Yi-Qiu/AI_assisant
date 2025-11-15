import router from '@ohos.router';

// 任务数据结构
export class Task {
  id: number;
  text: string;
  completed: boolean;

  constructor(id: number, text: string, completed: boolean) {
    this.id = id;
    this.text = text;
    this.completed = completed;
  }
}

@Component
export struct HomePage {
  @State timerValue: number = 25 * 60; // 25分钟的秒数
  @State pomodoroTarget: number = 8;
  @State pomodoroCompleted: number = 3;
  @State tasks: Task[] = [
    new Task(1, '设计番茄钟界面', false),
    new Task(2, '准备周会演示文稿', true)
  ];
  @State newTaskText: string = '';

  // 添加任务
  addTask() {
    if (this.newTaskText.trim() === '') return;
    const newId = this.tasks.length > 0 ? Math.max(...this.tasks.map(t => t.id)) + 1 : 1;
    this.tasks.push(new Task(newId, this.newTaskText.trim(), false));
    this.newTaskText = ''; // 清空输入框
  }

  // 删除任务
  deleteTask(taskId: number) {
    this.tasks = this.tasks.filter(task => task.id !== taskId);
  }

  // 将秒格式化为 MM:SS
  formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    const formattedMinutes = String(minutes).padStart(2, '0');
    const formattedSeconds = String(remainingSeconds).padStart(2, '0');
    return `${formattedMinutes}:${formattedSeconds}`;
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
            router.pushNamedRoute({ name: 'SettingsPage' });
          })
      }
      .width('90%')
      .padding({ top: 20, bottom: 40 })

      // 计时器圆环
      Stack({ alignContent: Alignment.Center }) {
        Progress({ value: 100, type: ProgressType.Ring })
          .width(280)
          .style({ strokeWidth: 20 })
          .color('#1F3C53')

        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(280)
          .style({ strokeWidth: 20 })
          .color('#007DFF')

        Text(this.formatTime(this.timerValue))
          .fontSize(60)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .margin({ bottom: 50 })

      // 开始按钮
      Button('开始', { type: ButtonType.Capsule, stateEffect: true })
        .width('80%')
        .height(50)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#007DFF')
        .margin({ bottom: 40 })
        .onClick(() => {
          router.pushNamedRoute({ name: 'FocusProgressPage' });
        })

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
      router.pushNamedRoute({ name: 'PomodoroStatsPage' });
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
            Checkbox({ name: `task_${item.id}`, group: 'tasks' })
              .select(item.completed)
              .selectedColor('#007DFF')
              .onChange((isSelected: boolean) => {
                const taskIndex = this.tasks.findIndex(t => t.id === item.id);
                if (taskIndex !== -1) {
                  this.tasks[taskIndex].completed = isSelected;
                  this.tasks = [...this.tasks]; // 强制刷新
                }
              })

            Text(item.text)
              .fontSize(14)
              .fontColor(item.completed ? Color.Gray : Color.White)
              .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
              .margin({ left: 10 })

            Blank()

            Text('×')
              .fontSize(20)
              .fontColor(Color.Gray)
              .onClick(() => this.deleteTask(item.id))
          }
          .alignItems(VerticalAlign.Center)
          .padding({ top: 8, bottom: 8 })
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