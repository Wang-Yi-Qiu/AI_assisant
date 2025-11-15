/**
 * 首页：数据输入与图表生成入口
 * @module Index
 */

import { onGenerateFromText, parseFileContent } from './HomePage';
import { CancellationToken as AIServiceCancellationToken } from '../utils/aiService';
import { setChartOption } from './ChartPage';
import router from '@ohos.router';
import filePicker from '@ohos.file.picker';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { ErrorHandler, AppError } from '../utils/errorHandler';
import { asyncManager, AsyncOptions, CancellationToken, AsyncTask } from '../utils/asyncManager';
import { deviceAdapter, DeviceType } from '../utils/deviceAdapter';
import { ChartConfig } from '../utils/aiService';

@Entry
@Component
struct Index {
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showSuccess: boolean = false;
  // 异步任务管理
  private currentTask: AsyncTask<ChartConfig> | null = null;
  private isDestroyed: boolean = false;
  // 设备适配
  private layoutConfig = deviceAdapter.getLayoutConfig();
  private supportsFileUpload = deviceAdapter.supportsFileUpload();
  private deviceType = deviceAdapter.getDeviceType();

  aboutToAppear() {
    // 注意：窗口大小变化监听功能暂时移除，因为getContext已弃用
    // 如果需要，可以在组件内部使用窗口API直接监听
    // 当前布局配置会在组件初始化时自动适配设备类型
  }

  aboutToDisappear() {
    // 组件销毁时取消所有任务
    this.cancelCurrentTask();
  }

  /**
   * 取消当前任务
   */
  private cancelCurrentTask(): void {
    if (this.currentTask) {
      this.currentTask.cancel();
      this.currentTask = null;
    }
  }

  build() {
    Scroll() {
      Column() {
      // 顶部标题
      Column() {
        Text('AI 智能数据可视化助手')
          .fontSize(this.layoutConfig.fontSize.title)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: this.layoutConfig.spacing.small })
        Text(this.deviceType === DeviceType.TV || this.deviceType === DeviceType.CAR 
          ? '输入数据，AI 自动生成图表' 
          : '输入或上传数据，AI 自动生成图表')
          .fontSize(this.layoutConfig.fontSize.medium)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ 
        top: this.layoutConfig.padding.large, 
        bottom: this.layoutConfig.padding.medium 
      })
      .backgroundColor('#F5F5F5')

