/**
 * 智能图表选择页面
 * 基于本地AI算法推荐最适合的图表类型
 * 提供详细的推荐理由和配置选项
 */

import router from '@ohos.router';
import { LocalChartService, LocalChartData, ChartRecommendation, ExportFormat } from '../utils/localChartService';
import { ChartConfigFactory, ChartType } from '../chart/config/ChartConfigFactory';
import { ChartTheme } from '../chart/config/ChartTheme';
import { dataVisualizationService, FieldInfo } from '../utils/dataVisualizationService';
import { fileDataParser, ParsedData } from '../utils/fileDataParser';

@Entry
@Component
export struct SmartChartSelectorPage {
  @State parsedData: ParsedData | null = null;
  @State localChartData: LocalChartData | null = null;
  @State recommendations: ChartRecommendation[] = [];
  @State selectedChartType: string = '';
  @State isLoading: boolean = false;
  @State showAdvancedOptions: boolean = false;
  @State selectedTheme: ChartTheme = new ChartTheme('dark');
  @State enableAnimation: boolean = true;
  @State showDataLabels: boolean = false;
  @State customTitle: string = '';
  @State customSubtitle: string = '';

  private localChartService: LocalChartService = LocalChartService.getInstance();

  aboutToAppear(): void {
    console.info('[SmartChartSelectorPage] 页面初始化');
    this.initializeData();
  }

  /**
   * 初始化数据
   */
  private async initializeData(): Promise<void> {
    try {
      const params = router.getParams() as any;
      if (params && params.parsedData) {
        this.parsedData = params.parsedData as ParsedData;

        // 转换为LocalChartData
        this.localChartData = this.convertParsedDataToLocal(this.parsedData);

        // 生成智能推荐
        if (this.localChartData) {
          this.recommendations = this.localChartService.recommendChartTypes(this.localChartData);
          if (this.recommendations.length > 0) {
            this.selectedChartType = this.recommendations[0].type;
          }
        }

        console.info('[SmartChartSelectorPage] 数据初始化完成');
      }
    } catch (error) {
      console.error('[SmartChartSelectorPage] 数据初始化失败:', error);
    }
  }

  /**
   * 转换ParsedData为LocalChartData
   */
  private convertParsedDataToLocal(parsedData: ParsedData): LocalChartData {
    const numericColumns: number[] = [];
    const categoryColumns: number[] = [];

    // 分析数据类型
    for (let i = 0; i < parsedData.headers.length; i++) {
      const values = parsedData.data.map(row => row[parsedData.headers[i]]);
      const numericCount = values.filter(val => !isNaN(Number(val))).length;

      if (numericCount / values.length > 0.7) {
        numericColumns.push(i);
      } else {
        categoryColumns.push(i);
      }
    }

    return {
      headers: parsedData.headers,
      rows: parsedData.data.map(row => parsedData.headers.map(header => String(row[header]))),
      numericColumns,
      categoryColumns
    };
  }

  /**
   * 获取置信度颜色
   */
  private getConfidenceColor(confidence: 'high' | 'medium' | 'low'): string {
    switch (confidence) {
      case 'high': return '#00C853';
      case 'medium': return '#FF9800';
      case 'low': return '#F44336';
      default: return '#757575';
    }
  }

  /**
   * 获取置信度文本
   */
  private getConfidenceText(confidence: 'high' | 'medium' | 'low'): string {
    switch (confidence) {
      case 'high': return '高置信度';
      case 'medium': return '中等置信度';
      case 'low': return '低置信度';
      default: return '未知';
    }
  }

  /**
   * 获取图表类型名称
   */
  private getChartTypeName(type: string): string {
    const names: Record<string, string> = {
      'bar': '柱状图',
      'line': '折线图',
      'pie': '饼图',
      'scatter': '散点图'
    };
    return names[type] || type;
  }

