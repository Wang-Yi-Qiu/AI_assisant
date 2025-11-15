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
import { deviceAdapter, DeviceType } from '../utils/deviceAdapter';

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
  // 设备适配
  private layoutConfig = deviceAdapter.getLayoutConfig();
  private deviceType = deviceAdapter.getDeviceType();
  private needsFocus = deviceAdapter.needsFocusNavigation();
  private supportsImageExport = deviceAdapter.supportsImageExport();
  private supportsPdfExport = deviceAdapter.supportsPdfExport();

  aboutToAppear() {
    // 启动性能监控
    performanceMonitor.startMonitoring();
    // 初始化WebView（会在页面加载完成后自动应用图表配置）
    this.initWebView();
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

      // 检查是否有待渲染的图表配置
      if (!currentOption) {
        console.warn('没有待渲染的图表配置，从Index页面跳转时应该已设置');
        // 尝试从路由参数获取配置（如果将来需要支持）
        this.errorMessage = '没有可显示的图表，请先生成图表';
        this.isLoading = false;
        return;
      }

      // WebView会自动初始化，等待页面加载完成后配置图表
      console.log('WebView 初始化中，等待页面加载...');
      // 注意：isLoading会在applyChartConfig成功后设置为false
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
   * 添加重试机制，确保chartAPI已初始化
   */
  private async applyChartConfig() {
    if (this.isDestroyed || !currentOption) {
      console.warn('无法应用图表配置: 组件已销毁或配置为空');
      return;
    }

    // 重试机制：最多重试5次，每次间隔200ms
    const maxRetries = 5;
    let retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // 检查chartAPI是否已初始化
        // runJavaScript返回的是字符串，JavaScript的布尔值会被转换为字符串 'true' 或 'false'
        const result = await this.webviewController.runJavaScript(`
          (function() {
            return window.chartAPI && window.chartAPI.setOption && typeof window.chartAPI.setOption === 'function';
          })();
        `) as string;
        
        // 将字符串结果转换为布尔值
        const isReady = result === 'true';

        if (isReady) {
          // chartAPI已准备好，设置图表配置
          await setChartOption(currentOption, this.webviewController);
          console.log('图表配置应用成功');
          this.isLoading = false;
          return;
        } else {
          // chartAPI还未准备好，等待后重试
          retryCount++;
          if (retryCount < maxRetries) {
            console.log(`等待chartAPI初始化... (${retryCount}/${maxRetries})`);
            await new Promise<void>((resolve) => {
              setTimeout(() => {
                resolve();
              }, 200);
            });
          }
        }
      } catch (error) {
        console.error(`应用图表配置失败 (尝试 ${retryCount + 1}/${maxRetries}):`, error);
        retryCount++;
        if (retryCount < maxRetries) {
          await new Promise<void>((resolve) => {
            setTimeout(() => {
              resolve();
            }, 200);
          });
        } else {
          this.errorMessage = '图表配置应用失败，请重试';
          this.isLoading = false;
        }
      }
    }

    // 如果所有重试都失败，显示错误信息
    if (retryCount >= maxRetries) {
      console.error('图表配置应用失败：chartAPI未能在预期时间内初始化');
      this.errorMessage = '图表初始化超时，请返回重试';
      this.isLoading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        // 顶部栏
        Row() {
          Button('返回')
            .type(ButtonType.Normal)
            .fontSize(this.layoutConfig.fontSize.medium)
            .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
            .onClick(() => {
              // 使用 getUIContext().getRouter().back() 替代已弃用的 router.pop()
              this.getUIContext().getRouter().back();
            })
            .focusable(this.needsFocus)
            .focusOnTouch(this.needsFocus)
          Text('图表预览')
            .fontSize(this.layoutConfig.fontSize.title)
            .fontWeight(FontWeight.Bold)
            .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
            .margin({ left: this.layoutConfig.spacing.medium })
        }
        .width('100%')
        .height(this.deviceType === DeviceType.WEARABLE ? 48 : 56)
        .padding({ 
          left: this.layoutConfig.padding.medium, 
          right: this.layoutConfig.padding.medium 
        })
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
                .height(this.deviceType === DeviceType.WEARABLE ? '50%' : '60%')
                .domStorageAccess(true)
                .javaScriptAccess(true)
                .mixedMode(MixedMode.All)
                .onPageEnd(() => {
                  console.log('WebView 页面加载完成');
                  // 页面加载完成后，延迟一点时间确保JavaScript环境完全初始化
                  setTimeout(() => {
                    this.applyChartConfig();
                  }, 300);
                })
                .onConsole((event) => {
                  // 输出WebView中的console日志，便于调试
                  console.log(`[WebView Console] ${event.message.getMessage()}`);
                  return true; // 返回true表示已处理
                })
                
              // 控制按钮区域
              Column() {
                // 第一行按钮
                Row() {
                  Button('导出 JSON')
                    .type(ButtonType.Normal)
                    .fontSize(this.layoutConfig.fontSize.medium)
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
                    .focusable(this.needsFocus)
                    .focusOnTouch(this.needsFocus)

                  Blank()

                  // PNG导出按钮（根据设备能力显示/隐藏）
                  if (this.supportsImageExport) {
                    Button('导出 PNG')
                      .type(ButtonType.Normal)
                      .fontSize(this.layoutConfig.fontSize.medium)
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
                      .focusable(this.needsFocus)
                      .focusOnTouch(this.needsFocus)
                  } else {
                    // 不支持图片导出时显示提示
                    Text(deviceAdapter.getFallbackMessage('imageExport'))
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor('#666666')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .width('100%')
                .margin({ bottom: this.layoutConfig.spacing.small })

                // 第二行按钮 - PDF导出（实际导出HTML，可在浏览器中打印为PDF）
                Row() {
                  if (this.supportsPdfExport) {
                    Button('导出 PDF')
                      .type(ButtonType.Normal)
                      .fontSize(this.layoutConfig.fontSize.medium)
                      .backgroundColor('#E8F5E9')
                      .fontColor(RESOURCES.COLORS.SUCCESS)
                      .onClick(() => {
                        this.exportPdfFile();
                      })
                      .focusable(this.needsFocus)
                      .focusOnTouch(this.needsFocus)
                  } else {
                    // 不支持PDF导出时显示提示
                    Text(deviceAdapter.getFallbackMessage('pdfExport'))
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor('#666666')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }

                  Blank()
                }
                .width('100%')
              }
              .width('100%')
              .margin({ top: this.layoutConfig.spacing.medium })
            }
            .width('100%')
            .height('100%')
            .padding(this.layoutConfig.padding.medium)
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
      const context = this.getUIContext().getHostContext();
      await FileManager.exportJson(jsonData, {
        filename: this.generateChartFilename(),
        format: 'json'
      }, context);
    } catch (error) {
      console.error('保存JSON失败:', error);
      // ArkTS限制：throw 语句只能抛出 Error 类型
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 保存图片文件
   */
  private async saveImageFile(dataUrl: string) {
    try {
      const context = this.getUIContext().getHostContext();
      await FileManager.exportPng(dataUrl, {
        filename: this.generateChartFilename(),
        format: 'png',
        backgroundColor: '#ffffff'
      }, context);
    } catch (error) {
      console.error('保存图片失败:', error);
      // ArkTS限制：throw 语句只能抛出 Error 类型
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 导出PDF文件（实际导出HTML，可在浏览器中打印为PDF）
   */
  private async exportPdfFile() {
    if (!currentOption) {
      this.errorMessage = '没有可导出的图表，请先生成图表';
      return;
    }

    try {
      const context = this.getUIContext().getHostContext();
      await FileManager.exportPdf(currentOption, {
        filename: this.generateChartFilename(),
        format: 'pdf'
      }, context);
      // 提示用户可以在浏览器中打开并打印为PDF
      this.errorMessage = ''; // 清空错误信息
      // 注意：这里可以添加成功提示，但由于是异步操作，可能需要使用Toast
    } catch (error) {
      const appError = ErrorHandler.handle(error, 'exportPdfFile');
      this.errorMessage = appError.userMessage || '导出失败，请稍后重试';
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
