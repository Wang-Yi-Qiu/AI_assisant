/**
 * 数据输入页面
 * 支持表格形式的手动数据输入
 * @module DataInputPage
 */

import router from '@ohos.router';
import { generateChart, ChartConfig, UserData } from '../utils/aiService';
import { setChartOption } from './ChartPage';
import { ErrorHandler } from '../utils/errorHandler';

@Entry
@Component
export struct DataInputPage {
  @State isLoading: boolean = false;
  @State loadingMessage: string = '正在生成图表...';
  @State tableData: Array<{ [key: string]: string }> = [];
  @State headers: string[] = ['字段1', '字段2', '字段3']; // 默认表头
  @State rowCount: number = 3;
  @State columnCount: number = 3;

  aboutToAppear() {
    console.info('[DataInputPage] 页面初始化');
    this.initializeTable();
  }

  /**
   * 初始化表格
   */
  initializeTable(): void {
    this.tableData = [];
    for (let i = 0; i < this.rowCount; i++) {
      const row: { [key: string]: string } = {};
      for (let j = 0; j < this.columnCount; j++) {
        row[this.headers[j]] = '';
      }
      this.tableData.push(row);
    }
    console.info('[DataInputPage] 表格初始化完成，行数:', this.rowCount, '列数:', this.columnCount);
  }

  /**
   * 添加新行
   */
  addRow(): void {
    const newRow: { [key: string]: string } = {};
    for (let j = 0; j < this.columnCount; j++) {
      newRow[this.headers[j]] = '';
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
      row[newColumnName] = '';
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
        delete row[columnName];
      });

      console.info('[DataInputPage] 删除列:', columnName);
    }
  }

  /**
   * 更新单元格数据
   */
  updateCell(rowIndex: number, columnName: string, value: string): void {
    if (this.tableData[rowIndex]) {
      this.tableData[rowIndex][columnName] = value;
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
        if (row.hasOwnProperty(oldName)) {
          row[value] = row[oldName];
          delete row[oldName];
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

      if (!userData || userData.data.length === 0) {
        throw new Error('没有有效的数据行，请填写数据后再生成图表');
      }

      this.loadingMessage = '正在调用AI生成图表...';

      // 调用AI服务生成图表
      const chartConfig: ChartConfig = await generateChart(userData);
      console.info('[DataInputPage] 图表配置生成成功');

      // 设置图表配置并跳转
      setChartOption(chartConfig, userData);
      console.info('[DataInputPage] 图表配置已设置，准备跳转');

      // 跳转到图表页面
      await router.pushNamedRoute({
        name: 'ChartPage'
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
  private validateAndPrepareData(): UserData | null {
    try {
      console.info('[DataInputPage] 开始验证和准备数据');
      console.info('[DataInputPage] 原始数据行数:', this.tableData.length);
      console.info('[DataInputPage] 表头:', this.headers);

      // 过滤有效行（至少有一个非空字段）
      const validRows = this.tableData.filter(row => {
        return Object.values(row).some(value => value && value.trim() !== '');
      });

      console.info('[DataInputPage] 有效数据行数:', validRows.length);

      if (validRows.length === 0) {
        return null;
      }

      // 转换数据格式，自动识别数字
      const processedData = validRows.map(row => {
        const processedRow: any = {};
        this.headers.forEach(header => {
          const value = row[header];
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
          // 操作提示
          Text('请输入您的数据，支持数字和文本')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 20, bottom: 10 })
            .textAlign(TextAlign.Center)

          // 表格操作按钮
          Row() {
            Button('添加行')
              .fontSize(14)
              .backgroundColor('#007DFF')
              .fontColor(Color.White)
              .margin({ right: 10 })
              .onClick(() => {
                this.addRow();
              })

            Button('添加列')
              .fontSize(14)
              .backgroundColor('#007DFF')
              .fontColor(Color.White)
              .onClick(() => {
                this.addColumn();
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.Start)
          .margin({ bottom: 20 })

          // 数据表格
          Column() {
            // 表头
            Row() {
              ForEach(this.headers, (header, index) => {
                TextInput({ text: header })
                  .width('120')
                  .height(40)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor('#2D3748')
                  .fontColor(Color.White)
                  .margin({ right: 5 })
                  .onChange((value: string) => {
                    this.updateHeader(index as number, value);
                  })
              }, (header: string, index: number) => index.toString())

              // 删除列按钮
              if (this.headers.length > 1) {
                Button('×')
                  .width(30)
                  .height(30)
                  .fontSize(16)
                  .backgroundColor('#FF4444')
                  .fontColor(Color.White)
                  .margin({ left: 5 })
                  .onClick(() => {
                    this.removeColumn(this.headers.length - 1);
                  })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ bottom: 10 })

            // 数据行
            ForEach(this.tableData, (row, rowIndex) => {
              Row() {
                ForEach(this.headers, (header) => {
                  TextInput({
                    text: row[header] || '',
                    placeholder: '请输入数据'
                  })
                    .width('120')
                    .height(35)
                    .fontSize(12)
                    .backgroundColor('#252525')
                    .fontColor(Color.White)
                    .placeholderColor(Color.Gray)
                    .margin({ right: 5 })
                    .onChange((value: string) => {
                      this.updateCell(rowIndex as number, header, value);
                    })
                }, (header: string) => header)

                // 删除行按钮
                if (this.tableData.length > 1) {
                  Button('×')
                    .width(25)
                    .height(25)
                    .fontSize(12)
                    .backgroundColor('#FF4444')
                    .fontColor(Color.White)
                    .margin({ left: 5 })
                    .onClick(() => {
                      this.removeRow(rowIndex as number);
                    })
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ bottom: 8 })
            }, (row: any, rowIndex: number) => rowIndex.toString())
          }
          .width('90%')
          .padding(15)
          .backgroundColor('#252525')
          .borderRadius(10)
          .margin({ bottom: 30 })

          // 生成按钮
          Button('生成图表')
            .width('80%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#007DFF')
            .fontColor(Color.White)
            .borderRadius(25)
            .enabled(!this.isLoading && this.tableData.length > 0)
            .onClick(() => {
              this.generateChartFromData();
            })
            .margin({ bottom: 20 })
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