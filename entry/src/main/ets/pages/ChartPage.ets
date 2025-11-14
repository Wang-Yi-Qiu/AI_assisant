/**
 * 图表页：渲染ECharts并支持导出
 * @module ChartPage
 */

import { ChartConfig } from '../utils/aiService';
import router from '@ohos.router';
import webview from '@ohos.web.webview';
import { BusinessError } from '@kit.BasicServicesKit';
import { FileManager } from '../utils/fileManager';
import { ErrorHandler, AppError } from '../utils/errorHandler';
import { performanceMonitor } from '../utils/performanceMonitor';
import { resourceManager, RESOURCES } from '../utils/resourceManager';

// 当前图表配置，全局状态保留
let currentOption: ChartConfig | null = null;

/**
 * 设置图表配置并渲染
 * @param option ECharts配置对象
 * @param controller WebView控制器实例
 */
export async function setChartOption(option: ChartConfig, controller?: webview.WebviewController): Promise<void> {
  if (!option || !option.series || option.series.length === 0) {
    throw new Error('图表配置无效：缺少series数据');
  }

  currentOption = option;

  // 如果没有传入控制器实例，只保存配置
  if (!controller) {
    console.log('图表配置已保存，等待WebView初始化');
    return;
  }

  try {
    // 桥接到WebView并调用chart.setOption
    await controller.runJavaScript(`
      if (window.chartAPI && window.chartAPI.setOption) {
        window.chartAPI.setOption(${JSON.stringify(option)});
      }
    `);
    console.log('图表配置已设置');
  } catch (error) {
    console.error('设置图表配置失败:', error);
    throw new Error('图表渲染失败');
  }
}

/**
 * 获取当前图表配置
 */
export function getCurrentOption(): ChartConfig | null {
  return currentOption;
}

/**
 * 导出图表为PNG（base64编码）
 * @param controller WebView控制器实例
 * @returns Promise<string> base64编码的PNG图片数据URL
 */
