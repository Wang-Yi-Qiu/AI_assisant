/**
 * 历史页：列表展示与导航到历史图表记录
 * @module HistoryPage
 */

import { fetchCharts } from '../utils/supabaseClient';
import { ChartConfig } from '../utils/aiService';
import { setChartOption } from './ChartPage';
import router from '@ohos.router';

export interface ChartRecord {
  id: string;
  title: string;
  type: string;
  createdAt: string;
  chartConfig: ChartConfig;
}

@Entry
@Component
struct HistoryPage {
  @State chartList: ChartRecord[] = [];
  @State isLoading: boolean = true;
  @State errorMessage: string = '';

  aboutToAppear() {
    this.loadCharts();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('历史记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 8 })
          Text('加载中...')
            .fontSize(14)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#F44336')
          Button('重试')
            .type(ButtonType.Normal)
            .margin({ top: 16 })
            .onClick(() => {
              this.loadCharts();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.chartList.length === 0) {
        Column() {
          Text('暂无历史记录')
            .fontSize(14)
            .fontColor('#999999')
          Text('去首页生成第一个图表吧！')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.chartList, (item: ChartRecord) => {
            ListItem() {
              this.buildChartItem(item);
            }
          }, (item: ChartRecord) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  buildChartItem(item: ChartRecord) {
    Row() {
      Column() {
        Text(item.title || '未命名图表')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .alignSelf(ItemAlign.Start)
        Text(`类型: ${item.type || '未知'} | ${this.formatDate(item.createdAt)}`)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
          .alignSelf(ItemAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.startIcon'))
        .width(24)
        .height(24)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      setChartOption(item.chartConfig);
      router.pushUrl({
        url: 'pages/ChartPage'
      }).catch((err) => {
        console.error('跳转到图表页失败:', err);
        this.errorMessage = '无法打开图表页';
      });
    })
  }

  async loadCharts() {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const charts = await fetchCharts(10);
      this.chartList = charts.map((chart: any) => ({
        id: chart.id || '',
        title: chart.title || chart.chart_config?.title?.text || '未命名图表',
        type: chart.type || chart.chart_config?.series?.[0]?.type || 'unknown',
        createdAt: chart.created_at || new Date().toISOString(),
        chartConfig: chart.chart_config || chart.chartConfig || {},
      }));
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '加载失败，请稍后重试';
      console.error('加载历史记录失败:', error);
    } finally {
      this.isLoading = false;
    }
  }

  formatDate(dateString: string): string {
    try {
      const date = new Date(dateString);
      const month = date.getMonth() + 1;
      const day = date.getDate();
      const hours = date.getHours();
      const minutes = date.getMinutes();
      return `${month}/${day} ${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    } catch {
      return dateString;
    }
  }
}
