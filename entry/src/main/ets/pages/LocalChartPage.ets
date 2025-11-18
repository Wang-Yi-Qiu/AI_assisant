/**
 * 本地图表页面
 * 使用ECharts进行本地图表渲染
 * 支持多种图表类型和导出功能
 */

import router from '@ohos.router';
import { LocalChartService, LocalChartData, LocalChartConfig, ExportFormat } from '../utils/localChartService';
import { webview } from '@kit.ArkWeb';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

@Entry
@Component
export struct LocalChartPage {
  @State webController: webview.WebviewController = new webview.WebviewController();
  @State isLoading: boolean = false;
  @State loadingMessage: string = '';
  @State chartData: LocalChartData | null = null;
  @State chartConfig: LocalChartConfig | null = null;
  @State showExportDialog: boolean = false;
  private localChartService: LocalChartService = LocalChartService.getInstance();

  aboutToAppear(): void {
    console.info('[LocalChartPage] 页面初始化');

    // 获取页面参数
    const params = router.getParams() as any;
    if (params && params.chartData) {
      try {
        console.info('[LocalChartPage] 接收到图表数据');
        const chartData = JSON.parse(params.chartData) as LocalChartData;
        this.setChartData(chartData);
      } catch (error) {
        console.error('[LocalChartPage] 解析图表数据失败:', error);
      }
    }
  }

  /**
   * 设置图表数据
   */
  setChartData(data: LocalChartData, config?: LocalChartConfig): void {
    this.chartData = data;
    this.chartConfig = config || this.localChartService.generateChartConfig(data);
    this.loadChart();
  }

  /**
   * 加载图表
   */
  private async loadChart(): Promise<void> {
    if (!this.chartData || !this.chartConfig) {
      console.error('[LocalChartPage] 图表数据或配置为空');
      return;
    }

    try {
      console.info('[LocalChartPage] 开始加载图表');
      this.isLoading = true;
      this.loadingMessage = '正在渲染图表...';

      // 获取ECharts配置
      const eChartsOption = this.localChartService.toEChartsOption(this.chartConfig);
      const optionJson = JSON.stringify(eChartsOption, null, 2);

      console.info('[LocalChartPage] ECharts配置生成完成');

      // 等待WebView加载完成
      await this.waitForWebViewReady();

      // 设置图表配置
      await this.webController.runJavaScript(`
        if (window.myChart) {
          window.myChart.setOption(${optionJson});
          console.log('图表配置设置完成');
        }
      `);

      console.info('[LocalChartPage] 图表加载完成');

    } catch (error) {
      console.error('[LocalChartPage] 图表加载失败:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 等待WebView准备就绪
   */
  private async waitForWebViewReady(): Promise<void> {
    const maxAttempts = 50;
    const delay = 100;

    for (let i = 0; i < maxAttempts; i++) {
      try {
        const result = await this.webController.runJavaScript(`
          window.myChart !== undefined && typeof window.myChart.setOption === 'function'
        `);

        if (result === 'true') {
          console.info('[LocalChartPage] WebView准备就绪');
          return;
        }
      } catch (error) {
        console.warn(`[LocalChartPage] 检查WebView状态失败 (尝试 ${i + 1}/${maxAttempts}):`, error);
      }

      // 等待一段时间再重试
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, delay);
      });
    }

    throw new Error('WebView未能在预期时间内准备就绪');
  }

  /**
   * 切换图表类型
   */
  switchChartType(type: 'bar' | 'line' | 'pie' | 'scatter'): void {
    if (this.chartData) {
      this.chartConfig = this.localChartService.generateChartConfig(this.chartData, type);
      this.loadChart();
    }
  }

  /**
   * 显示导出对话框
   */
  showExportOptions(): void {
    this.showExportDialog = true;
  }

  /**
   * 隐藏导出对话框
   */
  hideExportDialog(): void {
    this.showExportDialog = false;
  }

  /**
   * 导出数据
   */
  async exportData(format: ExportFormat): Promise<void> {
    if (!this.chartData) {
      console.error('[LocalChartPage] 没有数据可导出');
      return;
    }

    try {
      console.info('[LocalChartPage] 开始导出数据，格式:', format);

      // 生成导出内容
      const content = this.localChartService.exportData(this.chartData, format);
      const fileName = `chart_data_${new Date().toISOString().slice(0, 10)}.${format}`;

      // 创建文件保存选项
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [fileName];

      const documentViewPicker = new picker.DocumentViewPicker();
      const uriList = await documentViewPicker.save(documentSaveOptions);

      if (uriList && uriList.length > 0) {
        const uri = uriList[0];
        console.info('[LocalChartPage] 保存文件:', uri);

        // 写入文件内容
        const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        const encoder = util.TextEncoder.create();
        const buffer = encoder.encode(content);
        fs.writeSync(file.fd, buffer);
        fs.closeSync(file);

        console.info('[LocalChartPage] 文件导出完成');
      }

      this.hideExportDialog();

    } catch (error) {
      console.error('[LocalChartPage] 导出失败:', error);
    }
  }