        // 输入区域（自适应高度与间距）
        Column() {
        Text('数据输入')
          .fontSize(this.layoutConfig.fontSize.large)
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: this.layoutConfig.spacing.medium })

        TextArea({ 
          placeholder: this.deviceType === DeviceType.TV || this.deviceType === DeviceType.CAR
            ? '请输入数据（支持 JSON、CSV 或纯文本）\n\n示例 JSON:\n{"月份":["1月","2月","3月"],"销售额":[120,200,150]}\n\n示例 CSV:\n月份,销售额\n1月,120\n2月,200\n3月,150'
            : '请输入数据（支持 JSON、CSV 或纯文本）\n\n示例 JSON:\n{"月份":["1月","2月","3月"],"销售额":[120,200,150]}\n\n示例 CSV:\n月份,销售额\n1月,120\n2月,200\n3月,150'
        })
          .width('100%')
          .height(this.deviceType === DeviceType.WEARABLE ? '50%' : '40%')
          .fontSize(this.layoutConfig.fontSize.medium)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')
          .onChange((value: string) => {
            this.inputText = value;
            this.errorMessage = '';
            this.showSuccess = false;
          })

        Row() {
          // 文件上传按钮（根据设备能力显示/隐藏）
          if (this.supportsFileUpload) {
            Button('上传文件')
              .type(ButtonType.Normal)
              .backgroundColor('#E3F2FD')
              .fontColor('#1976D2')
              .fontSize(this.layoutConfig.fontSize.medium)
              .onClick(() => {
                this.onUploadFile();
              })
          } else {
            // 不支持文件上传时显示提示文本
            Text(deviceAdapter.getFallbackMessage('fileUpload'))
              .fontSize(this.layoutConfig.fontSize.small)
              .fontColor('#666666')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Blank()

          Button('生成图表')
            .type(ButtonType.Capsule)
            .backgroundColor('#1976D2')
            .fontColor(Color.White)
            .fontSize(this.layoutConfig.fontSize.medium)
            .enabled(!this.isLoading && this.inputText.trim().length > 0)
            .onClick(() => {
              this.onGenerateChart();
            })
        }
        .width('100%')
        .height(this.deviceType === DeviceType.WEARABLE ? 40 : 48)
        .margin({ top: this.layoutConfig.spacing.medium })
      }
      .width('100%')
      .padding(this.layoutConfig.padding.medium)
      .backgroundColor('#FFFFFF')
      .margin({ 
        top: this.layoutConfig.spacing.medium, 
        left: this.layoutConfig.spacing.medium, 
        right: this.layoutConfig.spacing.medium 
      })

      // 状态提示
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 8 })
          Text('AI 正在生成图表，请稍候...')
            .fontSize(this.layoutConfig.fontSize.medium)
            .fontColor('#666666')
        }
        .width('100%')
        .padding(20)
        .margin({ top: 20 })
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(this.layoutConfig.fontSize.medium)
          .fontColor('#F44336')
          .backgroundColor('#FFEBEE')
          .padding(this.layoutConfig.padding.small)
          .borderRadius(8)
          .width('100%')
          .margin({ 
            top: this.layoutConfig.spacing.medium, 
            left: this.layoutConfig.spacing.medium, 
            right: this.layoutConfig.spacing.medium 
          })
      }

      if (this.showSuccess) {
        Text('✅ 图表生成成功！正在跳转...')
          .fontSize(this.layoutConfig.fontSize.medium)
          .fontColor('#4CAF50')
          .backgroundColor('#E8F5E9')
          .padding(this.layoutConfig.padding.small)
          .borderRadius(8)
          .width('100%')
          .margin({ 
            top: this.layoutConfig.spacing.medium, 
            left: this.layoutConfig.spacing.medium, 
            right: this.layoutConfig.spacing.medium 
          })
      }

      // 历史记录入口
      Row() {
        Image($r('app.media.startIcon'))
          .width(this.deviceType === DeviceType.WEARABLE ? 16 : 20)
          .height(this.deviceType === DeviceType.WEARABLE ? 16 : 20)
        Text('查看历史记录')
          .fontSize(this.layoutConfig.fontSize.medium)
          .fontColor('#1976D2')
      }
      .width('100%')
      .padding(this.layoutConfig.padding.medium)
      .margin({ top: this.layoutConfig.spacing.medium })
      .onClick(() => {
        // 使用 getUIContext().getRouter().pushUrl() 替代已弃用的 router.pushPathByName()
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/HistoryPage'
        }).catch((err: BusinessError) => {
          console.error('跳转到历史页失败:', err);
          this.errorMessage = '无法打开历史记录页';
        });
      })
      // 添加焦点支持（TV/车机）
      .focusable(deviceAdapter.needsFocusNavigation())
      .focusOnTouch(deviceAdapter.needsFocusNavigation())

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
  }

  /**
   * 生成图表
   */
  onGenerateChart() {
    if (!this.inputText.trim()) {
      this.errorMessage = '请输入数据后再生成图表';
      return;
    }

    // 取消之前的任务
    this.cancelCurrentTask();

    this.isLoading = true;
    this.errorMessage = '';
    this.showSuccess = false;

    const options: AsyncOptions = {
      timeout: 45000, // 45秒超时
      retryCount: 2,
      retryDelay: 1000,
      onProgress: (progress) => {
        console.log(`生成进度: ${Math.round(progress)}%`);
      }
    };

    this.currentTask = asyncManager.createTask(async (signal) => {
      // 转换 CancellationToken 类型 - 使用明确的接口实现
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
      return await onGenerateFromText(this.inputText, token);
    }, options);

    this.currentTask.promise
      .then((chartConfig: ChartConfig) => {
        if (this.isDestroyed) return;

        // 保存图表配置到全局状态（ChartPage会读取）
        console.log('图表生成成功，保存配置:', chartConfig);
        setChartOption(chartConfig); // 不传入控制器，只保存配置
        this.showSuccess = true;

        // 跳转到图表页（延迟确保状态已保存）
        setTimeout(() => {
          if (!this.isDestroyed) {
            // 使用 getUIContext().getRouter().pushUrl() 替代已弃用的 router.pushPathByName()
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/ChartPage'
            }).catch((err: BusinessError) => {
              console.error('跳转到图表页失败:', err);
              if (!this.isDestroyed) {
                this.errorMessage = '生成成功，但跳转失败。请手动打开历史记录查看';
                this.showSuccess = false;
              }
            });
          }
        }, 500); // 减少延迟时间，提高响应速度
      })
      .catch((error: Error | object | string) => {
        if (this.isDestroyed) return;

        const appError = ErrorHandler.handle(error, 'onGenerateChart');
        this.errorMessage = appError.userMessage || '生成图表失败，请稍后重试';
        console.error('生成图表失败:', appError);
      })
      .finally(() => {
        if (!this.isDestroyed) {
          this.isLoading = false;
          this.currentTask = null;
        }
      });
  }

  /**
   * 上传文件
   */
  async onUploadFile() {
    try {
      this.isLoading = true;
      this.errorMessage = '';

      // 创建文档选择器选项
      const documentSelectOptions = new filePicker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.csv', '.json', '.txt', '.xlsx', '.xls'];

      // 创建文档选择器
      const documentPicker = new filePicker.DocumentViewPicker();
      
      // 使用 select 方法打开文件选择器
      // 注意：根据 HarmonyOS API，select 方法只需要 DocumentSelectOptions 参数
      documentPicker.select(documentSelectOptions).then((result: Array<string>) => {
        if (result && result.length > 0) {
          const fileUri = result[0];
          console.log('选择的文件:', fileUri);
          this.processFile(fileUri);
        } else {
          this.errorMessage = '未选择文件';
          this.isLoading = false;
        }
      }).catch((err: BusinessError) => {
        console.error('文件选择失败:', err);
        this.errorMessage = `文件选择失败: ${err.message}`;
        this.isLoading = false;
      });

    } catch (error) {
      const appError = ErrorHandler.handle(error, 'onUploadFile');
      this.errorMessage = appError.userMessage || '文件上传失败，请稍后重试';
      console.error('文件上传失败:', appError);
      this.isLoading = false;
    }
  }

  /**
   * 处理选中的文件
   */
  private async processFile(fileUri: string) {
    try {
      // 读取文件内容
      const content = await this.readFileContent(fileUri);
      if (!content) {
        this.errorMessage = '无法读取文件内容';
        this.isLoading = false;
        return;
      }

      // 解析文件内容（需要传递文件名）
      const parsedData = parseFileContent(content, fileUri);
      this.inputText = JSON.stringify(parsedData, null, 2);

      this.errorMessage = '';
      console.log('文件解析成功');

    } catch (error) {
      const appError = ErrorHandler.handle(error, 'processFile');
      this.errorMessage = appError.userMessage || '文件处理失败';
      console.error('文件处理失败:', appError);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 读取文件内容（安全分块读取）
   */
  private async readFileContent(fileUri: string): Promise<string> {
    const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB 文件大小限制
    const CHUNK_SIZE = 64 * 1024; // 64KB 分块大小
    let content = '';

    try {
      // 使用 fileIo 模块进行文件操作（已在文件顶部导入）

      // 1. 先检查文件大小
      const stat = fileIo.statSync(fileUri);
      if (stat.size > MAX_FILE_SIZE) {
        throw new Error(`文件过大，最大支持 ${Math.round(MAX_FILE_SIZE / 1024 / 1024)}MB`);
      }

      if (stat.size === 0) {
        throw new Error('文件为空');
      }

      // 2. 打开文件
      const file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);

      try {
        // 3. 分块读取文件内容
        let offset = 0;
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

        while (offset < stat.size) {
          const remainingSize = Math.min(CHUNK_SIZE, stat.size - offset);
          const buffer = new ArrayBuffer(remainingSize);
          const readLen = fileIo.readSync(file.fd, buffer, { offset });

          if (readLen === 0) break;

          const uint8Array = new Uint8Array(buffer, 0, readLen);
          // 使用 decodeWithStream 方法（decode 已弃用）
          const chunk: string = decoder.decodeWithStream(uint8Array, { stream: false });
          content += chunk;
          offset += readLen;
        }

      } finally {
        // 4. 确保文件句柄被关闭
        fileIo.closeSync(file.fd);
      }

      return content;

    } catch (error) {
      console.error('读取文件失败:', error);
      // ArkTS限制：throw 语句只能抛出 Error 类型
      throw error instanceof Error ? error : new Error(String(error));
    }
  }
}
