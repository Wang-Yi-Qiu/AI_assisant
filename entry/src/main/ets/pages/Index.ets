/**
 * 首页：数据输入与图表生成入口
 * @module Index
 */

import { onGenerateFromText } from './HomePage';
import { setChartOption } from './ChartPage';
import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showSuccess: boolean = false;

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
        }).catch((err: Error) => {
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
  async onGenerateChart() {
    if (!this.inputText.trim()) {
      this.errorMessage = '请输入数据后再生成图表';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.showSuccess = false;

    try {
      const chartConfig = await onGenerateFromText(this.inputText);
      setChartOption(chartConfig);
      
      this.showSuccess = true;
      
      // 跳转到图表页
      setTimeout(() => {
        router.pushUrl({
          url: 'pages/ChartPage'
        }).catch((err: Error) => {
          console.error('跳转到图表页失败:', err);
          this.errorMessage = '生成成功，但跳转失败';
          this.showSuccess = false;
        });
      }, 1000);
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '生成图表失败，请稍后重试';
      console.error('生成图表失败:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 上传文件
   */
  async onUploadFile() {
    // TODO: 实现文件选择器
    // import picker from '@ohos.file.picker';
    // const filePicker = new picker.DocumentViewPicker();
    // const result = await filePicker.select();
    // if (result && result.length > 0) {
    //   const file = result[0];
    //   const content = await readFileContent(file.uri);
    //   await this.onGenerateFromFile(content, file.name);
    // }
    
    this.errorMessage = '文件上传功能开发中，请使用文本输入';
  }
}
