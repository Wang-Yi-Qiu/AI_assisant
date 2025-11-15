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
    }
  }

  aboutToDisappear() {
    // 清理控制器引用
    if (this.controller && webviewController === this.controller) {
      webviewController = null;
    }
  }

  /**
   * 更新图表配置
   */
  updateChart() {
    if (!this.chartConfig) {
      console.warn('[ChartPage] updateChart: 没有图表配置');
      return;
    }
    
    const controller = this.controller;
    if (!controller) {
      console.warn('[ChartPage] updateChart: WebView 控制器未初始化');
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
            // 等待 chartAPI 初始化
            return new Promise((resolve) => {
              let attempts = 0;
              const checkInterval = setInterval(() => {
                attempts++;
                if (window.chartAPI && window.chartAPI.setOption) {
                  clearInterval(checkInterval);
                  window.chartAPI.setOption(${configJson});
                  console.log('图表配置已设置（延迟）');
                  resolve(true);
                } else if (attempts > 20) {
                  clearInterval(checkInterval);
                  console.error('chartAPI 初始化超时');
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
        })
        .catch((err: Error) => {
          console.error('[ChartPage] 更新图表配置失败:', err);
        });
    } catch (error) {
      console.error('[ChartPage] 序列化图表配置失败:', error);
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(Color.White)
          .onClick(() => router.back())

        Text('图表预览').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).margin({ left: 20 })
        Blank()
      }
      .width('90%').padding({ top: 20, bottom: 20 })

      // 图表渲染区域
      Stack() {
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40).margin({bottom: 15})
            Text('正在加载图表...').fontSize(16).fontColor(Color.Gray)
          }
        }
        // WebView 组件用于渲染图表
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
            
            // 延迟一点时间确保 chartAPI 已初始化
            setTimeout(() => {
              if (this.chartConfig) {
                console.info('[ChartPage] 开始更新图表，配置:', JSON.stringify(this.chartConfig).substring(0, 100));
                this.updateChart();
              } else {
                console.warn('[ChartPage] 没有图表配置，显示空图表');
              }
              this.isLoading = false;
            }, 1000);
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
            } else {
              console.error('WebView 加载错误: 未知错误');
            }
            this.isLoading = false;
          })
      }
      .width('90%')
      .height('45%')
      .backgroundColor('#252525')
      .borderRadius(15)
      .margin({ bottom: 20 })

      // AI分析报告
      Column() {
        Row(){
          Text('✨')
            .fontSize(24)
            .margin({right: 10})
          Text('AI自动分析报告').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
        Text('这是一个简短的文本块，用于显示AI自动生成的分析报告。')
          .fontSize(14)
          .fontColor(Color.Gray)
          .margin({ top: 10 })
          .lineHeight(20)
      }
      .padding(20)
      .width('90%')
      .backgroundColor('#252525')
      .borderRadius(15)
      .margin({ bottom: 20 })
      .alignItems(HorizontalAlign.Start)

      // 控制按钮
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        Button('导出 PNG', { type: ButtonType.Normal })
          .width('48%').height(50).backgroundColor('#252525').borderRadius(10).margin({bottom: 10})
        Button('导出 PDF', { type: ButtonType.Normal })
          .width('48%').height(50).backgroundColor('#252525').borderRadius(10)
        Button('重新生成', { type: ButtonType.Normal })
          .width('48%').height(50).backgroundColor('#252525').borderRadius(10)
        Button('更换图表', { type: ButtonType.Normal })
          .width('48%').height(50).backgroundColor('#007DFF').borderRadius(10)
      }.width('90%')

    }
    .width('100%').height('100%').backgroundColor('#1C1C1C').alignItems(HorizontalAlign.Center)
  }
}