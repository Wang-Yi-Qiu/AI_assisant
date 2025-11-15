import router from '@ohos.router';
import { ChartConfig, UserData, generateChart } from '../utils/aiService';
import webview from '@ohos.web.webview';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

// 定义接口
interface ChartExecutionResult {
  success: boolean;
  error?: string;
  stage?: string;
  result?: string;
}

interface PNGExportResult {
  success: boolean;
  dataURL?: string;
  error?: string;
}

interface DataWithArray {
  data: unknown[];
}

// 辅助函数：安全地获取数据长度
function getDataLength(userData: UserData): number {
  if (typeof userData === 'object' && userData !== null && 'data' in userData) {
    const dataArray = (userData as DataWithArray).data;
    return Array.isArray(dataArray) ? dataArray.length : 0;
  }
  return typeof userData === 'string' ? userData.length : 0;
}

// 辅助函数：检查UserData是否有有效的数据
function hasValidData(userData: UserData): boolean {
  return getDataLength(userData) > 0;
}

// 全局变量存储图表配置
let globalChartConfig: ChartConfig | null = null;
// 全局变量存储原始数据（用于重新生成）
let globalOriginalData: UserData | null = null;
// WebView 控制器引用
let webviewController: webview.WebviewController | null = null;

/**
 * 设置图表配置（供其他页面调用）
 * 增强版本：包含重试机制和详细错误处理
 */
export function setChartOption(config: ChartConfig, originalData?: UserData): void {
  console.info('[ChartPage] ========== setChartOption 开始执行 ==========');
  console.info('[ChartPage] 配置类型:', typeof config);
  console.info('[ChartPage] 配置预览:', JSON.stringify(config).substring(0, 200));

  globalChartConfig = config;

  // 如果提供了原始数据，保存起来用于重新生成
  if (originalData) {
    globalOriginalData = originalData;
    console.info('[ChartPage] 原始数据已保存，数据行数:', getDataLength(originalData));
  }

  // 如果 WebView 已经加载，立即设置图表配置
  if (webviewController) {
    console.info('[ChartPage] WebView 已加载，开始设置图表配置');
    applyChartConfigWithRetry(config, 0);
  } else {
    console.warn('[ChartPage] WebView 尚未加载，配置已保存，等待页面加载');
  }
}

/**
 * 获取原始数据（用于重新生成）
 */
export function getOriginalData(): UserData | null {
  return globalOriginalData;
}

/**
 * 设置原始数据
 */
export function setOriginalData(data: UserData): void {
  globalOriginalData = data;
  console.info('[ChartPage] 原始数据已设置，数据行数:', getDataLength(data));
}

/**
 * 带重试机制的图表配置应用
 */
