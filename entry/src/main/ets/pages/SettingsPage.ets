import router from '@ohos.router';
import { PomodoroTimerService } from '../utils/pomodoroTimerService';
import { getStorageInstance } from '../utils/preferencesStorage';
import common from '@ohos.app.ability.common';

@Entry
@Component
export struct SettingsPage {
  private pomodoroTimer: PomodoroTimerService = PomodoroTimerService.getInstance();

  @State pomodoroDuration: number = 25;
  @State shortBreakDuration: number = 5;
  @State longBreakDuration: number = 15;
  @State longBreakInterval: number = 4;
  @State autoStartBreak: boolean = false;
  @State autoStartFocus: boolean = false;
  @State enableSound: boolean = true;
  @State enableVibration: boolean = true;

  aboutToAppear() {
    // 设置存储Context
    const context = getContext(this) as common.UIAbilityContext;
    getStorageInstance().setContext(context);

    this.loadSettings();
  }

  aboutToDisappear() {
    this.pomodoroTimer.destroy();
  }

  private loadSettings() {
    const settings = this.pomodoroTimer.getSettings();
    this.pomodoroDuration = settings.focusDuration;
    this.shortBreakDuration = settings.shortBreakDuration;
    this.longBreakDuration = settings.longBreakDuration;
    this.longBreakInterval = settings.longBreakInterval;
    this.autoStartBreak = settings.autoStartBreak;
    this.autoStartFocus = settings.autoStartFocus;
    this.enableSound = settings.enableSound;
    this.enableVibration = settings.enableVibration;
  }

  private async saveSettings() {
    try {
      await this.pomodoroTimer.updateSettings({
        focusDuration: this.pomodoroDuration,
        shortBreakDuration: this.shortBreakDuration,
        longBreakDuration: this.longBreakDuration,
        longBreakInterval: this.longBreakInterval,
        autoStartBreak: this.autoStartBreak,
        autoStartFocus: this.autoStartFocus,
        enableSound: this.enableSound,
        enableVibration: this.enableVibration
      });
      console.info('设置已保存');
    } catch (error) {
      console.error('保存设置失败:', error);
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Color.White)
          .onClick(() => {
            router.pushUrl({ url: 'pages/Index' });
          })

        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 20 })
        Blank()
      }
      .width('90%').padding({ top: 20, bottom: 40 })

      // 可滚动的设置内容区域
      Scroll() {
        Column() {
          // 时间设置
          Column() {
            Text('时间设置')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 20 })

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
                  this.pomodoroDuration = Math.max(1, Math.min(60, parseInt(value) || 25));
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
                  this.shortBreakDuration = Math.max(1, Math.min(30, parseInt(value) || 5));
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
                  this.longBreakDuration = Math.max(1, Math.min(60, parseInt(value) || 15));
                })
            }.width('100%').margin({ bottom: 20 })

            // 长休息间隔
            Row() {
              Text('长休息间隔 (个番茄钟)').fontSize(16).fontColor(Color.White)
              Blank()
              TextInput({ text: this.longBreakInterval.toString() })
                .type(InputType.Number)
                .width(80)
                .height(40)
                .backgroundColor('#333')
                .fontColor(Color.White)
                .onChange((value: string) => {
                  this.longBreakInterval = Math.max(2, Math.min(10, parseInt(value) || 4));
                })
            }.width('100%').margin({ bottom: 20 })

          }.width('90%').padding(20).backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })

          // 自动设置
          Column() {
            Text('自动设置')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 20 })

            // 自动开始休息
            Row() {
              Column() {
                Text('自动开始休息').fontSize(16).fontColor(Color.White).alignSelf(ItemAlign.Start)
                Text('专注结束后自动开始休息').fontSize(12).fontColor(Color.Gray).alignSelf(ItemAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.autoStartBreak })
                .onChange((isOn: boolean) => {
                  this.autoStartBreak = isOn;
                })
            }.width('100%').margin({ bottom: 20 })

            // 自动开始专注
            Row() {
              Column() {
                Text('自动开始专注').fontSize(16).fontColor(Color.White).alignSelf(ItemAlign.Start)
                Text('休息结束后自动开始专注').fontSize(12).fontColor(Color.Gray).alignSelf(ItemAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.autoStartFocus })
                .onChange((isOn: boolean) => {
                  this.autoStartFocus = isOn;
                })
            }.width('100%').margin({ bottom: 20 })

          }.width('90%').padding(20).backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })

          // 通知设置
          Column() {
            Text('通知设置')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 20 })

            // 声音提醒
            Row() {
              Column() {
                Text('声音提醒').fontSize(16).fontColor(Color.White).alignSelf(ItemAlign.Start)
                Text('完成时播放提示音').fontSize(12).fontColor(Color.Gray).alignSelf(ItemAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.enableSound })
                .onChange((isOn: boolean) => {
                  this.enableSound = isOn;
                })
            }.width('100%').margin({ bottom: 20 })

            // 震动提醒
            Row() {
              Column() {
                Text('震动提醒').fontSize(16).fontColor(Color.White).alignSelf(ItemAlign.Start)
                Text('完成时震动提醒').fontSize(12).fontColor(Color.Gray).alignSelf(ItemAlign.Start)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.enableVibration })
                .onChange((isOn: boolean) => {
                  this.enableVibration = isOn;
                })
            }.width('100%').margin({ bottom: 20 })

          }.width('90%').padding(20).backgroundColor('#252525').borderRadius(15).margin({ bottom: 40 })

          // 保存按钮
          Button('保存设置', { type: ButtonType.Capsule })
            .width('80%')
            .height(50)
            .backgroundColor('#007DFF')
            .onClick(async () => {
              await this.saveSettings();
              router.pushUrl({ url: 'pages/Index' });
            })

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