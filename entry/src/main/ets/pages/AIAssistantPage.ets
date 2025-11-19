import router from '@ohos.router';
import { LocalChartService, LocalChartData, ExportFormat } from '../utils/localChartService';
import { ErrorHandler } from '../utils/errorHandler';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
export struct AIAssistantPage {
  @State isLoading: boolean = false;
  @State loadingMessage: string = '正在加载...';
  private localChartService: LocalChartService = LocalChartService.getInstance();

  aboutToAppear() {
    console.info('[AIAssistantPage] 页面初始化');
  }

  /**
   * 使用示例数据生成图表
   */
  async handleUseSampleData(dataType: 'sales' | 'weather' | 'students') {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.loadingMessage = '正在生成示例数据...';

    try {
      console.info('[AIAssistantPage] 开始生成示例数据:', dataType);

      // 生成示例数据
      const chartData = this.localChartService.generateSampleData(dataType);
      console.info('[AIAssistantPage] 示例数据生成完成');

      // 跳转到智能图表选择页面
      await router.pushUrl({
        url: 'pages/SmartChartSelectorPage',
        params: {
          'parsedData': {
            fileName: 'sample_data.csv',
            headers: chartData.headers,
            data: chartData.rows.map(row => {
              const obj: Record<string, Object> = {};
              chartData.headers.forEach((header, index) => {
                obj[header] = row[index];
              });
              return obj;
            }),
            rowCount: chartData.rows.length,
            columnCount: chartData.headers.length
          }
        }
      });

      console.info('[AIAssistantPage] 已跳转到本地图表页面');
    } catch (error) {
      console.error('[AIAssistantPage] 生成示例数据失败:', error);
      this.loadingMessage = `生成失败: ${error}`;

      setTimeout(() => {
        this.loadingMessage = '正在加载...';
      }, 3000);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 打开文件选择器并处理CSV文件
   */
  async handleFileUpload(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.loadingMessage = '正在选择文件...';

    try {
      console.info('[AIAssistantPage] 开始文件上传');

      // 使用本地服务解析CSV
      const chartData = await this.localChartService.selectAndParseCSV();

      if (chartData) {
        console.info('[AIAssistantPage] CSV解析成功');

        // 跳转到智能图表选择页面
        await router.pushUrl({
          url: 'pages/SmartChartSelectorPage',
          params: {
            'parsedData': {
              fileName: chartData.fileName,
              headers: chartData.headers,
              data: chartData.data,
              rowCount: chartData.data.length,
              columnCount: chartData.headers.length
            }
          }
        });

        console.info('[AIAssistantPage] 已跳转到本地图表页面');
      } else {
        throw new Error('CSV文件解析失败');
      }
    } catch (error) {
      console.error('[AIAssistantPage] 文件上传失败:', error);
      this.loadingMessage = `上传失败: ${error}`;

      setTimeout(() => {
        this.loadingMessage = '正在加载...';
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
            this.ActionButton('📄', '上传数据', true, async () => {
              console.info('点击上传数据');
              await this.handleFileUpload();
            })

            // 手动输入按钮（深色背景，亮色边框）
            this.ActionButton('✍️', '手动输入', false, () => {
              console.info('点击手动输入');
              router.pushUrl({
                url: 'pages/DataInputPage'
              }).catch((err: BusinessError) => {
                console.error('跳转到数据输入页面失败:', err);
              });
            })
          }
          .width('100%')
          .margin({ bottom: 30 })

          // 示例数据区域
          Column() {
            Row() {
              Text('示例数据')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Blank()
            }
            .width('100%')
            .margin({ bottom: 15 })

            // 示例数据卡片
            Column() {
              Row() {
                Button('📈 销售数据')
                  .width('48%')
                  .height(80)
                  .backgroundColor('#252525')
                  .fontColor(Color.White)
                  .fontSize(14)
                  .margin({ right: '4%' })
                  .onClick(() => {
                    this.handleUseSampleData('sales');
                  })

                Button('🌤️ 天气数据')
                  .width('48%')
                  .height(80)
                  .backgroundColor('#252525')
                  .fontColor(Color.White)
                  .fontSize(14)
                  .onClick(() => {
                    this.handleUseSampleData('weather');
                  })
              }
              .width('100%')
              .margin({ bottom: 12 })

              Button('👨‍🎓 学生成绩')
                .width('100%')
                .height(80)
                .backgroundColor('#252525')
                .fontColor(Color.White)
                .fontSize(14)
                .onClick(() => {
                  this.handleUseSampleData('students');
                })
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#1C1C1C')
            .borderRadius(10)
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

          }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1C1C')
  }
}