import router from '@ohos.router';

// 模拟任务分布数据
interface TaskDistribution {
  name: string;
  value: number;
  color: string;
}

// 模拟完成任务排行数据
interface CompletedTask {
  rank: number;
  name: string;
  count: number;
}

@Entry
@Component
export struct PomodoroStatsPage {
  @State selectedTab: 'week' | 'month' | 'year' = 'month';
  @State todayFocusMinutes: number = 128;
  @State yesterdayIncreasePercent: number = 15;
  @State focusTargetPercent: number = 75;

  // 模拟周专注趋势数据 (过去7天)
  private weeklyFocusData: number[] = [60, 90, 75, 110, 120, 150, 128];

  // 模拟任务分布数据
  private taskDistributionData: TaskDistribution[] = [
    { name: '项目设计', value: 45, color: '#8A2BE2' },
    { name: '需求撰写', value: 30, color: '#FF6347' },
    { name: '用户反馈', value: 25, color: '#32CD32' },
  ];

  // 模拟完成任务排行
  private completedTasksData: CompletedTask[] = [
    { rank: 1, name: '设计最终模型', count: 12 },
    { rank: 2, name: '撰写项目提案', count: 8 },
    { rank: 3, name: '回顾用户反馈', count: 5 },
  ];

  // Helper to create pie chart path
  private getPath(startAngle: number, sweepAngle: number): string {
    const radius = 75;
    const centerX = 75;
    const centerY = 75;
    const startX = centerX + radius * Math.cos(startAngle * Math.PI / 180);
    const startY = centerY + radius * Math.sin(startAngle * Math.PI / 180);
    const endX = centerX + radius * Math.cos((startAngle + sweepAngle) * Math.PI / 180);
    const endY = centerY + radius * Math.sin((startAngle + sweepAngle) * Math.PI / 180);
    const largeArcFlag = sweepAngle > 180 ? 1 : 0;

    return `M ${centerX} ${centerY} L ${startX} ${startY} A ${radius} ${radius} 0 ${largeArcFlag} 1 ${endX} ${endY} Z`;
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Color.White)
          .onClick(() => router.back())

        Text('统计').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 20 })
        Blank()
        Text('⋯')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width('90%').padding({ top: 20, bottom: 20 })

      // 时间切换器
      Row() {
        Button('周', { type: ButtonType.Capsule })
          .backgroundColor(this.selectedTab === 'week' ? '#007DFF' : '#252525')
          .onClick(() => this.selectedTab = 'week')
        Button('月', { type: ButtonType.Capsule })
          .backgroundColor(this.selectedTab === 'month' ? '#007DFF' : '#252525')
          .onClick(() => this.selectedTab = 'month')
          .margin({ left: 10, right: 10 })
        Button('年', { type: ButtonType.Capsule })
          .backgroundColor(this.selectedTab === 'year' ? '#007DFF' : '#252525')
          .onClick(() => this.selectedTab = 'year')
      }.margin({ bottom: 20 })

      Scroll() {
        Column(){
          // 今日专注
          this.TodayFocusCard()

          // 周专注趋势
          this.WeeklyFocusChart()

          // 任务分布
          this.TaskDistributionCard()

          // 完成任务排行
          this.CompletedTasksCard()
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.width('100%')

    }
    .width('100%').height('100%').backgroundColor('#1C1C1C').alignItems(HorizontalAlign.Center)
  }

  @Builder
  TodayFocusCard() {
    Column() {
      Row() {
        Text('今日专注').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Blank()
        Text('查看详情 >').fontSize(12).fontColor(Color.Gray)
      }.width('100%')

      Row() {
        Text(this.todayFocusMinutes.toString()).fontSize(40).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text('分钟').fontSize(14).fontColor(Color.Gray).margin({ left: 5, bottom: 5 })
      }.margin({ top: 10 }).alignItems(VerticalAlign.Bottom)

      Row(){
        Text('↑')
          .fontSize(16)
          .fontColor(Color.Green)
        Text(`比昨日提升 ${this.yesterdayIncreasePercent}%`).fontSize(12).fontColor(Color.Gray)
      }

      Stack({ alignContent: Alignment.Center }) {
        Progress({ value: this.focusTargetPercent, type: ProgressType.Ring })
          .width(80).style({ strokeWidth: 10 }).color('#007DFF')
        Column(){
          Text('目标').fontSize(12).fontColor(Color.Gray)
          Text(`${this.focusTargetPercent}%`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
      }.position({ top: 20, right: 20 })

    }
    .padding(20).width('90%').backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  WeeklyFocusChart() {
    Column() {
      Text('周专注趋势').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ bottom: 5 })
      Text('过去7天专注时长').fontSize(12).fontColor(Color.Gray)

      // 简单的条形图模拟
      Row() {
        ForEach(this.weeklyFocusData, (minutes: number) => {
          Column().width(20).height(minutes / 2).backgroundColor('#3399FF').borderRadius(5)
            .margin({ left: 5, right: 5 })
        }, (item: number, index: number) => index.toString())
      }.height(100).margin({ top: 20 }).alignItems(VerticalAlign.Bottom)

    }
    .padding(20).width('90%').backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TaskDistributionCard() {
    Column() {
      Text('任务分布').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)

      // 模拟饼图
      Stack(){
        Path().commands(this.getPath(-90, 360)).fill(this.taskDistributionData[0].color)
        Path().commands(this.getPath(-90, 360 * 0.75)).fill(this.taskDistributionData[1].color)
        Path().commands(this.getPath(-90, 360 * 0.45)).fill(this.taskDistributionData[2].color)
        Circle().fill(Color.White).width(80).height(80)
      }.width(150).height(150).margin({ top: 20, bottom: 20 })

      ForEach(this.taskDistributionData, (item: TaskDistribution) => {
        Row() {
          Circle().width(10).height(10).fill(item.color).margin({ right: 10 })
          Text(`${item.name} (${item.value}%)`).fontSize(12).fontColor(Color.White)
        }.margin({ bottom: 5 }).alignItems(VerticalAlign.Center)
      }, (item: TaskDistribution) => item.name)
    }
    .padding(20).width('90%').backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  CompletedTasksCard() {
    Column() {
      Text('完成任务排行').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)

      ForEach(this.completedTasksData, (item: CompletedTask) => {
        Row() {
          Text(item.rank.toString()).width(20).height(20).backgroundColor('#333').borderRadius(10).textAlign(TextAlign.Center).fontColor(Color.White)
          Text(item.name).fontSize(14).fontColor(Color.White).margin({ left: 15 })
          Blank()
          Text(`${item.count} 次`).fontSize(12).fontColor(Color.Gray)
        }
        .width('100%').padding({ top: 10, bottom: 10 }).alignItems(VerticalAlign.Center)
      }, (item: CompletedTask) => item.rank.toString())

    }
    .padding(20).width('90%').backgroundColor('#252525').borderRadius(15).margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }
}