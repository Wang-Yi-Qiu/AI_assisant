/**
 * 图表类型选择页面
 * 支持多种图表类型的选择和预览
 * @module ChartTypeSelectorPage
 */

import router from '@ohos.router';
import { getOriginalData, setChartOption } from './ChartPage';
import { generateChart, ChartConfig, UserData, CSVData } from '../utils/aiService';

// 辅助函数：安全地访问UserData的data属性
function getDataFromUserData(userData: UserData): object[] | null {
  if (typeof userData === 'object' && userData !== null) {
    const csvData = userData as CSVData;
    return csvData.data || null;
  }
  return null;
}

// 图表类型定义
export interface ChartType {
  id: string;
  name: string;
  description: string;
  icon: string;
  example: string;
  supported: boolean;
}

@Entry
@Component
export struct ChartTypeSelectorPage {
  @State chartTypes: ChartType[] = [];
  @State selectedType: string = '';
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    console.info('[ChartTypeSelectorPage] 页面初始化');
    this.initializeChartTypes();
  }

  /**
   * 初始化图表类型列表
   */
  initializeChartTypes(): void {
    this.chartTypes = [
      {
        id: 'bar',
        name: '柱状图',
        description: '适合比较不同类别的数值大小',
        icon: '📊',
        example: '月度销售额对比',
        supported: true
      },
      {
        id: 'line',
        name: '折线图',
        description: '适合展示数据随时间的变化趋势',
        icon: '📈',
        example: '股票价格走势',
        supported: true
      },
      {
        id: 'pie',
        name: '饼图',
        description: '适合展示数据的占比关系',
        icon: '🥧',
        example: '市场份额分布',
        supported: true
      },
      {
        id: 'scatter',
        name: '散点图',
        description: '适合展示两个变量之间的关系',
        icon: '⚡',
        example: '身高体重关系',
        supported: true
      },
      {
        id: 'area',
        name: '面积图',
        description: '适合展示数据的累积变化',
        icon: '📉',
        example: '用户增长趋势',
        supported: true
      },
      {
        id: 'radar',
        name: '雷达图',
        description: '适合多维度数据的对比分析',
        icon: '🎯',
        example: '产品能力评估',
        supported: true
      }
    ];
    console.info('[ChartTypeSelectorPage] 图表类型初始化完成，共', this.chartTypes.length, '种');
  }

  /**
   * 选择图表类型
   */
  selectChartType(chartType: ChartType): void {
    if (!chartType.supported) {
      console.warn('[ChartTypeSelectorPage] 图表类型不支持:', chartType.id);
      return;
    }

    this.selectedType = chartType.id;
    console.info('[ChartTypeSelectorPage] 选择图表类型:', chartType.id, chartType.name);
  }

  /**
   * 确认选择并生成图表
   */
  async confirmSelection(): Promise<void> {
    if (!this.selectedType || this.isLoading) {
      return;
    }

    try {
      console.info('[ChartTypeSelectorPage] ========== 开始生成', this.selectedType, '图表 ==========');

      // 检查是否有原始数据
      const originalData = getOriginalData();
      if (!originalData) {
        throw new Error('没有原始数据用于生成图表');
      }
      const dataRows = getDataFromUserData(originalData);
      if (!dataRows || dataRows.length === 0) {
        throw new Error('没有原始数据用于生成图表');
      }

      console.info('[ChartTypeSelectorPage] 使用数据生成', this.selectedType, '图表');

      this.isLoading = true;

      // 构建包含图表类型的用户数据
      const newUserData: Record<string, object> = {};
      if (typeof originalData === 'object' && originalData !== null) {
        // 手动复制属性
        const keys = Object.keys(originalData);
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i];
          const value = (originalData as Record<string, object>)[key];
          if (value !== undefined) {
            newUserData[key] = value;
          }
        }
      }
      newUserData.chartType = this.selectedType;
      const userData: UserData = newUserData;

      // 调用AI服务生成图表配置
      const chartConfig: ChartConfig = await generateChart(userData);
      console.info('[ChartTypeSelectorPage] 图表配置生成成功');

      // 设置图表配置
      setChartOption(chartConfig, userData);
      console.info('[ChartTypeSelectorPage] 图表配置已设置，准备跳转');

      // 跳转到图表页面
      await router.pushUrl({
        url: 'pages/ChartPage'
      });

      console.info('[ChartTypeSelectorPage] 已跳转到图表页面');

    } catch (error) {
      console.error('[ChartTypeSelectorPage] 生成图表失败:', error);

      // 显示错误提示
      // 这里可以添加Toast或Dialog显示错误信息
      console.error('生成失败:', error instanceof Error ? error.message : '未知错误');

    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 返回上一页
   */
  goBack(): void {
    router.back();
  }

  /**
   * 构建图表类型卡片
   */
  @Builder
  ChartTypeCard(chartType: ChartType): void {
    Column() {
      // 图标
      Text(chartType.icon)
        .fontSize(40)
        .margin({ bottom: 12 })

      // 名称
      Text(chartType.name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 6 })

      // 描述
      Text(chartType.description)
        .fontSize(12)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 8 })

      // 示例
      Text(chartType.example)
        .fontSize(10)
        .fontColor('#666666')
        .fontStyle(FontStyle.Italic)

      // 支持状态
      if (!chartType.supported) {
        Text('开发中')
          .fontSize(10)
          .fontColor('#FFA500')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(15)
    .backgroundColor(this.selectedType === chartType.id ? '#007DFF' : '#252525')
    .borderRadius(12)
    .border({
      width: 2,
      color: this.selectedType === chartType.id ? '#007DFF' : '#333333'
    })
    .onClick(() => {
      this.selectChartType(chartType);
    })
  }

  build() {
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

        Text('选择图表类型')
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

      // 主要内容区域
      Scroll() {
        Column() {
          // 说明文字
          Text('选择最适合您数据的图表类型')
            .fontSize(16)
            .fontColor(Color.White)
            .margin({ top: 20, bottom: 10 })
            .textAlign(TextAlign.Center)

          Text('系统将根据您的选择和数据特点智能生成图表')
            .fontSize(12)
            .fontColor(Color.Gray)
            .margin({ bottom: 30 })
            .textAlign(TextAlign.Center)

          // 图表类型网格
          Grid() {
            ForEach(this.chartTypes, (chartType: ChartType, index?: number) => {
              GridItem() {
                this.ChartTypeCard(chartType)
              }
            }, (chartType: ChartType, index?: number) => chartType.id)
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr')
          .columnsGap(15)
          .rowsGap(15)
          .width('90%')
          .height(400)

          // 确认按钮
          Button(this.selectedType ? '生成图表' : '请选择图表类型')
            .width('80%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(this.selectedType ? '#007DFF' : '#666666')
            .fontColor(Color.White)
            .borderRadius(25)
            .enabled(this.selectedType !== '' && !this.isLoading)
            .margin({ top: 40, bottom: 30 })
            .onClick(() => {
              this.confirmSelection();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 20, bottom: 20 })
      }
      .layoutWeight(1)
      .width('100%')

      // 加载状态提示
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .margin({ bottom: 10 })
          Text('正在生成图表...')
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