function applyChartConfigWithRetry(config: ChartConfig, retryCount: number): void {
  const maxRetries = 5;
  const retryDelay = 500; // 500ms

  console.info(`[ChartPage] 尝试设置图表配置 (第 ${retryCount + 1} 次)`);

  try {
    const configJson = JSON.stringify(config);

    // 更健壮的JavaScript代码，包含详细的诊断信息
    const jsCode = `(function() {
      console.log('=== JavaScript 诊断信息 ===');
      console.log('window 对象存在:', typeof window !== 'undefined');
      console.log('chartAPI 存在:', typeof window.chartAPI !== 'undefined');
      console.log('setOption 存在:', window.chartAPI && typeof window.chartAPI.setOption !== 'undefined');
      console.log('ECharts 存在:', typeof echarts !== 'undefined');

      try {
        // 检查ECharts是否已加载
        if (typeof echarts === 'undefined') {
          console.error('ECharts 库未加载');
          return JSON.stringify({ success: false, error: 'ECharts库未加载', stage: 'library_check' });
        }

        // 检查chartAPI是否已初始化
        if (!window.chartAPI) {
          console.error('chartAPI 对象不存在');
          return JSON.stringify({ success: false, error: 'chartAPI对象不存在', stage: 'api_check' });
        }

        if (!window.chartAPI.setOption) {
          console.error('setOption 方法不存在');
          return JSON.stringify({ success: false, error: 'setOption方法不存在', stage: 'method_check' });
        }

        // 尝试调用setOption
        const option = ${configJson};
        console.log('图表配置:', option);

        const result = window.chartAPI.setOption(option);
        console.log('setOption 调用结果:', result);

        return JSON.stringify({ success: true, result: result, stage: 'success' });

      } catch (e) {
        console.error('JavaScript 执行错误:', e);
        return JSON.stringify({ success: false, error: e.toString(), stage: 'javascript_error' });
      }
    })()`;

    if (!webviewController) {
      console.error('[ChartPage] WebView 控制器未初始化');
      return;
    }

    webviewController.runJavaScript(jsCode)
      .then((result) => {
        console.info('[ChartPage] JavaScript 执行结果:', result);

        try {
          const parsedResult: ChartExecutionResult = JSON.parse(result);
          if (parsedResult.success) {
            console.info('[ChartPage] ✅ 图表配置设置成功！');
          } else {
            console.error('[ChartPage] ❌ 图表配置设置失败:', parsedResult.error, '阶段:', parsedResult.stage);

            // 如果是API未就绪的问题，进行重试
            if (retryCount < maxRetries &&
                (parsedResult.stage === 'api_check' || parsedResult.stage === 'method_check')) {
              console.info(`[ChartPage] ${retryDelay}ms 后进行第 ${retryCount + 2} 次重试`);
              setTimeout(() => {
                applyChartConfigWithRetry(config, retryCount + 1);
              }, retryDelay);
            } else {
              console.error('[ChartPage] 重试次数已达上限，设置失败');
            }
          }
        } catch (parseError) {
          console.error('[ChartPage] 解析JavaScript结果失败:', parseError);
          console.error('[ChartPage] 原始结果:', result);
        }
      })
      .catch((err: Error) => {
        console.error('[ChartPage] runJavaScript 执行失败:', err);

        // 网络或系统错误，进行重试
        if (retryCount < maxRetries) {
          console.info(`[ChartPage] 系统错误，${retryDelay}ms 后进行第 ${retryCount + 2} 次重试`);
          setTimeout(() => {
            applyChartConfigWithRetry(config, retryCount + 1);
          }, retryDelay);
        }
      });

  } catch (error) {
    console.error('[ChartPage] 序列化图表配置失败:', error);
  }
}

@Entry
@Component
export struct ChartPage {
  @State isLoading: boolean = true;
  @State chartConfig: ChartConfig | null = globalChartConfig;
  @State errorMessage: string = '';
  @State loadingMessage: string = '正在加载图表...';
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

  /**
   * 导出PNG图片
   */
  async exportPNG(): Promise<void> {
    if (!webviewController) {
      console.error('[ChartPage] WebView控制器未初始化');
      return;
    }

    try {
      console.info('[ChartPage] 开始导出PNG图片');

      // 调用JavaScript导出图表
      const jsCode = `
        (function() {
          try {
            console.log('开始导出PNG...');
            if (window.chartAPI && window.chartAPI.exportImage) {
              const dataURL = window.chartAPI.exportImage({
                type: 'png',
                backgroundColor: '#1C1C1C', // 深色背景
                pixelRatio: 2
              });
              console.log('PNG导出成功，数据长度:', dataURL.length);
              return JSON.stringify({ success: true, dataURL: dataURL });
            } else {
              return JSON.stringify({ success: false, error: '图表未初始化或导出功能不可用' });
            }
          } catch (e) {
            console.error('PNG导出失败:', e);
            return JSON.stringify({ success: false, error: e.toString() });
          }
        })()
      `;

      const result = await webviewController.runJavaScript(jsCode);
      const parsedResult: PNGExportResult = JSON.parse(result);

      if (parsedResult.success && parsedResult.dataURL) {
        await this.saveImageFile(parsedResult.dataURL, 'chart.png');
        console.info('[ChartPage] PNG导出完成');
      } else {
        console.error('[ChartPage] PNG导出失败:', parsedResult.error);
      }
    } catch (error) {
      console.error('[ChartPage] PNG导出异常:', error);
    }
  }

