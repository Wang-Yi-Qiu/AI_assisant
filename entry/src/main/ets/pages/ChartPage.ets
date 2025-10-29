/**
 * 图表页：渲染ECharts并支持导出
 * @module ChartPage
 */

import { ChartConfig } from '../utils/aiService';
import router from '@ohos.router';

let currentOption: ChartConfig | null = null;

/**
 * 设置图表配置并渲染
 * @param option ECharts配置对象
 */
export function setChartOption(option: ChartConfig): void {
  if (!option || !option.series || option.series.length === 0) {
    throw new Error('图表配置无效：缺少series数据');
  }

  currentOption = option;
  
  // TODO: 桥接到WebView并调用chart.setOption
  // 在HarmonyOS中：
  // import webview from '@ohos.web.webview';
  // const webComponent = findComponentById('chartWebView');
  // await webComponent.executeJavaScript(`
  //   if (!window.chart) {
  //     window.chart = echarts.init(document.getElementById('chart-container'));
  //   }
  //   window.chart.setOption(${JSON.stringify(option)});
  // `);
  
  console.log('图表配置已设置（占位实现）');
}

/**
 * 获取当前图表配置
 */
export function getCurrentOption(): ChartConfig | null {
  return currentOption;
}

/**
 * 导出图表为PNG（base64编码）
 * @returns Promise<string> base64编码的PNG图片数据URL
 */
export async function exportPng(): Promise<string> {
  if (!currentOption) {
    throw new Error('没有可导出的图表，请先生成图表');
  }

  // TODO: 桥接到WebView的chart.getDataURL
  // await webComponent.executeJavaScript(`
  //   return window.chart.getDataURL({
  //     type: 'png',
  //     backgroundColor: '#fff',
  //     pixelRatio: 2
  //   });
  // `);
  
  // 占位返回值
  return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
}

/**
 * 导出图表配置为JSON
 */
export function exportJson(): ChartConfig {
  if (!currentOption) {
    throw new Error('没有可导出的图表配置');
  }
  return currentOption;
}

/**
 * 从历史记录加载图表配置
 */
export function loadChartFromRecord(config: ChartConfig): void {
  setChartOption(config);
}

@Entry
@Component
struct ChartPage {
  build() {
    Scroll() {
      Column() {
      // 顶部栏
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .onClick(() => {
            router.back();
          })
        Text('图表预览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

        // 内容
        if (!currentOption) {
        Column() {
          Text('暂无图表配置，请先生成或从历史进入')
            .fontSize(14)
            .fontColor('#666666')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        } else {
          Column() {
          // 这里应集成 WebView/ECharts，当前为占位
          Text('图表已就绪（占位渲染）')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 12 })

            Row() {
            Button('导出 JSON')
              .onClick(() => {
                try {
                  const json = exportJson();
                  console.log('导出JSON: ' + JSON.stringify(json));
                } catch (e) {
                  console.error('导出失败', e);
                }
              })

            Blank()

            Button('导出 PNG')
              .onClick(async () => {
                try {
                  const dataUrl = await exportPng();
                  console.log('导出PNG: ' + dataUrl.substring(0, 64) + '...');
                } catch (e) {
                  console.error('导出失败', e);
                }
              })
            }
            .width('100%')
          }
          .width('100%')
          .height('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
  }
}
