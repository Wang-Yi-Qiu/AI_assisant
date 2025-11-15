/**
 * 图表页：渲染ECharts并支持导出
 * @module ChartPage
 */

import { ChartConfig, generateChart, getLastUserData, getLastGeneratedConfig, UserData, CancellationToken as AIServiceCancellationToken, generateChartInsight, ChartInsightData, InsightResponse } from '../utils/aiService';
import router from '@ohos.router';
import webview from '@ohos.web.webview';
import { BusinessError } from '@kit.BasicServicesKit';
import { FileManager } from '../utils/fileManager';
import { ErrorHandler, AppError } from '../utils/errorHandler';
import { performanceMonitor } from '../utils/performanceMonitor';
import { resourceManager, RESOURCES } from '../utils/resourceManager';
import { deviceAdapter, DeviceType } from '../utils/deviceAdapter';
import { asyncManager, AsyncOptions, CancellationToken, AsyncTask } from '../utils/asyncManager';
import promptAction from '@ohos.promptAction';
import { ChartType, getSupportedChartTypes, getChartTypeName, switchChartType, isCompatibleWithChartType, autoSelectChartType } from '../utils/chartTypeSwitcher';

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
  @State isRegenerating: boolean = false; // 重新生成状态
  @State regenerateError: string = ''; // 重新生成错误提示
  @State showTypeSelector: boolean = false; // 类型选择器显示状态
  @State typeSwitchError: string = ''; // 类型切换错误提示
  @State isSwitchingType: boolean = false; // 类型切换中状态
  @State showInsight: boolean = false; // AI洞察区域显示状态
  @State insightContent: InsightResponse | null = null; // AI洞察内容
  @State isLoadingInsight: boolean = false; // AI洞察加载状态
  @State insightError: string = ''; // AI洞察错误提示
  // 组件内部WebView控制器
  private webviewController: webview.WebviewController = new webview.WebviewController();
  // 组件卸载标志
  private isDestroyed: boolean = false;
  // 异步任务管理
  private currentRegenerateTask: AsyncTask<ChartConfig> | null = null;
  private currentTypeSwitchTask: AsyncTask<ChartConfig> | null = null;
  private currentInsightTask: AsyncTask<InsightResponse> | null = null;
  private insightCancellationToken: AIServiceCancellationToken | null = null;
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
    // 取消重新生成任务
    this.cancelRegenerateTask();
    // 取消类型切换任务
    this.cancelTypeSwitchTask();
    // 取消AI洞察任务
    this.cancelInsightTask();
    // 清理WebView资源
    this.cleanup();
    // 停止性能监控
    performanceMonitor.stopMonitoring();
  }

  /**
   * 取消重新生成任务
   */
  private cancelRegenerateTask(): void {
    if (this.currentRegenerateTask) {
      this.currentRegenerateTask.cancel();
      this.currentRegenerateTask = null;
    }
  }

  /**
   * 取消类型切换任务
   */
  private cancelTypeSwitchTask(): void {
    if (this.currentTypeSwitchTask) {
      this.currentTypeSwitchTask.cancel();
      this.currentTypeSwitchTask = null;
    }
  }

  /**
   * 取消AI洞察任务
   */
  private cancelInsightTask(): void {
    if (this.insightCancellationToken) {
      this.insightCancellationToken.cancel();
      this.insightCancellationToken = null;
    }
    if (this.currentInsightTask) {
      this.currentInsightTask.cancel();
      this.currentInsightTask = null;
    }
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
                // 重新生成和更改类型按钮行
                Row() {
                  Button('重新生成')
                    .type(ButtonType.Capsule)
                    .backgroundColor('#FF9800')
                    .fontColor(Color.White)
                    .fontSize(this.layoutConfig.fontSize.medium)
                    .enabled(!this.isRegenerating && !this.isLoading && !this.isSwitchingType)
                    .onClick(() => {
                      this.onRegenerateChart();
                    })
                    .focusable(this.needsFocus)
                    .focusOnTouch(this.needsFocus)
                    .tabIndex(1)

                  Blank()

                  Button('更改类型')
                    .type(ButtonType.Capsule)
                    .backgroundColor('#2196F3')
                    .fontColor(Color.White)
                    .fontSize(this.layoutConfig.fontSize.medium)
                    .enabled(!this.isRegenerating && !this.isLoading && !this.isSwitchingType)
                    .onClick(() => {
                      this.showTypeSelector = !this.showTypeSelector;
                    })
                    .focusable(this.needsFocus)
                    .focusOnTouch(this.needsFocus)
                    .tabIndex(2)
                }
                .width('100%')
                .margin({ bottom: this.layoutConfig.spacing.medium })

                // 类型选择器
                if (this.showTypeSelector) {
                  Column() {
                    Text('选择图表类型')
                      .fontSize(this.layoutConfig.fontSize.medium)
                      .fontWeight(FontWeight.Bold)
                      .margin({ bottom: this.layoutConfig.spacing.small })
                    
                    ForEach(getSupportedChartTypes(), (type: ChartType, index: number) => {
                      Button(getChartTypeName(type))
                        .type(ButtonType.Normal)
                        .backgroundColor(this.getCurrentChartType() === type ? '#4CAF50' : RESOURCES.COLORS.PRIMARY_LIGHT)
                        .fontColor(this.getCurrentChartType() === type ? Color.White : RESOURCES.COLORS.PRIMARY)
                        .fontSize(this.layoutConfig.fontSize.medium)
                        .width('100%')
                        .margin({ bottom: this.layoutConfig.spacing.small })
                        .enabled(!this.isSwitchingType)
                        .onClick(() => {
                          this.onSwitchChartType(type);
                        })
                        .focusable(this.needsFocus)
                        .focusOnTouch(this.needsFocus)
                        .tabIndex(3 + index)
                    }, (type: ChartType) => type)
                  }
                  .width('100%')
                  .padding(this.layoutConfig.padding.medium)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .margin({ bottom: this.layoutConfig.spacing.medium })
                }

                // 重新生成加载状态
                if (this.isRegenerating) {
                  Row() {
                    LoadingProgress()
                      .width(24)
                      .height(24)
                      .margin({ right: 8 })
                    Text('正在重新生成图表...')
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor('#666666')
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)
                  .margin({ bottom: this.layoutConfig.spacing.small })
                }

                // 重新生成错误提示
                if (this.regenerateError) {
                  Row() {
                    Text(this.regenerateError)
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor('#F44336')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Blank()
                    Button('重试')
                      .type(ButtonType.Normal)
                      .fontSize(this.layoutConfig.fontSize.small)
                      .backgroundColor('#FFEBEE')
                      .fontColor('#F44336')
                      .onClick(() => {
                        this.onRegenerateChart();
                      })
                      .focusable(this.needsFocus)
                      .focusOnTouch(this.needsFocus)
                  }
                  .width('100%')
                  .margin({ bottom: this.layoutConfig.spacing.small })
                }

                // 类型切换加载状态
                if (this.isSwitchingType) {
                  Row() {
                    LoadingProgress()
                      .width(24)
                      .height(24)
                      .margin({ right: 8 })
                    Text('正在切换图表类型...')
                      .fontSize(this.layoutConfig.fontSize.small)
                      .fontColor('#666666')
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)
                  .margin({ bottom: this.layoutConfig.spacing.small })
                }

                // 类型切换错误提示
                if (this.typeSwitchError) {
                  Text(this.typeSwitchError)
                    .fontSize(this.layoutConfig.fontSize.small)
                    .fontColor('#F44336')
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ bottom: this.layoutConfig.spacing.small })
                }

                // AI洞察区域
                Column() {
                  Row() {
                    Text('AI 洞察')
                      .fontSize(this.layoutConfig.fontSize.medium)
                      .fontWeight(FontWeight.Bold)
                      .layoutWeight(1)
                    
                    Button(this.showInsight ? '收起' : '展开')
                      .type(ButtonType.Normal)
                      .fontSize(this.layoutConfig.fontSize.small)
                      .backgroundColor(RESOURCES.COLORS.PRIMARY_LIGHT)
                      .fontColor(RESOURCES.COLORS.PRIMARY)
                      .onClick(() => {
                        this.showInsight = !this.showInsight;
                        if (this.showInsight && !this.insightContent && !this.isLoadingInsight) {
                          // 首次展开时加载洞察
                          this.onLoadInsight();
                        }
                      })
                      .focusable(this.needsFocus)
                      .focusOnTouch(this.needsFocus)
                      .tabIndex(10)
                  }
                  .width('100%')
                  .margin({ bottom: this.layoutConfig.spacing.small })

                  if (this.showInsight) {
                    Column() {
                      if (this.isLoadingInsight) {
                        Row() {
                          LoadingProgress()
                            .width(24)
                            .height(24)
                            .margin({ right: 8 })
                          Text('正在生成AI洞察...')
                            .fontSize(this.layoutConfig.fontSize.small)
                            .fontColor('#666666')
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.Start)
                        .padding(this.layoutConfig.padding.medium)
                      } else if (this.insightError) {
                        Column() {
                          Text(this.insightError)
                            .fontSize(this.layoutConfig.fontSize.small)
                            .fontColor('#F44336')
                            .maxLines(3)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          
                          Button('重试')
                            .type(ButtonType.Normal)
                            .fontSize(this.layoutConfig.fontSize.small)
                            .backgroundColor('#FFEBEE')
                            .fontColor('#F44336')
                            .margin({ top: this.layoutConfig.spacing.small })
                            .onClick(() => {
                              this.onLoadInsight();
                            })
                            .focusable(this.needsFocus)
                            .focusOnTouch(this.needsFocus)
                        }
                        .width('100%')
                        .padding(this.layoutConfig.padding.medium)
                      } else if (this.insightContent) {
                        Column() {
                          Text(this.insightContent.insightText)
                            .fontSize(this.layoutConfig.fontSize.medium)
                            .fontColor(RESOURCES.COLORS.TEXT_PRIMARY)
                            .lineHeight(24)
                            .maxLines(this.deviceType === DeviceType.WEARABLE ? 5 : 10)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          
                          if (this.insightContent.suggestions && this.insightContent.suggestions.length > 0) {
                            Text('建议：')
                              .fontSize(this.layoutConfig.fontSize.small)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(RESOURCES.COLORS.PRIMARY)
                              .margin({ top: this.layoutConfig.spacing.medium })
                            
                            ForEach(this.insightContent.suggestions, (suggestion: any, index: number) => {
                              Text(`${index + 1}. ${suggestion.text}`)
                                .fontSize(this.layoutConfig.fontSize.small)
                                .fontColor(RESOURCES.COLORS.TEXT_SECONDARY)
                                .margin({ top: this.layoutConfig.spacing.small })
                            }, (suggestion: any, index: number) => `${index}-${suggestion.text}`)
                          }
                        }
                        .width('100%')
                        .padding(this.layoutConfig.padding.medium)
                        .backgroundColor('#F5F5F5')
                        .borderRadius(8)
                      }
                    }
                    .width('100%')
                    .margin({ bottom: this.layoutConfig.spacing.medium })
                  }
                }
                .width('100%')
                .padding(this.layoutConfig.padding.medium)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
                .margin({ bottom: this.layoutConfig.spacing.medium })

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
                    .tabIndex(2)

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
                      .tabIndex(3)
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
                      .tabIndex(4)
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

  /**
   * 重新生成图表
   */
  onRegenerateChart() {
    // 取消之前的重新生成任务
    this.cancelRegenerateTask();

    this.isRegenerating = true;
    this.regenerateError = '';
    this.errorMessage = '';

    // 获取原始数据
    let userData: UserData | null = getLastUserData();
    
    // 如果原始数据已从内存中清除，尝试从当前图表配置中提取数据
    if (!userData) {
      const currentConfig = getLastGeneratedConfig() || currentOption;
      if (currentConfig && currentConfig.series && currentConfig.series.length > 0) {
        // 尝试从图表配置中提取数据
        const firstSeries = currentConfig.series[0];
        if (firstSeries.data) {
          userData = firstSeries.data as UserData;
        }
      }
    }

    // 如果仍然无法获取数据，显示错误提示
    if (!userData) {
      this.regenerateError = '无法重新生成，请重新输入数据';
      this.isRegenerating = false;
      promptAction.showToast({
        message: '无法重新生成，请重新输入数据',
        duration: 2000
      });
      return;
    }

    // 设置超时（45秒，与生成图表一致）
    const options: AsyncOptions = {
      timeout: 45000,
      retryCount: 0, // 重新生成不自动重试，由用户手动重试
      retryDelay: 1000,
      onProgress: (progress) => {
        console.log(`重新生成进度: ${Math.round(progress)}%`);
      }
    };

    this.currentRegenerateTask = asyncManager.createTask(async (signal) => {
      // 转换 CancellationToken 类型
      class AIServiceTokenImpl implements AIServiceCancellationToken {
        cancelled: boolean;
        cancel(): void {
          signal.cancel();
        }
        constructor(signal: CancellationToken) {
          this.cancelled = signal.cancelled;
        }
      }
      const token = new AIServiceTokenImpl(signal);
      return await generateChart(userData!, token);
    }, options);

    this.currentRegenerateTask.promise
      .then((chartConfig: ChartConfig) => {
        if (this.isDestroyed) return;

        // 验证返回的图表配置
        if (!chartConfig || !chartConfig.series || chartConfig.series.length === 0) {
          throw new AppError(
            ErrorCode.CHART_CONFIG_INVALID,
            'Invalid chart configuration returned',
            '重新生成的图表配置无效，请重试'
          );
        }

        // 更新图表配置
        currentOption = chartConfig;
        
        // 平滑切换到新图表
        this.applyChartConfig().then(() => {
          if (!this.isDestroyed) {
            this.isRegenerating = false;
            this.regenerateError = '';
            console.log('图表重新生成成功');
          }
        }).catch((error) => {
          console.error('应用新图表配置失败:', error);
          if (!this.isDestroyed) {
            this.isRegenerating = false;
            this.regenerateError = '图表重新生成成功，但显示失败，请刷新页面';
          }
        });
      })
      .catch((error: Error | object | string) => {
        if (this.isDestroyed) return;

        const appError = ErrorHandler.handle(error, 'onRegenerateChart');
        
        // 保留原图表显示
        // 根据错误类型显示不同的提示
        let errorMessage = appError.userMessage || '重新生成失败，请稍后重试';
        
        if (appError.code === ErrorCode.NETWORK_ERROR) {
          errorMessage = '网络连接失败，请检查网络后重试';
        } else if (appError.code === ErrorCode.API_TIMEOUT) {
          errorMessage = '服务响应超时，请稍后重试';
        }

        this.regenerateError = errorMessage;
        this.isRegenerating = false;
        
        console.error('重新生成图表失败:', appError);
      })
      .finally(() => {
        if (!this.isDestroyed) {
          this.currentRegenerateTask = null;
        }
      });
  }

  /**
   * 获取当前图表类型
   */
  private getCurrentChartType(): ChartType | null {
    if (!currentOption || !currentOption.series || currentOption.series.length === 0) {
      return null;
    }
    const firstSeries = currentOption.series[0];
    if (!firstSeries || !firstSeries.type) {
      return null;
    }
    const type = firstSeries.type as ChartType;
    if (getSupportedChartTypes().includes(type)) {
      return type;
    }
    return null;
  }

  /**
   * 切换图表类型
   */
  onSwitchChartType(targetType: ChartType) {
    // 取消之前的类型切换任务
    this.cancelTypeSwitchTask();
    // 取消AI洞察任务（在类型切换时取消洞察请求）
    this.cancelInsightTask();

    if (!currentOption) {
      this.typeSwitchError = '当前图表无数据，无法切换类型';
      promptAction.showToast({
        message: '当前图表无数据，无法切换类型',
        duration: 2000
      });
      return;
    }

    // 检查是否已经是目标类型
    const currentType = this.getCurrentChartType();
    if (currentType === targetType) {
      this.showTypeSelector = false;
      return;
    }

    this.isSwitchingType = true;
    this.typeSwitchError = '';
    this.showTypeSelector = false;

    // 使用异步任务管理，确保响应时间≤500ms
    const options: AsyncOptions = {
      timeout: 500, // 500ms超时
      retryCount: 0,
      retryDelay: 0,
      onProgress: () => {}
    };

    this.currentTypeSwitchTask = asyncManager.createTask(async () => {
      try {
        // 检查数据兼容性
        const isCompatible = isCompatibleWithChartType(currentOption!, targetType);
        
        if (!isCompatible) {
          // 尝试自动选择最合适的类型
          const autoType = autoSelectChartType(currentOption!);
          if (autoType) {
            // 使用自动选择的类型
            const newConfig = switchChartType(currentOption!, autoType);
            return newConfig;
          } else {
            // 所有类型都不兼容
            throw new AppError(
              ErrorCode.CHART_CONFIG_INVALID,
              'Data is incompatible with all chart types',
              '当前数据无法切换图表类型，请使用重新生成功能'
            );
          }
        }

        // 数据兼容，直接切换
        const newConfig = switchChartType(currentOption!, targetType);
        return newConfig;
      } catch (error) {
        const appError = ErrorHandler.handle(error, 'onSwitchChartType');
        throw appError;
      }
    }, options);

    this.currentTypeSwitchTask.promise
      .then((newConfig: ChartConfig) => {
        if (this.isDestroyed) return;

        // 更新图表配置
        currentOption = newConfig;
        
        // 平滑切换到新图表（≤500ms）
        this.applyChartConfig().then(() => {
          if (!this.isDestroyed) {
            this.isSwitchingType = false;
            this.typeSwitchError = '';
            
            // 检查是否自动切换了类型
            const finalType = this.getCurrentChartType();
            if (finalType !== targetType) {
              // 自动切换了类型，显示提示
              const message = finalType 
                ? `当前数据不适合${getChartTypeName(targetType)}，已自动选择${getChartTypeName(finalType)}`
                : '当前数据点数量不足，已自动选择最合适的类型';
              promptAction.showToast({
                message: message,
                duration: 2000
              });
            }
            
            console.log('图表类型切换成功');
          }
        }).catch((error) => {
          console.error('应用新图表配置失败:', error);
          if (!this.isDestroyed) {
            this.isSwitchingType = false;
            this.typeSwitchError = '图表类型切换成功，但显示失败，请刷新页面';
          }
        });
      })
      .catch((error: Error | object | string) => {
        if (this.isDestroyed) return;

        const appError = ErrorHandler.handle(error, 'onSwitchChartType');
        
        // 保留原图表显示
        let errorMessage = appError.userMessage || '类型切换失败，请稍后重试';
        
        // 根据错误类型显示不同的提示
        if (appError.code === ErrorCode.CHART_CONFIG_INVALID) {
          if (errorMessage.includes('无法切换图表类型')) {
            errorMessage = '当前数据无法切换图表类型，请使用重新生成功能';
          } else if (errorMessage.includes('无数据')) {
            errorMessage = '当前图表无数据，无法切换类型';
          } else {
            errorMessage = '当前数据无效，无法切换图表类型';
          }
        }

        this.typeSwitchError = errorMessage;
        this.isSwitchingType = false;
        
        promptAction.showToast({
          message: errorMessage,
          duration: 2000
        });
        
        console.error('切换图表类型失败:', appError);
      })
      .finally(() => {
        if (!this.isDestroyed) {
          this.currentTypeSwitchTask = null;
        }
      });
  }

  /**
   * 加载AI洞察
   */
  onLoadInsight() {
    // 取消之前的洞察任务
    this.cancelInsightTask();

    if (!currentOption) {
      this.insightError = '当前图表无数据，无法生成洞察';
      promptAction.showToast({
        message: '当前图表无数据，无法生成洞察',
        duration: 2000
      });
      return;
    }

    // 检查图表数据是否有效
    if (!currentOption.series || currentOption.series.length === 0) {
      this.insightError = '当前图表无数据，无法生成洞察';
      promptAction.showToast({
        message: '当前图表无数据，无法生成洞察',
        duration: 2000
      });
      return;
    }

    this.isLoadingInsight = true;
    this.insightError = '';
    this.insightContent = null;

    // 创建取消令牌
    class InsightTokenImpl implements AIServiceCancellationToken {
      cancelled: boolean = false;
      cancel(): void {
        this.cancelled = true;
      }
      onCancel?(callback: () => void): void {
        // 简化实现，不处理回调
      }
    }
    this.insightCancellationToken = new InsightTokenImpl();

    // 构建洞察数据
    const insightData: ChartInsightData = {
      chartConfig: currentOption,
      rawData: getLastUserData() ? JSON.stringify(getLastUserData()) : undefined
    };

    // 使用异步任务管理，设置5秒超时
    const options: AsyncOptions = {
      timeout: 5000, // 5秒超时
      retryCount: 0,
      retryDelay: 0,
      onProgress: () => {}
    };

    this.currentInsightTask = asyncManager.createTask(async () => {
      return await generateChartInsight(insightData, this.insightCancellationToken!);
    }, options);

    this.currentInsightTask.promise
      .then((insight: InsightResponse) => {
        if (this.isDestroyed) return;

        // 验证洞察内容
        if (!insight || !insight.insightText || insight.insightText.trim().length === 0) {
          throw new AppError(
            ErrorCode.INSIGHT_INVALID_RESPONSE,
            'Invalid insight response',
            '洞察数据格式错误，请稍后重试'
          );
        }

        this.insightContent = insight;
        this.isLoadingInsight = false;
        this.insightError = '';
        
        console.log('AI洞察生成成功');
      })
      .catch((error: Error | object | string) => {
        if (this.isDestroyed) return;

        const appError = ErrorHandler.handle(error, 'onLoadInsight');
        
        // 根据错误类型显示不同的提示
        let errorMessage = appError.userMessage || 'AI洞察生成失败，请稍后重试';
        
        if (appError.code === ErrorCode.INSIGHT_TIMEOUT) {
          errorMessage = 'AI洞察生成超时，请稍后重试';
        } else if (appError.code === ErrorCode.INSIGHT_SERVICE_UNAVAILABLE) {
          errorMessage = 'AI洞察暂时不可用，请稍后重试';
        } else if (appError.code === ErrorCode.INSIGHT_INVALID_RESPONSE) {
          errorMessage = '洞察数据格式错误，请稍后重试';
        }

        this.insightError = errorMessage;
        this.isLoadingInsight = false;
        
        // 显示Toast提示（2秒）
        promptAction.showToast({
          message: errorMessage,
          duration: 2000
        });
        
        console.error('AI洞察生成失败:', appError);
      })
      .finally(() => {
        if (!this.isDestroyed) {
          this.currentInsightTask = null;
          this.insightCancellationToken = null;
        }
      });
  }
}