  /**
   * 导出PDF文件（简化版，实际应用中可能需要更复杂的实现）
   */
  async exportPDF(): Promise<void> {
    // HarmonyOS的PDF导出相对复杂，这里先提供基础实现
    // 可以通过打印服务或第三方库实现
    console.info('[ChartPage] PDF导出功能开发中...');

    // 临时实现：先导出PNG，后续可扩展为PDF
    await this.exportPNG();
  }

  /**
   * 保存图片文件到本地
   */
  private async saveImageFile(dataURL: string, fileName: string): Promise<void> {
    try {
      // 从dataURL中提取base64数据
      const base64Data = dataURL.replace(/^data:image\/png;base64,/, '');

      // 将base64转换为ArrayBuffer
      const base64 = new util.Base64Helper();
      const uint8Array: Uint8Array = base64.decodeSync(base64Data);

      // 使用文件保存器保存文件
      const documentViewPicker = new picker.DocumentViewPicker();
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;

      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.SAVE_MODE;
      documentSaveOptions.newFileNames = [fileName];

      const uri = await documentViewPicker.save(documentSaveOptions);
      if (uri) {
        const file = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
        fs.writeSync(file.fd, uint8Array);
        fs.closeSync(file);
        console.info('[ChartPage] 文件保存成功:', uri);
      }
    } catch (error) {
      console.error('[ChartPage] 保存文件失败:', error);
    }
  }

  /**
   * 重新生成图表功能
   */
  async regenerateChart(chartType?: string): Promise<void> {
    if (this.isLoading) {
      return;
    }

    try {
      console.info('[ChartPage] ========== 开始重新生成图表 ==========');

      // 检查是否有原始数据
      const originalData = getOriginalData();
      if (!originalData || !hasValidData(originalData)) {
        throw new Error('没有原始数据用于重新生成图表');
      }

      console.info('[ChartPage] 使用原始数据重新生成图表，数据行数:', getDataLength(originalData));

      this.isLoading = true;
      this.loadingMessage = '正在重新生成图表...';

      // generateChart函数已从模块导入

      // 如果指定了图表类型，可以在这里处理
      let userData = originalData;
      if (chartType) {
        // 可以根据chartType调整用户数据的配置
        console.info('[ChartPage] 指定图表类型:', chartType);
        userData = Object.assign({}, originalData, { chartType });
      }

      // 调用AI服务重新生成图表配置
      const newChartConfig: ChartConfig = await generateChart(userData);
      console.info('[ChartPage] 新图表配置生成成功');

      // 更新全局配置
      globalChartConfig = newChartConfig;
      this.chartConfig = newChartConfig;

      // 应用新的图表配置
      if (webviewController) {
        console.info('[ChartPage] 应用新的图表配置');
        applyChartConfigWithRetry(newChartConfig, 0);
      } else {
        console.warn('[ChartPage] WebView控制器未初始化');
      }

      console.info('[ChartPage] ✅ 图表重新生成完成');

    } catch (error) {
      console.error('[ChartPage] ❌ 重新生成图表失败:', error);

      // 显示错误信息
      this.errorMessage = `重新生成失败: ${error instanceof Error ? error.message : '未知错误'}`;
      this.isLoading = false;

      // 延迟清除错误消息
      setTimeout(() => {
        this.errorMessage = '';
      }, 3000);
    } finally {
      this.isLoading = false;
    }
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
        this.ActionButton('🖼️', '导出 PNG', false, async () => {
          console.info('导出 PNG 被点击');
          await this.exportPNG();
        })

        // 导出 PDF
        this.ActionButton('📄', '导出 PDF', false, async () => {
          console.info('导出 PDF 被点击');
          await this.exportPDF();
        })

        // 重新生成
        this.ActionButton('🔄', '重新生成', false, async () => {
          console.info('重新生成被点击');
          await this.regenerateChart();
        })

        // 更换图表（主色调）
        this.ActionButton('📈', '更换图表', true, () => {
          console.info('更换图表被点击');
          router.pushNamedRoute({
            name: 'ChartTypeSelectorPage'
          }).catch((err: BusinessError) => {
            console.error('跳转到图表类型选择页面失败:', err);
          });
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