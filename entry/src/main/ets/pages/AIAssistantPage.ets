import router from '@ohos.router';
import { generateChart, ChartConfig, UserData } from '../utils/aiService';
import { loadSampleData, getSampleDataList, SampleDataset } from '../utils/sampleDataManager';
import { setChartOption } from './ChartPage';
import { ErrorHandler } from '../utils/errorHandler';
import { getGlobalContext } from '../utils/sampleDataManager';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
export struct AIAssistantPage {
  @State isLoading: boolean = false;
  @State loadingMessage: string = '正在生成图表...';
  @State sampleDataList: SampleDataset[] = getSampleDataList();

  aboutToAppear() {
    // 页面加载时获取样本数据列表
    this.sampleDataList = getSampleDataList();
  }

  /**
   * 使用示例数据生成图表
   */
  async handleUseSampleData(sampleId: string) {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.loadingMessage = '正在加载示例数据...';

    try {
      console.info('[AIAssistantPage] 开始使用示例数据生成图表:', sampleId);
      
      // 1. 加载示例数据
      const context = getGlobalContext();
      if (!context) {
        throw new Error('应用上下文不可用');
      }

      this.loadingMessage = '正在加载示例数据...';
      const sampleDataJson = await loadSampleData(sampleId, context);
      console.info('[AIAssistantPage] 示例数据加载成功，长度:', sampleDataJson.length);

      // 2. 解析数据
      let userData: UserData;
      try {
        userData = JSON.parse(sampleDataJson);
        console.info('[AIAssistantPage] 数据解析成功');
      } catch (parseError) {
        console.error('[AIAssistantPage] 数据解析失败:', parseError);
        throw new Error('示例数据格式错误');
      }

      // 3. 调用 AI 服务生成图表配置
      this.loadingMessage = '正在调用千问API生成图表...';
      console.info('[AIAssistantPage] 开始调用 generateChart API');
      
      const chartConfig: ChartConfig = await generateChart(userData);
      console.info('[AIAssistantPage] 图表配置生成成功:', JSON.stringify(chartConfig).substring(0, 200));

      // 4. 设置图表配置并跳转
      setChartOption(chartConfig);
      console.info('[AIAssistantPage] 图表配置已设置，准备跳转');

      // 5. 跳转到图表页面
      await router.pushUrl({
        url: 'pages/ChartPage'
      });
      
      console.info('[AIAssistantPage] 已跳转到图表页面');
    } catch (error) {
      console.error('[AIAssistantPage] 生成图表失败:', error);
      const appError = ErrorHandler.handle(error, 'handleUseSampleData');
      
      // 显示错误提示（这里可以添加 Toast 或 Dialog）
      this.loadingMessage = `生成失败: ${appError.userMessage}`;
      
      // 延迟清除错误消息
      setTimeout(() => {
        this.loadingMessage = '正在生成图表...';
      }, 3000);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 顶部标题区域（固定）
      Column() {
        Text('AI 智能数据可视化助手')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ top: 20, bottom: 10 })

        Text('上传 CSV 文件或手动输入数据，\n开始您的第一次数据可视化。')
          .fontSize(14)
          .fontColor(Color.Gray)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })

      // 可滚动内容区域
      Scroll() {
        Column() {
          // 功能按钮
          Button('上传数据', { type: ButtonType.Capsule, stateEffect: true })
            .width('90%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#007DFF')
            .margin({ bottom: 15 })
            .onClick(() => {
              // 添加上传逻辑
              console.info('点击上传数据');
            })

          Button('手动输入', { type: ButtonType.Capsule, stateEffect: true })
            .width('90%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#252525')
            .margin({ bottom: 20 })
            .onClick(() => {
              // 添加手动输入逻辑
              console.info('点击手动输入');
            })

          // 示例数据选择区域
          Column() {
            Text('选择示例数据')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 15 })
            
            // 示例数据列表
            Column() {
              ForEach(this.sampleDataList, (sample: SampleDataset) => {
                Button(sample.name, { type: ButtonType.Normal, stateEffect: true })
                  .width('100%')
                  .height(45)
                  .fontSize(14)
                  .backgroundColor('#252525')
                  .fontColor(Color.White)
                  .margin({ bottom: 10 })
                  .enabled(!this.isLoading)
                  .onClick(() => {
                    this.handleUseSampleData(sample.id);
                  })
              }, (sample: SampleDataset) => sample.id)
            }
            .width('100%')
          }
          .width('90%')
          .padding(15)
          .backgroundColor('#252525')
          .borderRadius(15)
          .margin({ bottom: 20 })

          // 历史图表
          Column() {
            Row() {
              Text('历史图表')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
            }
            .width('100%')
            .margin({ bottom: 15 })

            Grid() {
              GridItem() {
                Column()
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#1C1C1C')
                  .borderRadius(15)
                  .onClick(() => router.pushUrl({ url: 'pages/ChartPage' }))
              }
              GridItem() {
                Column()
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#1C1C1C')
                  .borderRadius(15)
                  .onClick(() => router.pushUrl({ url: 'pages/ChartPage' }))
              }
              GridItem() {
                Column()
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#1C1C1C')
                  .borderRadius(15)
                  .onClick(() => router.pushUrl({ url: 'pages/ChartPage' }))
              }
            }
            .columnsTemplate('1fr 1fr')
            .rowsTemplate('1fr 1fr')
            .columnsGap(10)
            .rowsGap(10)
            .width('100%')
            .height(200)
          }
          .width('90%')
          .margin({ bottom: 20 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 20 })
      }
      .layoutWeight(1)
      .width('100%')

      // 加载状态提示（固定在底部）
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
        .backgroundColor('#1C1C1C')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
  }
}