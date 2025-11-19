/**
 * 首页：数据输入与图表生成入口
 * @module Index
 */

import { onGenerateFromText, parseFileContent } from './HomePage';
import { setChartOption } from './ChartPage';
import router from '@ohos.router';
import filePicker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { ErrorHandler, AppError } from '../utils/errorHandler';
import { asyncManager, AsyncOptions, CancellationToken } from '../utils/asyncManager';

interface ManagedTask {
  cancel(): void;
}

@Entry
@Component
struct Index {
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showSuccess: boolean = false;
  // 异步任务管理
  private currentTask: ManagedTask | null = null;
  private isDestroyed: boolean = false;

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
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })
        Text('输入或上传数据，AI 自动生成图表')
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ top: 40, bottom: 20 })
      .backgroundColor('#F5F5F5')

        // 输入区域（自适应高度与间距）
        Column() {
        Text('数据输入')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })

        TextArea({ placeholder: '请输入数据（支持 JSON、CSV 或纯文本）\n\n示例 JSON:\n{"月份":["1月","2月","3月"],"销售额":[120,200,150]}\n\n示例 CSV:\n月份,销售额\n1月,120\n2月,200\n3月,150' })
          .width('100%')
          .height('40%')
          .fontSize(14)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')
          .onChange((value: string) => {
            this.inputText = value;
            this.errorMessage = '';
            this.showSuccess = false;
          })

        Row() {
          Button('上传文件')
            .type(ButtonType.Normal)
            .backgroundColor('#E3F2FD')
            .fontColor('#1976D2')
            .onClick(() => {
              this.onUploadFile();
            })

          Blank()

          Button('生成图表')
            .type(ButtonType.Capsule)
            .backgroundColor('#1976D2')
            .fontColor(Color.White)
            .enabled(!this.isLoading && this.inputText.trim().length > 0)
            .onClick(() => {
              this.onGenerateChart();
            })
        }
        .width('100%')
        .height(48)
        .margin({ top: 16 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .margin({ top: 16, left: 16, right: 16 })

      // 状态提示
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 8 })
          Text('AI 正在生成图表，请稍候...')
            .fontSize(14)
            .fontColor('#666666')
        }
        .width('100%')
        .padding(20)
        .margin({ top: 20 })
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#F44336')
          .backgroundColor('#FFEBEE')
          .padding(12)
          .borderRadius(8)
          .width('100%')
          .margin({ top: 16, left: 16, right: 16 })
      }

      if (this.showSuccess) {
        Text('✅ 图表生成成功！正在跳转...')
          .fontSize(14)
          .fontColor('#4CAF50')
          .backgroundColor('#E8F5E9')
          .padding(12)
          .borderRadius(8)
          .width('100%')
          .margin({ top: 16, left: 16, right: 16 })
      }

      // 历史记录入口
      Row() {
        Image($r('app.media.startIcon'))
          .width(20)
          .height(20)
        Text('查看历史记录')
          .fontSize(14)
          .fontColor('#1976D2')
      }
      .width('100%')
      .padding(16)
      .margin({ top: 20 })
      .onClick(() => {
        router.pushUrl({
          url: 'pages/HistoryPage'
        }).catch((err: BusinessError) => {
          console.error('跳转到历史页失败:', err);
          this.errorMessage = '无法打开历史记录页';
        });
      })

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
      return await onGenerateFromText(this.inputText, signal);
    }, options);

    this.currentTask.promise
      .then((chartConfig) => {
        if (this.isDestroyed) return;

        setChartOption(chartConfig); // 不传入控制器，只保存配置
        this.showSuccess = true;

        // 跳转到图表页
        setTimeout(() => {
          if (!this.isDestroyed) {
            router.pushUrl({
                url: 'pages/ChartPage'
              }).catch((err: BusinessError) => {
                console.error('跳转到图表页失败:', err);
                if (!this.isDestroyed) {
                this.errorMessage = '生成成功，但跳转失败';
                this.showSuccess = false;
              }
            });
          }
        }, 1000);
      })
      .catch((error) => {
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

      // 创建文档选择器
      const documentPicker = new filePicker.DocumentViewPicker();
      documentPicker.select((err: BusinessError, result: Array<string>) => {
        if (err) {
          console.error('文件选择失败:', err);
          this.errorMessage = `文件选择失败: ${err.message}`;
          this.isLoading = false;
          return;
        }

        if (result && result.length > 0) {
          const fileUri = result[0];
          console.log('选择的文件:', fileUri);
          this.processFile(fileUri);
        } else {
          this.errorMessage = '未选择文件';
          this.isLoading = false;
        }
      });

      // 设置文件类型过滤器 - 移除不存在的selectFile方法
      // documentPicker API在HarmonyOS中已更新，无需手动设置过滤器

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

      // 解析文件内容
      const parsedData = parseFileContent(content);
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
      // 1. 先检查文件大小
      const stat = fs.statSync(fileUri);
      if (stat.size > MAX_FILE_SIZE) {
        throw new Error(`文件过大，最大支持 ${Math.round(MAX_FILE_SIZE / 1024 / 1024)}MB`);
      }

      if (stat.size === 0) {
        throw new Error('文件为空');
      }

      // 2. 打开文件
      const file = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);

      try {
        // 3. 分块读取文件内容
        let offset = 0;
        const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

        while (offset < stat.size) {
          const remainingSize = Math.min(CHUNK_SIZE, stat.size - offset);
          const buffer = new ArrayBuffer(remainingSize);
          const readLen = fs.readSync(file.fd, buffer, {
          offset: offset
        });

          if (readLen === 0) break;

          const uint8Array = new Uint8Array(buffer, 0, readLen);
          const chunk = decoder.decode(uint8Array);
          content += chunk;
          offset += readLen;
        }

      } finally {
        // 4. 确保文件句柄被关闭
        fs.closeSync(file.fd);
      }

      return content;

    } catch (error) {
      console.error('读取文件失败:', error);
      throw error; // 让上层的ErrorHandler处理
    }
  }
}