  /**
   * 生成并显示图表（使用工厂模式）
   */
  private async generateChart(): Promise<void> {
    if (!this.localChartData || !this.selectedChartType) {
      console.error('[SmartChartSelectorPage] 数据或图表类型未选择');
      return;
    }

    try {
      this.isLoading = true;
      console.info('[SmartChartSelectorPage] 开始生成图表:', this.selectedChartType);

      // 使用工厂模式生成图表配置
      const chartConfig = ChartConfigFactory.createChartConfig(
        this.selectedChartType as ChartType,
        this.localChartData,
        {
          theme: this.selectedTheme,
          animation: this.enableAnimation,
          dataLabels: this.showDataLabels,
          title: this.customTitle || undefined,
          subtitle: this.customSubtitle || undefined
        }
      );

      // 生成ECharts配置
      const eChartsConfig = chartConfig.generateConfig();

      // 构建图表数据包
      const chartData = {
        ...this.localChartData,
        eChartsConfig: eChartsConfig,
        chartType: this.selectedChartType,
        theme: this.selectedTheme.name
      };

      console.info('[SmartChartSelectorPage] 工厂模式图表配置生成完成');

      // 跳转到图表显示页面
      await router.pushUrl({
        url: 'pages/LocalChartPage',
        params: {
          'chartData': JSON.stringify(chartData)
        }
      });

    } catch (error) {
      console.error('[SmartChartSelectorPage] 图表生成失败:', error);
      // 提供友好的错误提示
      console.error('[SmartChartSelectorPage] 错误详情:', error instanceof Error ? error.message : String(error));
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Scroll() {
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
            router.back();
          })

          Blank()

          Text('智能图表选择')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Blank()
            .width(40)
        }
        .width('100%')
        .height(56)
        .padding({ left: 15, right: 15 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#1C1C1C')

        // 数据预览卡片
        if (this.parsedData) {
          Column() {
            Row() {
              Text('数据预览')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
              Text(`${this.parsedData.rowCount} 行 × ${this.parsedData.columnCount} 列`)
                .fontSize(14)
                .fontColor(Color.Gray)
            }
            .width('100%')
            .margin({ bottom: 15 })

            // 表格预览
            Column() {
              // 表头
              Row() {
                ForEach(this.parsedData.headers.slice(0, 4), (header: string) => {
                  Text(header)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                })
              }
              .width('100%')
              .padding({ vertical: 8 })
              .backgroundColor('#252525')
              .borderRadius({ topLeft: 8, topRight: 8 })

              // 数据行（只显示前3行）
              ForEach(this.parsedData.data.slice(0, 3), (row: Record<string, Object>) => {
                Row() {
                  ForEach(this.parsedData!.headers.slice(0, 4), (header: string) => {
                    Text(String(row[header]))
                      .fontSize(11)
                      .fontColor(Color.White)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  })
                }
                .width('100%')
                .padding({ vertical: 6 })
                .backgroundColor('#2A2A2A')
              })

              if (this.parsedData.data.length > 3) {
                Row() {
                  Text(`... 还有 ${this.parsedData.data.length - 3} 行数据`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
                .width('100%')
                .padding({ vertical: 6 })
                .backgroundColor('#2A2A2A')
                .borderRadius({ bottomLeft: 8, bottomRight: 8 })
              }
            }
            .width('100%')
          }
          .width('90%')
          .padding(20)
          .backgroundColor('#252525')
          .borderRadius(15)
          .margin({ top: 20, bottom: 20 })
        }

        // AI推荐结果
        Column() {
          Row() {
            Text('🤖 AI智能推荐')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Blank()
            Text(`基于数据特征分析`)
              .fontSize(12)
              .fontColor(Color.Gray)
          }
          .width('100%')
          .margin({ bottom: 15 })

          // 推荐列表
          ForEach(this.recommendations, (recommendation: ChartRecommendation, index: number) => {
            Column() {
              Row() {
                // 图表类型选择
                Row() {
                  Radio({ value: recommendation.type, group: 'chartType' })
                    .checked(this.selectedChartType === recommendation.type)
                    .onChange(() => {
                      this.selectedChartType = recommendation.type;
                    })
                    .margin({ right: 10 })

                  Text(this.getChartTypeName(recommendation.type))
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }

                Blank()

                // 置信度标签
                Row() {
                  Text(this.getConfidenceText(recommendation.confidence))
                    .fontSize(12)
                    .fontColor(this.getConfidenceColor(recommendation.confidence))
                    .margin({ right: 5 })

                  Circle({ width: 8, height: 8 })
                    .fill(this.getConfidenceColor(recommendation.confidence))
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ bottom: 8 })

              // 推荐理由
              Text(recommendation.reason)
                .fontSize(14)
                .fontColor('#CCCCCC')
                .width('100%')
                .margin({ bottom: 8 })

              // 评分条
              Row() {
                Text('匹配度')
                  .fontSize(12)
                  .fontColor(Color.Gray)
                  .margin({ right: 10 })

                Progress({
                  value: recommendation.score * 100,
                  total: 100,
                  type: ProgressType.Linear
                })
                  .width(100)
                  .height(6)
                  .color(this.getConfidenceColor(recommendation.confidence))
                  .backgroundColor('#333333')

                Text(`${Math.round(recommendation.score * 100)}%`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .margin({ left: 10 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(15)
            .backgroundColor(this.selectedChartType === recommendation.type ? '#2A2A2A' : '#1C1C1C')
            .borderRadius(10)
            .border({
              width: 2,
              color: this.selectedChartType === recommendation.type ? '#007DFF' : 'transparent'
            })
            .margin({ bottom: 10 })
            .onClick(() => {
              this.selectedChartType = recommendation.type;
            })
          })
        }
        .width('90%')
        .padding(20)
        .backgroundColor('#252525')
        .borderRadius(15)
        .margin({ bottom: 20 })

        // 高级选项
        Column() {
          Row() {
            Text('高级选项')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Blank()
            Button(this.showAdvancedOptions ? '收起' : '展开')
              .fontSize(14)
              .fontColor('#007DFF')
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.showAdvancedOptions = !this.showAdvancedOptions;
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          if (this.showAdvancedOptions) {
            Column() {
              // 主题选择
              Row() {
                Text('主题配色')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .width(80)

                Row() {
                  Button('深色')
                    .fontSize(12)
                    .backgroundColor(this.selectedTheme.name === 'dark' ? '#007DFF' : '#333333')
                    .fontColor(Color.White)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectedTheme = new ChartTheme('dark');
                    })

                  Button('浅色')
                    .fontSize(12)
                    .backgroundColor(this.selectedTheme.name === 'light' ? '#007DFF' : '#333333')
                    .fontColor(Color.White)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.selectedTheme = new ChartTheme('light');
                    })

                  Button('蓝色')
                    .fontSize(12)
                    .backgroundColor(this.selectedTheme.name === 'blue' ? '#007DFF' : '#333333')
                    .fontColor(Color.White)
                    .onClick(() => {
                      this.selectedTheme = new ChartTheme('blue');
                    })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .margin({ bottom: 15 })

              // 动画选项
              Row() {
                Text('动画效果')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .width(80)

                Toggle({ type: ToggleType.Switch, isOn: this.enableAnimation })
                  .onChange((isOn: boolean) => {
                    this.enableAnimation = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 15 })

              // 数据标签
              Row() {
                Text('显示数据标签')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .width(80)

                Toggle({ type: ToggleType.Switch, isOn: this.showDataLabels })
                  .onChange((isOn: boolean) => {
                    this.showDataLabels = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 15 })

              // 自定义标题
              Column() {
                Text('图表标题')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })

                TextInput({ placeholder: '输入自定义标题...', text: this.customTitle })
                  .onChange((value: string) => {
                    this.customTitle = value;
                  })
                  .width('100%')
                  .height(40)
                  .backgroundColor('#333333')
                  .fontColor(Color.White)
                  .placeholderColor(Color.Gray)
                  .borderRadius(8)
              }
              .width('100%')
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#1C1C1C')
            .borderRadius(8)
          }
        }
        .width('90%')
        .padding(20)
        .backgroundColor('#252525')
        .borderRadius(15)
        .margin({ bottom: 30 })

        // 生成按钮
        Button(this.isLoading ? '生成中...' : '生成图表')
          .width('90%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .borderRadius(25)
          .enabled(!this.isLoading && this.selectedChartType !== '')
          .onClick(() => {
            this.generateChart();
          })

        // 底部间距
        Column()
          .height(100)
      }
      .width('100%')
      .padding({ left: 15, right: 15, bottom: 20 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .backgroundColor('#1C1C1C')
    .height('100%')

    // 加载状态提示
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ bottom: 10 })
        Text('正在智能生成图表配置...')
          .fontSize(14)
          .fontColor(Color.Gray)
      }
      .width('100%')
      .padding(20)
      .backgroundColor('rgba(28, 28, 28, 0.9)')
    }
  }
}