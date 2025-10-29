/**
 * 图表页：渲染ECharts并支持导出
 * @module ChartPage
 */

import { ChartConfig, getLastGeneratedConfig } from '../utils/aiService';
import { exportPng, exportJson } from './ChartPage';
import router from '@ohos.router';

let currentOption: ChartConfig | null = null;

@Entry
@Component
struct ChartPage {
  @State chartConfig: ChartConfig | null = null;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear() {
    // 尝试从路由参数或最近生成的配置获取
    const params = router.getParams() as { chartConfig?: ChartConfig } | null;
    if (params?.chartConfig) {
      this.chartConfig = params.chartConfig;
      currentOption = params.chartConfig;
    } else {
      const lastConfig = getLastGeneratedConfig();
      if (lastConfig) {
        this.chartConfig = lastConfig;
        currentOption = lastConfig;
      } else {
        this.errorMessage = '未找到图表配置，请先生成图表';
      }
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Button('返回')
          .type(ButtonType.Text)
          .fontSize(16)
          .onClick(() => {
            router.back();
          })
        
        Blank()
        
        Text('图表预览')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        Button('导出')
          .type(ButtonType.Text)
          .fontSize(16)
          .onClick(() => {
            this.onExport();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      // 图表显示区域
      if (this.errorMessage) {
        Column() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#F44336')
            .padding(20)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.chartConfig) {
        Column() {
          Text('图表渲染区域（WebView 集成待完成）')
            .fontSize(16)
            .fontColor('#666666')
            .padding(20)
          
          Text(`标题: ${this.chartConfig.title?.text || '未命名'}`)
            .fontSize(14)
            .margin({ top: 16 })
          
          Text(`类型: ${this.chartConfig.series?.[0]?.type || '未知'}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 8 })
          
          // TODO: 集成 WebView 渲染 ECharts
          // Web({ src: 'xxx.html' })
          //   .onControllerReady((controller) => {
          //     controller.runJavaScript(`chart.setOption(${JSON.stringify(this.chartConfig)})`);
          //   })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF')
        .margin({ top: 16, left: 16, right: 16 })
        .borderRadius(8)
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  async onExport() {
    if (!this.chartConfig) {
      this.errorMessage = '没有可导出的图表';
      return;
    }

    // TODO: 实现导出功能（PNG/PDF/JSON）
    try {
      const pngData = await exportPng();
      // TODO: 保存文件
      console.log('图表已导出（占位实现）');
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '导出失败';
    }
  }
}

// 导出工具函数（保持向后兼容）
export function setChartOption(option: ChartConfig): void {
  if (!option || !option.series || option.series.length === 0) {
    throw new Error('图表配置无效：缺少series数据');
  }

  currentOption = option;
  console.log('图表配置已设置（占位实现）');
}

export function getCurrentOption(): ChartConfig | null {
  return currentOption;
}

export async function exportPng(): Promise<string> {
  if (!currentOption) {
    throw new Error('没有可导出的图表，请先生成图表');
  }
  
  // TODO: 桥接到WebView的chart.getDataURL
  return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
}

export function exportJson(): ChartConfig {
  if (!currentOption) {
    throw new Error('没有可导出的图表配置');
  }
  return currentOption;
}

export function loadChartFromRecord(config: ChartConfig): void {
  setChartOption(config);
}
