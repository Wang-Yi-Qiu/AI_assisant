/**
 * 数据输入页面
 * 支持表格形式的手动数据输入
 * @module DataInputPage
 */

import router from '@ohos.router';
import { generateChartLocal, ChartConfig, UserData, CSVData } from '../utils/aiService';
import { setChartOption } from './ChartPage';
import { ErrorHandler } from '../utils/errorHandler';

// 定义表格数据行类型（使用Map替代索引签名）
type TableRow = Map<string, string>;

@Entry
@Component
export struct DataInputPage {
  @State isLoading: boolean = false;
  @State loadingMessage: string = '正在生成图表...';
  @State tableData: TableRow[] = [];
  @State headers: string[] = ['类别 (X轴)', '数值 (Y轴)', '备注']; // 默认表头 - 更具语义和引导性
  @State rowCount: number = 3;
  @State columnCount: number = 3;

  aboutToAppear(): void {
    console.info('[DataInputPage] 页面初始化');
    this.initializeTable();
  }

  /**
   * 初始化表格
   */
  initializeTable(): void {
    this.tableData = [];
    for (let i = 0; i < this.rowCount; i++) {
      const row: TableRow = new Map<string, string>();
      for (let j = 0; j < this.columnCount; j++) {
        row.set(this.headers[j], '');
      }
      this.tableData.push(row);
    }
    console.info('[DataInputPage] 表格初始化完成，行数:', this.rowCount, '列数:', this.columnCount);
  }

  /**
   * 添加新行
   */
  addRow(): void {
    const newRow: Map<string, string> = new Map<string, string>();
    for (let j = 0; j < this.columnCount; j++) {
      newRow.set(this.headers[j], '');
    }
    this.tableData.push(newRow);
    this.rowCount++;
    console.info('[DataInputPage] 添加新行，当前行数:', this.rowCount);
  }

  /**
   * 删除行
   */
  removeRow(index: number): void {
    if (this.tableData.length > 1) {
      this.tableData.splice(index, 1);
      this.rowCount--;
      console.info('[DataInputPage] 删除第', index + 1, '行');
    }
  }

  /**
   * 添加新列
   */
  addColumn(): void {
    const newColumnName = `字段${this.columnCount + 1}`;
    this.headers.push(newColumnName);
    this.columnCount++;

    // 为现有行添加新列
    this.tableData.forEach(row => {
      row.set(newColumnName, '');
    });

    console.info('[DataInputPage] 添加新列:', newColumnName);
  }

  /**
   * 删除列
   */
  removeColumn(index: number): void {
    if (this.headers.length > 1) {
      const columnName = this.headers[index];
      this.headers.splice(index, 1);
      this.columnCount--;

      // 从所有行中删除该列
      this.tableData.forEach(row => {
        row.delete(columnName);
      });

      console.info('[DataInputPage] 删除列:', columnName);
    }
  }

  /**
   * 更新单元格数据
   */
  updateCell(rowIndex: number, columnName: string, value: string): void {
    if (this.tableData[rowIndex]) {
      this.tableData[rowIndex].set(columnName, value);
    }
  }

  /**
   * 更新表头
   */
  updateHeader(index: number, value: string): void {
    if (this.headers[index]) {
      const oldName = this.headers[index];
      this.headers[index] = value;

      // 更新所有行中的键名
      this.tableData.forEach(row => {
        if (row.has(oldName)) {
          const oldValue = row.get(oldName);
          if (oldValue !== undefined) {
            row.set(value, oldValue);
          }
          row.delete(oldName);
        }
      });
    }
  }

