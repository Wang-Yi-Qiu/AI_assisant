/**
 * 番茄钟服务卡片UI组件
 * 提供桌面小卡片界面，显示计时状态和快捷操作
 */
@Component
@Entry
export default struct PomodoroTimerCard {
  formData: Record<string, any> = {};
  currentState: string = 'idle';
  formattedTime: string = '25:00';
  progress: number = 0;
  currentTask: string = '准备开始';
  isRunning: boolean = false;
  isPaused: boolean = false;
  completedToday: number = 0;
  stateText: string = '空闲';
  stateColor: string = '#9E9E9E';
  actionButtonText: string = '开始专注';
  secondaryActionButtonText: string = '';
  formInfo: any = {};

  aboutToAppear() {
    console.info('[PomodoroTimerCard] Component about to appear');
    this.updateFormData();
  }

  /**
   * 更新卡片数据
   */
  private updateFormData(): void {
    try {
      if (this.formInfo.formBindingData) {
        const data = this.formInfo.formBindingData.data || {};
        console.info('[PomodoroTimerCard] Updating form data:', JSON.stringify(data));

        this.formData = data;
        this.currentState = data.currentState || 'idle';
        this.formattedTime = data.formattedTime || '25:00';
        this.progress = parseFloat(data.progress) || 0;
        this.currentTask = data.currentTask || '准备开始';
        this.isRunning = data.isRunning || false;
        this.isPaused = data.isPaused || false;
        this.completedToday = data.completedToday || 0;
        this.stateText = data.stateText || '空闲';
        this.stateColor = data.stateColor || '#9E9E9E';
        this.actionButtonText = data.actionButtonText || '开始专注';
        this.secondaryActionButtonText = data.secondaryActionButtonText || '';
      }
    } catch (error) {
      console.error('[PomodoroTimerCard] Failed to update form data:', error);
      // 使用默认数据
      this.setDefaultData();
    }
  }

  /**
   * 设置默认数据
   */
  private setDefaultData(): void {
    this.currentState = 'idle';
    this.formattedTime = '25:00';
    this.progress = 0;
    this.currentTask = '准备开始';
    this.isRunning = false;
    this.isPaused = false;
    this.completedToday = 0;
    this.stateText = '空闲';
    this.stateColor = '#9E9E9E';
    this.actionButtonText = '开始专注';
    this.secondaryActionButtonText = '';
  }

  /**
   * 发送卡片事件
   */
  private sendFormEvent(action: string, parameters?: Record<string, any>): void {
    try {
      console.info('[PomodoroTimerCard] Sending form event:', action);
      // 卡片事件通过FormAbility处理，这里简化实现
    } catch (error) {
      console.error('[PomodoroTimerCard] Failed to send form event:', error);
    }
  }

  build() {
    Column() {
      // 卡片头部
      Row() {
        Column() {
          Text('番茄钟')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Text(`今日完成 ${this.completedToday} 个`)
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 状态指示器
        Text(this.stateText)
          .fontSize(14)
          .fontColor(this.stateColor)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 16 })

      // 计时器显示区域
      Column() {
        // 时间显示
        Text(this.formattedTime)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        // 进度条
        Progress({
          value: this.progress,
          total: 100,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(6)
          .color(this.stateColor)
          .backgroundColor('#F0F0F0')
          .margin({ bottom: 12 })

        // 当前任务
        Text(this.currentTask)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(12)
      .margin({ bottom: 16 })

      // 操作按钮区域
      Row() {
        // 主要操作按钮
        Button(this.actionButtonText)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.stateColor)
          .borderRadius(8)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            console.info('[PomodoroTimerCard] Primary button clicked:', this.actionButtonText);

            if (this.actionButtonText === '开始专注') {
              this.sendFormEvent('start_focus');
            } else if (this.actionButtonText === '暂停') {
              this.sendFormEvent('pause');
            } else if (this.actionButtonText === '继续') {
              if (this.isPaused) {
                this.sendFormEvent('resume');
              } else {
                this.sendFormEvent('start_focus');
              }
            }
          })

        // 次要操作按钮
        if (this.secondaryActionButtonText) {
          Button(this.secondaryActionButtonText)
            .fontSize(14)
            .fontColor('#666666')
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .height(40)
            .margin({ left: 8 })
            .onClick(() => {
              console.info('[PomodoroTimerCard] Secondary button clicked:', this.secondaryActionButtonText);
              this.sendFormEvent('skip');
            })
        }

        // 打开应用按钮
        Button('打开')
          .fontSize(14)
          .fontColor('#666666')
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .height(40)
          .margin({ left: 8 })
          .onClick(() => {
            console.info('[PomodoroTimerCard] Open app button clicked');
            this.sendFormEvent('open_app');
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor($r('app.color.start_window_background'))
    .borderRadius(12)
  }
}

/**
 * 简化的表单UI组件
 */
@Component
export struct SimplePomodoroForm {
  build() {
    // 简化版番茄钟表单
    Column() {
      Text('番茄钟')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 8 })

      Text('25:00')
        .fontSize(24)
        .fontColor('#F44336')
        .margin({ bottom: 8 })

      Progress({
        value: 30,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color('#F44336')
        .backgroundColor('#F0F0F0')
        .margin({ bottom: 12 })

      Button('开始专注')
        .width('100%')
        .height(36)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#F44336')
        .borderRadius(8)
        .onClick(() => {
          console.info('[SimplePomodoroForm] Start focus clicked');
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#FAFAFA')
    .borderRadius(12)
  }
}