export async function exportPng(controller: webview.WebviewController): Promise<string> {
  if (!currentOption) {
    throw new Error('没有可导出的图表，请先生成图表');
  }

  try {
    // 桥接到WebView的chart.exportImage
    const result = await controller.runJavaScript(`
      if (window.chartAPI && window.chartAPI.exportImage) {
        return window.chartAPI.exportImage({
          type: 'png',
          backgroundColor: '#ffffff',
          pixelRatio: 2
        });
      }
      return null;
    `);

    if (result) {
      return result as string;
    } else {
      throw new Error('图表导出失败');
    }
  } catch (error) {
    console.error('导出PNG失败:', error);
    throw new Error('导出图片失败');
  }
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
 * @param config 图表配置
 * @param controller WebView控制器实例（可选）
 */
export function loadChartFromRecord(config: ChartConfig, controller?: webview.WebviewController): void {
  setChartOption(config, controller);
}

@Entry
@Component
struct ChartPage {
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  // 组件内部WebView控制器
  private webviewController: webview.WebviewController = new webview.WebviewController();
  // 组件卸载标志
  private isDestroyed: boolean = false;

  aboutToAppear() {
    this.initWebView();
    // 启动性能监控
    performanceMonitor.startMonitoring();
  }

  aboutToDisappear() {
    // 清理WebView资源
    this.cleanup();
    // 停止性能监控
    performanceMonitor.stopMonitoring();
  }

  /**
   * 初始化WebView
   */
  private async initWebView() {
    try {
      this.isLoading = true;
      this.errorMessage = '';

      // WebView会自动初始化，等待页面加载完成后配置图表
      console.log('WebView 初始化中...');
      this.isLoading = false;
    } catch (error) {
      console.error('WebView 初始化失败:', error);
      this.errorMessage = '图表组件初始化失败';
      this.isLoading = false;
    }
  }

  /**
   * 清理WebView资源
   */
  private cleanup() {
    try {
      this.isDestroyed = true;
      // WebView资源会自动清理，这里标记状态
      console.log('ChartPage 资源清理完成');
    } catch (error) {
      console.error('ChartPage 资源清理失败:', error);
    }
  }

  /**
   * 在WebView加载完成后应用图表配置
   */
  private async applyChartConfig() {
    if (this.isDestroyed || !currentOption) {
      return;
    }

    try {
      await setChartOption(currentOption, this.webviewController);
    } catch (error) {
      console.error('应用图表配置失败:', error);
      this.errorMessage = '图表配置应用失败';
    }
  }

  build() {
    Scroll() {
      Column() {
        // 顶部栏
        Row() {
          Button('返回')
            .type(ButtonType.Normal)
            .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
            .onClick(() => {
              router.pop();
            })
          Text('图表预览')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
            .margin({ left: 12 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(RESOURCES.COLORS.SURFACE)

        // 内容区域
        Column() {
          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .margin({ bottom: 8 })
              Text('正在加载图表组件...')
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
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .padding(16)
          } else {
            Column() {
              // WebView 集成区域
              Web({ src: 'resource:///rawfile/chart.html', controller: this.webviewController })
                .width('100%')
                .height('60%')
                .domStorageAccess(true)
                .javaScriptAccess(true)
                .mixedMode(MixedMode.All)
                .onPageEnd(() => {
                  console.log('WebView 页面加载完成');
                  // 页面加载完成后应用图表配置
                  this.applyChartConfig();
                })
                
              // 控制按钮区域
              Column() {
                // 第一行按钮
                Row() {
                  Button('导出 JSON')
                    .type(ButtonType.Normal)
                    .backgroundColor(RESOURCES.COLORS.PRIMARY_LIGHT)
                    .fontColor(RESOURCES.COLORS.PRIMARY)
                    .onClick(() => {
                      try {
                        const json = exportJson();
                        this.saveJsonFile(json);
                      } catch (e) {
                        const appError = ErrorHandler.handle(e, 'exportJson');
                        if (!this.isDestroyed) {
                          this.errorMessage = appError.userMessage || '导出JSON失败';
                        }
                      }
                    })

                  Blank()

                  Button('导出 PNG')
                    .type(ButtonType.Normal)
                    .backgroundColor(RESOURCES.COLORS.PRIMARY_LIGHT)
                    .fontColor(RESOURCES.COLORS.PRIMARY)
                    .onClick(async () => {
                      try {
                        const dataUrl = await exportPng(this.webviewController);
                        await this.saveImageFile(dataUrl);
                      } catch (e) {
                        const appError = ErrorHandler.handle(e, 'exportPng');
                        if (!this.isDestroyed) {
                          this.errorMessage = appError.userMessage || '导出图片失败';
                        }
                      }
                    })
                }
                .width('100%')
                .margin({ bottom: 8 })

                // 第二行按钮 - PDF导出
                Row() {
                  Button('导出 PDF')
                    .type(ButtonType.Normal)
                    .backgroundColor('#E8F5E9')
                    .fontColor(RESOURCES.COLORS.SUCCESS)
                    .onClick(() => {
                      this.exportPdfFile();
                    })

                  Blank()
                }
                .width('100%')
              }
              .width('100%')
              .margin({ top: 16 })
            }
            .width('100%')
            .height('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
  }

  /**
   * 保存JSON文件
   */
  private async saveJsonFile(jsonData: ChartConfig) {
    try {
      await FileManager.exportJson(jsonData, {
        filename: this.generateChartFilename(),
        format: 'json'
      });
    } catch (error) {
      console.error('保存JSON失败:', error);
      throw error;
    }
  }

  /**
   * 保存图片文件
   */
  private async saveImageFile(dataUrl: string) {
    try {
      await FileManager.exportPng(dataUrl, {
        filename: this.generateChartFilename(),
        format: 'png',
        backgroundColor: '#ffffff'
      });
    } catch (error) {
      console.error('保存图片失败:', error);
      throw error;
    }
  }

  /**
   * 导出PDF文件
   */
  private async exportPdfFile() {
    if (!currentOption) {
      this.errorMessage = '没有可导出的图表，请先生成图表';
      return;
    }

    try {
      await FileManager.exportPdf(currentOption, {
        filename: this.generateChartFilename(),
        format: 'pdf'
      });
    } catch (error) {
      const appError = ErrorHandler.handle(error, 'exportPdfFile');
      this.errorMessage = appError.userMessage || '导出PDF失败';
      console.error('导出PDF失败:', appError);
    }
  }

  /**
   * 生成图表文件名
   */
  private generateChartFilename(): string {
    if (currentOption?.title?.text) {
      return currentOption.title.text;
    }
    return 'AI图表';
  }
}