  /**
   * 生成图表
   */
  async generateChartFromData(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    try {
      console.info('[DataInputPage] ========== 开始生成图表 ==========');
      this.isLoading = true;
      this.loadingMessage = '正在验证数据...';

      // 验证数据
      const userData = this.validateAndPrepareData();

      if (!userData) {
        throw new Error('没有有效的数据行，请填写数据后再生成图表');
      }

      this.loadingMessage = '正在生成本地图表...';

      // 使用本地服务生成图表（无需API调用）
      const chartConfig: ChartConfig = await generateChartLocal(userData);
      console.info('[DataInputPage] 图表配置生成成功');

      // 设置图表配置并跳转
      setChartOption(chartConfig, userData);
      console.info('[DataInputPage] 图表配置已设置，准备跳转');

      // 跳转到图表页面
      await router.pushUrl({
        url: 'pages/ChartPage'
      });

      console.info('[DataInputPage] 已跳转到图表页面');

    } catch (error) {
      console.error('[DataInputPage] 生成图表失败:', error);
      const appError = ErrorHandler.handle(error, 'generateChartFromData');

      // 显示错误提示
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
   * 验证并准备数据
   */
  validateAndPrepareData(): UserData | null {
    try {
      console.info('[DataInputPage] 开始验证和准备数据');
      console.info('[DataInputPage] 原始数据行数:', this.tableData.length);
      console.info('[DataInputPage] 表头:', this.headers);

      // 过滤有效行（至少有一个非空字段）
      const validRows: Map<string, string>[] = this.tableData.filter(row => {
        let hasValidValue = false;
        row.forEach((value) => {
          if (value && value.trim() !== '') {
            hasValidValue = true;
          }
        });
        return hasValidValue;
      });

      console.info('[DataInputPage] 有效数据行数:', validRows.length);

      if (validRows.length === 0) {
        return null;
      }

      // 转换数据格式，自动识别数字
      const processedData: Record<string, string | number>[] = validRows.map(row => {
        const processedRow: Record<string, string | number> = {};
        this.headers.forEach(header => {
          const value = row.get(header);
          if (value && value.trim() !== '') {
            // 尝试转换为数字
            const numValue = Number(value);
            processedRow[header] = isNaN(numValue) ? value.trim() : numValue;
          }
        });
        return processedRow;
      });

      console.info('[DataInputPage] 数据处理完成');
      return { data: processedData };

    } catch (error) {
      console.error('[DataInputPage] 数据验证失败:', error);
      throw new Error(`数据验证失败: ${error}`);
    }
  }

  /**
   * 返回上一页
   */
  goBack(): void {
    router.back();
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

        Text('手动输入数据')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)

        Blank()
          .width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#121826')

      // 主要内容区域
      Scroll() {
        Column() {
          // 操作提示 - AI功能引导
          Text('输入数据让AI为您智能生成精美图表')
            .fontSize(14)
            .fontWeight(FontWeight.Normal)
            .fontColor('#AAAAAA')
            .margin({ top: 12, bottom: 16 })
            .textAlign(TextAlign.Start)
            .width('90%')

          // 表格操作按钮
          Row() {
            Button('+ 添加行')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#0095FF')
              .fontColor(Color.White)
              .borderRadius(8)
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.addRow();
              })

            Button('+ 添加列')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#1E2430')
              .fontColor(Color.White)
              .borderRadius(8)
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .margin({ left: 12 })
              .onClick(() => {
                this.addColumn();
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.Start)
          .margin({ bottom: 20 })

          // 数据表格
          Column() {
            // 表头 - 带有类型图标的语义化表头
            Row() {
              ForEach(this.headers, (header: string, index?: number) => {
                Row() {
                  // 类型图标
                  if (index === 0) {
                    Text('Aa')
                      .fontSize(12)
                      .fontColor('#AAAAAA')
                      .fontWeight(FontWeight.Bold)
                      .margin({ right: 6 })
                  } else if (index === 1) {
                    Text('#')
                      .fontSize(14)
                      .fontColor('#AAAAAA')
                      .fontWeight(FontWeight.Bold)
                      .margin({ right: 6 })
                  } else {
                    Text('📝')
                      .fontSize(12)
                      .margin({ right: 6 })
                  }

                  // 表头文字
                  Text(header)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                }
                .width('33%')
                .height(40)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ right: 8 })
              }, (header: string, index?: number) => (index ?? 0).toString())
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ bottom: 16 })

            // 数据行 - 智能输入行为
            ForEach(this.tableData, (row: Map<string, string>, rowIndex?: number) => {
              Row() {
                // 第一列：类别输入
                TextInput({
                  text: row.get(this.headers[0]) || '',
                  placeholder: rowIndex === 0 ? '如：苹果' : '输入类别'
                })
                  .width('33%')
                  .height(40)
                  .fontSize(14)
                  .backgroundColor('#1E2430')
                  .fontColor(Color.White)
                  .placeholderColor('#AAAAAA')
                  .margin({ right: 8 })
                  .borderRadius(6)
                  .padding({ left: 12, right: 12 })
                  .type(InputType.Normal)
                  .onChange((value: string) => {
                    this.updateCell(rowIndex as number, this.headers[0], value);
                  })

                // 第二列：数值输入
                TextInput({
                  text: row.get(this.headers[1]) || '',
                  placeholder: rowIndex === 0 ? '如：50' : '输入数值'
                })
                  .width('33%')
                  .height(40)
                  .fontSize(14)
                  .backgroundColor('#1E2430')
                  .fontColor(Color.White)
                  .placeholderColor('#AAAAAA')
                  .margin({ right: 8 })
                  .borderRadius(6)
                  .padding({ left: 12, right: 12 })
                  .type(InputType.Number)
                  .onChange((value: string) => {
                    this.updateCell(rowIndex as number, this.headers[1], value);
                  })

                // 第三列：备注输入
                TextInput({
                  text: row.get(this.headers[2]) || '',
                  placeholder: rowIndex === 0 ? '可选备注' : '备注信息'
                })
                  .width('33%')
                  .height(40)
                  .fontSize(14)
                  .backgroundColor('#1E2430')
                  .fontColor(Color.White)
                  .placeholderColor('#AAAAAA')
                  .borderRadius(6)
                  .padding({ left: 12, right: 12 })
                  .type(InputType.Normal)
                  .onChange((value: string) => {
                    this.updateCell(rowIndex as number, this.headers[2], value);
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ bottom: 8 })
            }, (row: Map<string, string>, rowIndex?: number) => (rowIndex ?? 0).toString())
          }
          .width('90%')
          .padding(16)
          .backgroundColor('transparent')
          .margin({ bottom: 24 })

          // AI 生成按钮 - 带渐变色和科技感
          Button() {
            Row() {
              Text('✨')
                .fontSize(18)
                .margin({ right: 8 })
              Text('AI 生成图表')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
            .width('90%')
            .height(50)
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [['#0095FF', 0.0], ['#7B3FF2', 1.0]]
            })
            .borderRadius(12)
            .enabled(!this.isLoading && this.tableData.length > 0)
            .onClick(() => {
              this.generateChartFromData();
            })
            .margin({ top: 32, bottom: 20 })
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
          Text(this.loadingMessage)
            .fontSize(14)
            .fontColor('#AAAAAA')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#121826')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121826')
  }
}