  /**
   * 导出图表图片
   */
  async exportChartImage(): Promise<void> {
    try {
      console.info('[LocalChartPage] 开始导出图表图片');

      // 通过WebView导出图片
      const imageData = await this.webController.runJavaScript(`
        if (window.myChart) {
          return window.myChart.getDataURL({
            type: 'png',
            pixelRatio: 2,
            backgroundColor: '#fff'
          });
        }
        return null;
      `);

      if (imageData && imageData !== 'null') {
        console.info('[LocalChartPage] 获取到图片数据，长度:', imageData.length);

        // 保存图片
        const fileName = `chart_${new Date().toISOString().slice(0, 10)}.png`;
        const documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [fileName];

        const documentViewPicker = new picker.DocumentViewPicker();
        const uriList = await documentViewPicker.save(documentSaveOptions);

        if (uriList && uriList.length > 0) {
          const uri = uriList[0];
          console.info('[LocalChartPage] 保存图片到:', uri);

          // 写入base64数据到文件
          const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);

          // 移除data URL前缀
          const base64Data = imageData.replace(/^data:image\/png;base64,/, '');

          // 解码base64数据
          const binaryString = atob(base64Data);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }

          fs.writeSync(file.fd, bytes.buffer);
          fs.closeSync(file);

          console.info('[LocalChartPage] 图片导出完成');
        }
      } else {
        console.warn('[LocalChartPage] 未能获取图表图片数据');
      }

    } catch (error) {
      console.error('[LocalChartPage] 图片导出失败:', error);
    }
  }

  /**
   * 返回上一页
   */
  goBack(): void {
    router.back();
  }

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // 顶部导航栏
        Row() {
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
            this.goBack();
          })

          Blank()

          Text('数据图表')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Blank()
            .width(40)

          // 导出按钮
          Button() {
            Text('导出')
              .fontSize(14)
              .fontColor(Color.White)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showExportOptions();
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 15, right: 15 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#1C1C1C')

        // 图表类型切换按钮
        if (this.chartConfig) {
          Row() {
            Button('柱状图')
              .fontSize(12)
              .backgroundColor(this.chartConfig.type === 'bar' ? '#007DFF' : '#252525')
              .fontColor(Color.White)
              .margin({ right: 8 })
              .onClick(() => {
                this.switchChartType('bar');
              })

            Button('折线图')
              .fontSize(12)
              .backgroundColor(this.chartConfig.type === 'line' ? '#007DFF' : '#252525')
              .fontColor(Color.White)
              .margin({ right: 8 })
              .onClick(() => {
                this.switchChartType('line');
              })

            Button('饼图')
              .fontSize(12)
              .backgroundColor(this.chartConfig.type === 'pie' ? '#007DFF' : '#252525')
              .fontColor(Color.White)
              .margin({ right: 8 })
              .onClick(() => {
                this.switchChartType('pie');
              })

            Button('散点图')
              .fontSize(12)
              .backgroundColor(this.chartConfig.type === 'scatter' ? '#007DFF' : '#252525')
              .fontColor(Color.White)
              .onClick(() => {
                this.switchChartType('scatter');
              })
          }
          .width('90%')
          .margin({ top: 10, bottom: 10 })
          .justifyContent(FlexAlign.Start)
        }

        // 图表显示区域
        Column() {
          Text('图表加载中...')
            .fontSize(16)
            .fontColor(Color.Gray)
            .margin(20)

          // ECharts WebView
          Web({ src: $rawfile('echarts.html'), controller: this.webController })
            .width('100%')
            .height('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .mixedMode(MixedMode.All)
            .onPageEnd(() => {
              console.info('[LocalChartPage] WebView页面加载完成');
              if (this.chartConfig) {
                this.loadChart();
              }
            })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1C1C1C')

      // 加载状态提示
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 10 })
          Text(this.loadingMessage)
            .fontSize(14)
            .fontColor(Color.Gray)
        }
        .width('100%')
        .padding(20)
        .backgroundColor('rgba(28, 28, 28, 0.9)')
      }

      // 导出选项对话框
      if (this.showExportDialog) {
        Stack() {
          // 背景遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.hideExportDialog();
            })

          // 对话框内容
          Column() {
            // 标题栏
            Row() {
              Text('选择导出格式')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
              Text('✕')
                .fontSize(24)
                .fontColor(Color.Gray)
                .onClick(() => {
                  this.hideExportDialog();
                })
            }
            .width('100%')
            .padding(15)

            Divider()
              .color('#333333')

            // 导出选项
            Column() {
              Button('导出为图片 (PNG)')
                .width('100%')
                .height(50)
                .backgroundColor('#252525')
                .fontColor(Color.White)
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.exportChartImage();
                })

              Button('导出数据为 CSV')
                .width('100%')
                .height(50)
                .backgroundColor('#252525')
                .fontColor(Color.White)
                .margin({ bottom: 10 })
                .onClick(() => {
                  this.exportData('csv');
                })

              Button('导出数据为 JSON')
                .width('100%')
                .height(50)
                .backgroundColor('#252525')
                .fontColor(Color.White)
                .onClick(() => {
                  this.exportData('json');
                })
            }
            .width('100%')
            .padding(15)
          }
          .width('80%')
          .backgroundColor('#252525')
          .borderRadius(15)
          .alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .height('100%')
      }
    }
  }
}