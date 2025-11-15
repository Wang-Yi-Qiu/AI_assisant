import router from '@ohos.router';

@Entry
@Component
struct FocusProgressPage {
  @State timerValue: number = 25 * 60; // 25分钟
  @State isPaused: boolean = false;
  @State currentTask: string = "设计一个新的Logo"; // 示例任务

  private timerId: number = -1;

  aboutToAppear() {
    this.startTimer();
  }

  aboutToDisappear() {
    this.stopTimer();
  }

  // 启动计时器
  startTimer() {
    if (this.timerId === -1) {
      this.timerId = setInterval(() => {
        if (!this.isPaused && this.timerValue > 0) {
          this.timerValue--;
        } else if (this.timerValue === 0) {
          this.stopTimer();
          console.info('番茄钟计时结束');
        }
      }, 1000);
    }
  }

  // 停止计时器
  stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  // 格式化时间 MM:SS
  formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    const formattedMinutes = String(minutes).padStart(2, '0');
    const formattedSeconds = String(remainingSeconds).padStart(2, '0');
    return `${formattedMinutes}:${formattedSeconds}`;
  }

  // 暂停/继续
  togglePause() {
    this.isPaused = !this.isPaused;
  }

  // 放弃
  abandonFocus() {
    this.stopTimer();
    router.back();
  }

  build() {
    Column() {
      // 倒计时
      Text(this.formatTime(this.timerValue))
        .fontSize(80)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: '30%' })

      // 当前任务
      Text(`当前任务: ${this.currentTask}`)
        .fontSize(16)
        .fontColor(Color.Gray)
        .margin({ top: 20, bottom: '35%' })

      // 底部环境音效（暂不实现）
      Row() {
        // 示例图标
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
          .width('45%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#252525')
          .onClick(() => this.abandonFocus())

        Button(this.isPaused ? '继续' : '暂停', { type: ButtonType.Capsule, stateEffect: true })
          .width('45%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#007DFF')
          .onClick(() => this.togglePause())
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
    .alignItems(HorizontalAlign.Center)
  }
}