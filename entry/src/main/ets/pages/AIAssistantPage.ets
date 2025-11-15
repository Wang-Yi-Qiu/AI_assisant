import router from '@ohos.router';
import { generateChart, ChartConfig, UserData } from '../utils/aiService';
import { loadSampleData, getSampleDataList, SampleDataset } from '../utils/sampleDataManager';
import { getSampleChartList, SampleChart } from '../utils/sampleChartManager';
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
  @State sampleChartList: SampleChart[] = getSampleChartList();
  @State showSampleDataDialog: boolean = false;

  aboutToAppear() {
    // 页面加载时获取样本数据列表和示例图表列表
    this.sampleDataList = getSampleDataList();
    this.sampleChartList = getSampleChartList();
  }

  /**
   * 使用示例图表
   */
  handleUseSampleChart(sampleChart: SampleChart) {
    console.info('[AIAssistantPage] 使用示例图表:', sampleChart.id);
    setChartOption(sampleChart.chartConfig);
    router.pushNamedRoute({
      name: 'ChartPage'
    }).catch((err: BusinessError) => {
      console.error('跳转到图表页失败:', err);
    });
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
      await router.pushNamedRoute({
        name: 'ChartPage'
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

  /**
   * 构建操作按钮
   */
  @Builder
  ActionButton(icon: string, text: string, isPrimary: boolean, onClick: () => void) {
    Button() {
      Row() {
        Text(icon)
          .fontSize(24)
          .margin({ right: 10 })
        Text(text)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .type(ButtonType.Capsule)
    .stateEffect(true)
    .width('90%')
    .height(56)
    .backgroundColor(isPrimary ? '#007DFF' : '#252525')
    .border(isPrimary ? undefined : { width: 1, color: '#007DFF', style: BorderStyle.Solid })
    .margin({ bottom: 15 })
    .enabled(!this.isLoading)
    .onClick(onClick)
  }

  /**
   * 构建示例图表卡片
   */
  @Builder
  SampleChartCard(sampleChart: SampleChart) {
    Column() {
      Text(sampleChart.icon)
        .fontSize(40)
        .margin({ bottom: 10 })
      Text(sampleChart.name)
        .fontSize(12)
        .fontColor(Color.Gray)
        .margin({ bottom: 4 })
      Text(sampleChart.description)
        .fontSize(10)
        .fontColor('#666666')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(10)
    .backgroundColor('#1C1C1C')
    .borderRadius(15)
    .onClick(() => {
      this.handleUseSampleChart(sampleChart);
    })
  }

  /**
   * 构建示例数据选择项
   */
  @Builder
  SampleDataItem(sample: SampleDataset) {
    Row() {
      Column() {
        Text(sample.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .alignSelf(ItemAlign.Start)
        Text(sample.description)
          .fontSize(12)
          .fontColor(Color.Gray)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .alignSelf(ItemAlign.Start)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('→')
        .fontSize(20)
        .fontColor('#007DFF')
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#252525')
    .borderRadius(10)
    .margin({ bottom: 10 })
    .onClick(() => {
      this.showSampleDataDialog = false;
      this.handleUseSampleData(sample.id);
    })
  }

  build() {
    Stack() {
      // 主内容区域 - 可滚动
      Scroll() {
        Column() {
          // 顶部标题区域
          Column() {
            Text('AI 智能数据可视化助手')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 20, bottom: 12 })

            Text('上传 CSV 文件或手动输入数据')
              .fontSize(14)
              .fontColor(Color.Gray)
              .textAlign(TextAlign.Center)
              .margin({ bottom: 4 })

            Text('开始您的第一次数据可视化')
              .fontSize(14)
              .fontColor(Color.Gray)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 30 })
          .alignItems(HorizontalAlign.Center)

          // 数据输入操作区 - 三个主要操作按钮
          Column() {
            // 上传数据按钮（主色调）
            this.ActionButton('📄', '上传数据', true, () => {
              console.info('点击上传数据');
              // TODO: 实现文件选择器逻辑
            })

            // 手动输入按钮（深色背景，亮色边框）
            this.ActionButton('✍️', '手动输入', false, () => {
              console.info('点击手动输入');
              // TODO: 导航到数据手动输入页面
            })

            // 使用示例数据按钮（深色背景，亮色边框）
            this.ActionButton('📊', '使用示例数据', false, () => {
              console.info('点击使用示例数据');
              // 显示示例数据选择对话框
              this.showSampleDataDialog = true;
            })
          }
          .width('100%')
          .margin({ bottom: 30 })

          // 历史图表区
          Column() {
            Row() {
              Text('历史图表')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
            }
            .width('100%')
            .margin({ bottom: 15 })

            // 示例图表网格布局
            Grid() {
              ForEach(this.sampleChartList, (sampleChart: SampleChart) => {
                GridItem() {
                  this.SampleChartCard(sampleChart)
                }
              }, (sampleChart: SampleChart) => sampleChart.id)
            }
            .columnsTemplate('1fr 1fr')
            .rowsTemplate('1fr 1fr')
            .columnsGap(12)
            .rowsGap(12)
            .width('100%')
            .height(220)
          }
          .width('90%')
          .margin({ bottom: 20 })

          // 底部间距，确保内容不会被遮挡
          Column()
            .height(100)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollable(ScrollDirection.Vertical) // 明确指定垂直滚动
      .scrollBar(BarState.Auto) // 自动显示滚动条
      .edgeEffect(EdgeEffect.Spring) // 添加弹性效果

      // 加载状态提示（覆盖在顶层）
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
        .position({ x: 0, y: '70%' }) // 固定在底部位置
      }

      // 示例数据选择对话框（覆盖在顶层）
      if (this.showSampleDataDialog) {
        Stack() {
          // 背景遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.showSampleDataDialog = false;
            })

          // 对话框内容
          Column() {
            // 标题栏
            Row() {
              Text('选择示例数据')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
              Text('✕')
                .fontSize(24)
                .fontColor(Color.Gray)
                .onClick(() => {
                  this.showSampleDataDialog = false;
                })
            }
            .width('100%')
            .padding(15)
            .border({ width: 0, color: Color.Transparent })

            Divider()
              .color('#333333')

            // 示例数据列表
            Scroll() {
              Column() {
                ForEach(this.sampleDataList, (sample: SampleDataset) => {
                  this.SampleDataItem(sample)
                }, (sample: SampleDataset) => sample.id)
              }
              .width('100%')
              .padding(15)
            }
            .layoutWeight(1)
            .width('100%')
          }
          .width('90%')
          .height('70%')
          .backgroundColor('#252525')
          .borderRadius(15)
          .alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
  }
}