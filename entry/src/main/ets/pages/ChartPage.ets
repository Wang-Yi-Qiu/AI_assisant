import router from '@ohos.router';
import { ChartConfig } from '../utils/aiService';
import webview from '@ohos.web.webview';

// 全局变量存储图表配置
let globalChartConfig: ChartConfig | null = null;
// WebView 控制器引用
let webviewController: webview.WebviewController | null = null;

/**
 * 设置图表配置（供其他页面调用）
 */
export function setChartOption(config: ChartConfig): void {
  console.info('[ChartPage] setChartOption 被调用，配置:', JSON.stringify(config).substring(0, 200));
  globalChartConfig = config;
  
  // 如果 WebView 已经加载，立即设置图表配置
  if (webviewController) {
    console.info('[ChartPage] WebView 已加载，立即设置图表配置');
    try {
      const configJson = JSON.stringify(config);
      const jsCode = `(function() {
        try {
          if (window.chartAPI && window.chartAPI.setOption) {
            window.chartAPI.setOption(${configJson});
            console.log('图表配置已通过 setChartOption 设置');
            return true;
          } else {
            console.warn('chartAPI 未初始化，稍后重试');
            return false;
          }
        } catch (e) {
          console.error('设置图表配置时出错:', e);
          return false;
        }
      })()`;
      
      webviewController.runJavaScript(jsCode)
        .then((result) => {
          console.info('[ChartPage] 图表配置已设置，结果:', result);
        })
        .catch((err: Error) => {
          console.error('[ChartPage] 设置图表配置失败:', err);
        });
    } catch (error) {
      console.error('[ChartPage] 序列化图表配置失败:', error);
    }
  } else {
    console.info('[ChartPage] WebView 尚未加载，配置已保存，等待页面加载');
  }
}

@Entry
@Component
export struct ChartPage {
  @State isLoading: boolean = true;
  @State chartConfig: ChartConfig | null = globalChartConfig;
  @State errorMessage: string = '';
  @State loadTimeout: number = 0; // 用于存储超时定时器ID
  controller?: webview.WebviewController;

  aboutToAppear() {
    // 每次页面显示时，重新获取最新的全局配置
    console.info('[ChartPage] aboutToAppear, 当前全局配置:', globalChartConfig ? '存在' : '不存在');
    if (globalChartConfig) {
      this.chartConfig = globalChartConfig;
      console.info('[ChartPage] 已设置图表配置:', JSON.stringify(globalChartConfig).substring(0, 100));
    } else {
      console.warn('[ChartPage] 没有图表配置，将显示空图表');
      this.chartConfig = null;
      // 如果没有配置，直接显示错误
      this.isLoading = false;
      this.errorMessage = '没有可用的图表配置，请先生成图表';
    }
  }

  aboutToDisappear() {
    // 清理控制器引用
    if (this.controller && webviewController === this.controller) {
      webviewController = null;
    }
    // 清除超时定时器
    if (this.loadTimeout) {
      clearTimeout(this.loadTimeout);
      this.loadTimeout = 0;
    }
  }

