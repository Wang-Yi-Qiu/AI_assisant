import router from '@ohos.router';

@Entry
@Component
export struct SettingsPage {
  @State pomodoroDuration: number = 25;
  @State shortBreakDuration: number = 5;
  @State longBreakDuration: number = 15;

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Color.White)
          .onClick(() => router.back())

        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 20 })
        Blank()
      }
      .width('90%').padding({ top: 20, bottom: 40 })

      // 可滚动的设置内容区域
      Scroll() {
        Column() {
          // 设置选项
          Column() {
            // 番茄时长
            Row() {
              Text('番茄时长 (分钟)').fontSize(16).fontColor(Color.White)
              Blank()
              TextInput({ text: this.pomodoroDuration.toString() })
                .type(InputType.Number)
                .width(80)
                .height(40)
                .backgroundColor('#333')
                .fontColor(Color.White)
                .onChange((value: string) => {
                  this.pomodoroDuration = parseInt(value) || 25;
                })
            }.width('100%').margin({ bottom: 20 })

            // 短休息时长
            Row() {
              Text('短休息时长 (分钟)').fontSize(16).fontColor(Color.White)
              Blank()
              TextInput({ text: this.shortBreakDuration.toString() })
                .type(InputType.Number)
                .width(80)
                .height(40)
                .backgroundColor('#333')
                .fontColor(Color.White)
                .onChange((value: string) => {
                  this.shortBreakDuration = parseInt(value) || 5;
                })
            }.width('100%').margin({ bottom: 20 })

            // 长休息时长
            Row() {
              Text('长休息时长 (分钟)').fontSize(16).fontColor(Color.White)
              Blank()
              TextInput({ text: this.longBreakDuration.toString() })
                .type(InputType.Number)
                .width(80)
                .height(40)
                .backgroundColor('#333')
                .fontColor(Color.White)
                .onChange((value: string) => {
                  this.longBreakDuration = parseInt(value) || 15;
                })
            }.width('100%').margin({ bottom: 40 })

            Button('保存', { type: ButtonType.Capsule })
              .width('80%')
              .height(50)
              .backgroundColor('#007DFF')
              .onClick(() => {
                // 在这里添加保存设置的逻辑
                console.info(`设置已保存: ${this.pomodoroDuration}, ${this.shortBreakDuration}, ${this.longBreakDuration}`);
                router.back();
              })

          }.width('90%')

          // 底部间距，确保内容不会被底部导航栏遮挡
          Column()
            .height(100)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
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
    .alignItems(HorizontalAlign.Center)
  }
}