/**
 * 历史页：列表展示与导航到历史图表记录
 * @module HistoryPage
 */

import { fetchCharts, ChartRecordRow } from '../utils/supabaseClient';
import { ChartConfig } from '../utils/aiService';
import { setChartOption } from './ChartPage';
import { BusinessError } from '@kit.BasicServicesKit';
import { deviceAdapter, DeviceType } from '../utils/deviceAdapter';
import { ErrorHandler } from '../utils/errorHandler';

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
  // 设备适配
  private layoutConfig = deviceAdapter.getLayoutConfig();
  private deviceType = deviceAdapter.getDeviceType();
  private needsFocus = deviceAdapter.needsFocusNavigation();

  aboutToAppear() {
    this.loadCharts();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('历史记录')
          .fontSize(this.layoutConfig.fontSize.title)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(this.deviceType === DeviceType.WEARABLE ? 48 : 56)
      .padding({ 
        left: this.layoutConfig.padding.medium, 
        right: this.layoutConfig.padding.medium 
      })
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
            .fontSize(this.layoutConfig.fontSize.medium)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage) {
        Column() {
          Text(this.errorMessage)
            .fontSize(this.layoutConfig.fontSize.medium)
            .fontColor('#F44336')
          Button('重试')
            .type(ButtonType.Normal)
            .fontSize(this.layoutConfig.fontSize.medium)
            .margin({ top: this.layoutConfig.spacing.medium })
            .onClick(() => {
              this.loadCharts();
            })
            .focusable(this.needsFocus)
            .focusOnTouch(this.needsFocus)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.chartList.length === 0) {
        Column() {
          Text('暂无历史记录')
            .fontSize(this.layoutConfig.fontSize.medium)
            .fontColor('#999999')
          Text('去首页生成第一个图表吧！')
            .fontSize(this.layoutConfig.fontSize.small)
            .fontColor('#CCCCCC')
            .margin({ top: this.layoutConfig.spacing.small })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: this.layoutConfig.spacing.medium }) {
          ForEach(this.chartList, (item: ChartRecord) => {
            ListItem() {
              this.buildChartItem(item);
            }
          }, (item: ChartRecord) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ 
          left: this.layoutConfig.padding.medium, 
          right: this.layoutConfig.padding.medium, 
          top: this.layoutConfig.spacing.small 
        })
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
          .fontSize(this.layoutConfig.fontSize.large)
          .fontWeight(FontWeight.Medium)
          .maxLines(this.deviceType === DeviceType.WEARABLE ? 2 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .alignSelf(ItemAlign.Start)
        Text(`类型: ${item.type || '未知'} | ${this.formatDate(item.createdAt)}`)
          .fontSize(this.layoutConfig.fontSize.small)
          .fontColor('#666666')
          .margin({ top: this.layoutConfig.spacing.small })
          .alignSelf(ItemAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.startIcon'))
        .width(this.deviceType === DeviceType.WEARABLE ? 20 : 24)
        .height(this.deviceType === DeviceType.WEARABLE ? 20 : 24)
    }
    .width('100%')
    .padding(this.layoutConfig.padding.medium)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      setChartOption(item.chartConfig);
      // 使用 getUIContext().getRouter().pushUrl() 替代已弃用的 router.pushPathByName()
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ChartPage'
      }).catch((err: BusinessError) => {
        console.error('跳转到图表页失败:', err);
        this.errorMessage = '无法打开图表页';
      });
    })
    // 添加焦点支持（TV/车机）
    .focusable(this.needsFocus)
    .focusOnTouch(this.needsFocus)
  }

  async loadCharts() {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const charts = await fetchCharts(10);
      this.chartList = charts.map((chart: ChartRecordRow): ChartRecord => ({
        id: chart.id ?? '',
        title: chart.title ?? chart.chart_config?.title?.text ?? '未命名图表',
        type: chart.type ?? chart.chart_config?.series?.[0]?.type ?? 'unknown',
        createdAt: chart.created_at ?? new Date().toISOString(),
        chartConfig: chart.chart_config ?? chart.chartConfig ?? { series: [{ type: 'unknown' }] },
      }));
    } catch (error) {
      // 使用ErrorHandler处理错误，获取用户友好的错误消息
      const appError = ErrorHandler.handle(error, 'loadCharts');
      this.errorMessage = appError.userMessage || (error instanceof Error ? error.message : '加载失败，请稍后重试');
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