  /**
   * 更新图表配置
   */
  updateChart(): Promise<boolean> {
    return new Promise((resolve) => {
      if (!this.chartConfig) {
        console.warn('[ChartPage] updateChart: 没有图表配置');
        this.errorMessage = '没有可用的图表配置';
        this.isLoading = false;
        resolve(false);
        return;
      }
      
      const controller = this.controller;
      if (!controller) {
        console.warn('[ChartPage] updateChart: WebView 控制器未初始化');
        this.errorMessage = 'WebView 控制器未初始化';
        this.isLoading = false;
        resolve(false);
        return;
      }
      
      try {
        const configJson = JSON.stringify(this.chartConfig);
        console.info('[ChartPage] updateChart: 准备执行 JavaScript，配置长度:', configJson.length);
        
        const jsCode = `(function() {
          try {
            console.log('开始设置图表配置...');
            if (typeof window === 'undefined') {
              console.error('window 对象不存在');
              return false;
            }
            if (!window.chartAPI) {
              console.warn('chartAPI 未初始化，等待初始化...');
              // 等待 chartAPI 初始化，最多等待 5 秒
              return new Promise((resolve) => {
                let attempts = 0;
                const maxAttempts = 50; // 50 * 100ms = 5秒
                const checkInterval = setInterval(() => {
                  attempts++;
                  if (window.chartAPI && window.chartAPI.setOption) {
                    clearInterval(checkInterval);
                    try {
                      window.chartAPI.setOption(${configJson});
                      console.log('图表配置已设置（延迟）');
                      resolve(true);
                    } catch (e) {
                      console.error('设置图表配置时出错:', e);
                      resolve(false);
                    }
                  } else if (attempts >= maxAttempts) {
                    clearInterval(checkInterval);
                    console.error('chartAPI 初始化超时，已尝试 ' + attempts + ' 次');
                    resolve(false);
                  }
                }, 100);
              });
            }
            if (!window.chartAPI.setOption) {
              console.error('chartAPI.setOption 方法不存在');
              return false;
            }
            window.chartAPI.setOption(${configJson});
            console.log('图表配置已设置');
            return true;
          } catch (e) {
            console.error('设置图表配置时出错:', e);
            return false;
          }
        })()`;
        
        controller.runJavaScript(jsCode)
          .then((result) => {
            console.info('[ChartPage] 图表配置更新完成，结果:', result);
            if (result === 'true') {
              this.isLoading = false;
              this.errorMessage = '';
              resolve(true);
            } else {
              this.errorMessage = '图表配置设置失败，请检查网络连接或重试';
              this.isLoading = false;
              resolve(false);
            }
          })
          .catch((err: Error) => {
            console.error('[ChartPage] 更新图表配置失败:', err);
            this.errorMessage = `图表加载失败: ${err.message}`;
            this.isLoading = false;
            resolve(false);
          });
      } catch (error) {
        console.error('[ChartPage] 序列化图表配置失败:', error);
        this.errorMessage = '图表配置序列化失败';
        this.isLoading = false;
        resolve(false);
      }
    });
  }

