/**
 * 番茄钟完成记录页面
 * 展示今日完成的番茄钟历史记录
 * @module PomodoroHistoryPage
 */

import router from '@ohos.router';
import { PomodoroTimerService, CompletedPomodoro } from '../utils/pomodoroTimerService';

@Entry
@Component
export struct PomodoroHistoryPage {
  private pomodoroTimer: PomodoroTimerService = PomodoroTimerService.getInstance();
  @State completedPomodoros: CompletedPomodoro[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadTodayCompletedPomodoros();
  }

  private async loadTodayCompletedPomodoros(): Promise<void> {
    try {
      this.completedPomodoros = this.pomodoroTimer.getTodayCompletedPomodoros();
      console.info(`PomodoroHistoryPage: Loaded ${this.completedPomodoros.length} completed pomodoros`);
    } catch (error) {
      console.error('PomodoroHistoryPage: Failed to load completed pomodoros', error);
    } finally {
      this.isLoading = false;
    }
  }

  // 格式化时间显示
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  // 格式化日期显示
  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${month}月${day}日`;
  }

  // 获取番茄钟图标
  getPomodoroIcon(index: number): string {
    const icons = ['🍅', '🔥', '⭐', '💪', '🎯', '🚀', '✨', '🌟'];
    return icons[index % icons.length];
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Button() {
          Text('←')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .width(40)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Text('今日番茄记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank()
          .width(40) // 占位，保持标题居中
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 20, bottom: 20 })

      if (this.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
          .color('#007DFF')
          .margin({ top: 100 })

        Text('加载中...')
          .fontSize(16)
          .fontColor(Color.Gray)
          .margin({ top: 20 })
      } else if (this.completedPomodoros.length === 0) {
        // 空状态
        Column() {
          Text('🍅')
            .fontSize(80)
            .margin({ bottom: 20 })

          Text('今日还没有完成番茄钟')
            .fontSize(18)
            .fontColor(Color.White)
            .margin({ bottom: 10 })

          Text('开始专注，完成第一个番茄钟吧！')
            .fontSize(14)
            .fontColor(Color.Gray)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .margin({ top: 100 })
      } else {
        // 统计卡片
        this.StatsCard()

        Scroll() {
          Column() {
            Text('完成记录')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .alignSelf(ItemAlign.Start)
              .margin({ left: 20, bottom: 15 })

            ForEach(this.completedPomodoros, (item: CompletedPomodoro, index?: number) => {
              this.PomodoroRecordCard(item, index || 0)
            })
          }
          .width('100%')
          .padding({ bottom: 30 })
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
  }

  @Builder
  StatsCard() {
    Column() {
      Row() {
        Column() {
          Text(this.completedPomodoros.length.toString())
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')

          Text('完成番茄数')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 5 })
        }
        .layoutWeight(1)

        Column() {
          const totalMinutes = this.completedPomodoros.reduce((sum, item) => sum + item.duration, 0);
          Text(totalMinutes.toString())
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4ECDC4')

          Text('专注分钟')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 5 })
        }
        .layoutWeight(1)

        Column() {
          const uniqueTasks = new Set(this.completedPomodoros.map(item => item.taskId)).size;
          Text(uniqueTasks.toString())
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B6B')

          Text('涉及任务')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 5 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('90%')
    .padding(20)
    .backgroundColor('#252525')
    .borderRadius(15)
    .margin({ bottom: 20 })
  }

  @Builder
  PomodoroRecordCard(record: CompletedPomodoro, index: number) {
    Row() {
      // 番茄钟图标
      Text(this.getPomodoroIcon(index))
        .fontSize(32)
        .margin({ right: 15 })

      // 内容区域
      Column() {
        Text(record.taskText)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .alignSelf(ItemAlign.Start)

        Row() {
          Text(`${record.duration} 分钟`)
            .fontSize(14)
            .fontColor('#007DFF')

          Text(' • ')
            .fontSize(14)
            .fontColor(Color.Gray)

          Text(this.formatTime(record.completedAt))
            .fontSize(14)
            .fontColor(Color.Gray)
        }
        .margin({ top: 5 })
        .alignSelf(ItemAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 完成标记
      Column() {
        Text('✓')
          .fontSize(16)
          .fontColor(Color.White)

        Text('完成')
          .fontSize(12)
          .fontColor('#4CAF50')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('90%')
    .padding(15)
    .backgroundColor('#2A2A2A')
    .borderRadius(12)
    .margin({ bottom: 10, left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
  }
}