  /**
   * 构建底部操作按钮
   */
  @Builder
  ActionButton(icon: string, text: string, isPrimary: boolean, onClick: () => void) {
    Button() {
      Row() {
        Text(icon)
          .fontSize(20)
          .margin({ right: 8 })
        Text(text)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .type(ButtonType.Normal)
    .stateEffect(true)
    .width('48%')
    .height(50)
    .backgroundColor(isPrimary ? '#007DFF' : '#252525')
    .borderRadius(10)
    .onClick(onClick)
  }

  build() {
    Column() {
      // 头部导航栏
      Row() {
        // 返回按钮（左上方）
        Button() {
          Text('←')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Blank()

        // 标题（居中显示）
        Text('图表预览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Blank()

        // 右侧占位，保持标题居中
        Blank()
          .width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 15, right: 15 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // 可滚动内容区域
      Scroll() {
        Column() {
          // 图表渲染区域（占据主要部分）
          Stack() {
            if (this.isLoading) {
              Column() {
                Text('✨')
                  .fontSize(48)
                  .margin({ bottom: 15 })
                LoadingProgress()
                  .width(40)
                  .height(40)
                  .margin({ bottom: 15 })
                Text('正在加载图表...')
                  .fontSize(16)
                  .fontColor(Color.Gray)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else if (this.errorMessage) {
              Column() {
                Text('⚠️')
                  .fontSize(48)
                  .margin({ bottom: 15 })
                Text(this.errorMessage)
                  .fontSize(14)
                  .fontColor('#FF6B6B')
                  .textAlign(TextAlign.Center)
                  .padding({ left: 20, right: 20 })
                  .margin({ bottom: 15 })
                Button() {
                  Text('重试')
                    .fontColor(Color.White)
                }
                .type(ButtonType.Normal)
                .backgroundColor('#007DFF')
                .onClick(() => {
                  this.isLoading = true;
                  this.errorMessage = '';
                  // 重新加载页面
                  if (this.controller) {
                    this.controller.refresh();
                  }
                })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            // WebView 组件用于渲染图表（只在非错误状态下显示）
            if (!this.errorMessage) {
              Web({ src: 'resource:///rawfile/chart.html', controller: this.controller })
                .width('100%')
                .height('100%')
                .javaScriptAccess(true)
                .domStorageAccess(true)
                .fileAccess(true)
              .onControllerAttached(() => {
                // WebView 控制器已附加，通过 this.controller 访问
                if (this.controller) {
                  webviewController = this.controller;
                }
              })
              .onPageEnd((event) => {
                console.info('[ChartPage] WebView 页面加载完成:', event?.url);
                // 页面加载完成后，再次检查全局配置（可能在页面加载过程中被设置）
                if (globalChartConfig && !this.chartConfig) {
                  this.chartConfig = globalChartConfig;
                  console.info('[ChartPage] 在页面加载后获取到配置');
                }
                
                // 清除之前的超时定时器
                if (this.loadTimeout) {
                  clearTimeout(this.loadTimeout);
                }
                
                // 设置超时机制（10秒后如果还没加载完成，显示错误）
                this.loadTimeout = setTimeout(() => {
                  if (this.isLoading) {
                    console.error('[ChartPage] 图表加载超时');
                    this.errorMessage = '图表加载超时，可能是网络连接问题或 ECharts 库加载失败';
                    this.isLoading = false;
                  }
                }, 10000) ;
                
                // 延迟一点时间确保 chartAPI 已初始化
                setTimeout(() => {
                  if (this.chartConfig) {
                    console.info('[ChartPage] 开始更新图表，配置:', JSON.stringify(this.chartConfig).substring(0, 100));
                    this.updateChart().then((success) => {
                      // 清除超时定时器
                      if (this.loadTimeout) {
                        clearTimeout(this.loadTimeout);
                        this.loadTimeout = 0;
                      }
                      if (!success) {
                        console.error('[ChartPage] 图表更新失败');
                      }
                    });
                  } else {
                    console.warn('[ChartPage] 没有图表配置，显示空图表');
                    this.errorMessage = '没有可用的图表配置，请先生成图表';
                    this.isLoading = false;
                    // 清除超时定时器
                    if (this.loadTimeout) {
                      clearTimeout(this.loadTimeout);
                      this.loadTimeout = 0;
                    }
                  }
                }, 1500); // 增加延迟时间，确保 ECharts 库有足够时间加载
              })
              .onConsole((event) => {
                const message = event.message?.getMessage();
                if (message) {
                  console.info('WebView Console:', message);
                }
                return true;
              })
              .onErrorReceive((event) => {
                const error = event?.error;
                if (error) {
                  const errorCode = error.getErrorCode();
                  const errorInfo = error.getErrorInfo();
                  console.error('WebView 加载错误:', `Code: ${errorCode}, Info: ${errorInfo}`);
                  this.errorMessage = `页面加载失败: ${errorInfo || '未知错误'}`;
                } else {
                  console.error('WebView 加载错误: 未知错误');
                  this.errorMessage = '页面加载失败: 未知错误';
                }
                this.isLoading = false;
                // 清除超时定时器
                if (this.loadTimeout) {
                  clearTimeout(this.loadTimeout);
                  this.loadTimeout = 0;
                }
              })
            }
          }
          .width('100%')
          .height(400) // 设置固定高度而非百分比，确保图表区域有足够空间
          .backgroundColor('#252525')
          .borderRadius(15)
          .margin({ bottom: 20 })

          // AI 自动分析报告区
          Column() {
            Row() {
              Text('✨')
                .fontSize(24)
                .margin({ right: 10 })
              Text('AI 自动分析报告')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width('100%')
            .margin({ bottom: 12 })
            .alignItems(VerticalAlign.Center)

            Text('这是一个简短的文本块，用于显示 AI 自动生成的分析报告。')
              .fontSize(14)
              .fontColor(Color.Gray)
              .lineHeight(20)
              .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor('#252525')
          .borderRadius(15)
          .margin({ bottom: 20 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 15, right: 15 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical) // 明确指定垂直滚动
      .scrollBar(BarState.Auto) // 自动显示滚动条
      .edgeEffect(EdgeEffect.Spring) // 添加弹性滚动效果

      // 底部操作按钮区
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        // 导出 PNG
        this.ActionButton('🖼️', '导出 PNG', false, () => {
          console.info('导出 PNG 被点击');
          // TODO: 实现导出 PNG 逻辑
        })

        // 导出 PDF
        this.ActionButton('📄', '导出 PDF', false, () => {
          console.info('导出 PDF 被点击');
          // TODO: 实现导出 PDF 逻辑
        })

        // 重新生成
        this.ActionButton('🔄', '重新生成', false, () => {
          console.info('重新生成被点击');
          // TODO: 实现重新生成逻辑
        })

        // 更换图表（主色调）
        this.ActionButton('📈', '更换图表', true, () => {
          console.info('更换图表被点击');
          // TODO: 导航到图表类型选择界面
        })
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 15, bottom: 15 })
      .backgroundColor('#1C1C1C')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
  }
}