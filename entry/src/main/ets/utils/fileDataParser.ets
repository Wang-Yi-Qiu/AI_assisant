/**
 * 文件数据解析工具
 * 支持 CSV 和 Excel 文件的本地解析
 */

import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

// 解析结果接口
export interface ParsedData {
  headers: string[];
  data: object[];
  fileName: string;
  fileType: 'csv' | 'excel';
  rowCount: number;
  columnCount: number;
}

// 验证结果接口
export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

// 解析错误类
export class ParseError extends Error {
  public code: string;

  constructor(message: string, code: string = 'PARSE_ERROR') {
    super(message);
    this.name = 'ParseError';
    this.code = code;
  }
}

/**
 * 文件数据解析器类
 */
export class FileDataParser {
  private static instance: FileDataParser;

  constructor() {
  }

  public static getInstance(): FileDataParser {
    if (!FileDataParser.instance) {
      FileDataParser.instance = new FileDataParser();
    }
    return FileDataParser.instance;
  }

  /**
   * 选择并解析文件
   */
  public async selectAndParseFile(): Promise<ParsedData> {
    try {
      // 选择文件
      const fileUri = await this.selectFile();
      if (!fileUri) {
        throw new ParseError('未选择文件', 'NO_FILE_SELECTED');
      }

      // 解析文件
      const parsedData = await this.parseFile(fileUri);
      return parsedData;
    } catch (error) {
      console.error('[FileDataParser] 文件选择和解析失败:', error);
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 选择文件
   */
  private async selectFile(): Promise<string | null> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      // 支持的文件类型
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.defaultFilePathUri = 'file://docs';

      const documentViewPicker = new picker.DocumentViewPicker();
      const documentSelectResult = await documentViewPicker.select(documentSelectOptions);

      if (documentSelectResult.length > 0) {
        return documentSelectResult[0];
      }
      return null;
    } catch (error) {
      console.error('[FileDataParser] 文件选择失败:', error);
      throw new ParseError('文件选择失败: ' + (error as Error).message, 'FILE_SELECT_ERROR');
    }
  }

  /**
   * 解析文件
   */
  private async parseFile(fileUri: string): Promise<ParsedData> {
    try {
      // 读取文件内容
      const fileContent = await this.readFileContent(fileUri);

      // 获取文件名和类型
      const fileName = this.extractFileName(fileUri);
      const fileType = this.detectFileType(fileName);

      // 根据文件类型解析
      let parsedData: ParsedData;
      switch (fileType) {
        case 'csv':
          parsedData = this.parseCSV(fileContent, fileName);
          break;
        case 'excel':
          parsedData = await this.parseExcel(fileUri, fileName);
          break;
        default:
          throw new ParseError('不支持的文件类型', 'UNSUPPORTED_FILE_TYPE');
      }

      console.info(`[FileDataParser] 成功解析文件: ${fileName}, 行数: ${parsedData.rowCount}, 列数: ${parsedData.columnCount}`);
      return parsedData;
    } catch (error) {
      console.error('[FileDataParser] 文件解析失败:', error);
      throw error instanceof Error ? error : new Error(String(error));
    }
  }

  /**
   * 读取文件内容
   */
  private async readFileContent(fileUri: string): Promise<string> {
    try {
      const file = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);

      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);

      fs.closeSync(file);

      // 尝试不同的编码方式
      const decoder = new util.TextDecoder('utf-8', { fatal: false });
      // 将ArrayBuffer转换为Uint8Array
      const uint8Array = new Uint8Array(buffer);
      return decoder.decodeWithStream(uint8Array);
    } catch (error) {
      console.error('[FileDataParser] 读取文件内容失败:', error);
      throw new ParseError('读取文件失败: ' + (error as Error).message, 'FILE_READ_ERROR');
    }
  }

  /**
   * 解析CSV文件
   */
  private parseCSV(content: string, fileName: string): ParsedData {
    try {
      const lines = content.split('\n').filter(line => line.trim());

      if (lines.length === 0) {
        throw new ParseError('CSV文件为空', 'EMPTY_CSV');
      }

      // 解析表头
      const headers = this.parseCSVLine(lines[0]);

      // 解析数据行
      const data: object[] = [];
      for (let i = 1; i < lines.length; i++) {
        const values = this.parseCSVLine(lines[i]);

        // 如果行数据不为空
        if (values.some(val => val.trim() !== '')) {
          const row: Record<string, Object> = {};
          headers.forEach((header, index) => {
            let value = values[index] || '';

            // 尝试转换为数字
            const numValue = parseFloat(value);
            if (!isNaN(numValue) && isFinite(numValue)) {
              row[header] = numValue;
            } else {
              row[header] = value;
            }
          });
          data.push(row);
        }
      }

      return {
        headers,
        data,
        fileName,
        fileType: 'csv',
        rowCount: data.length,
        columnCount: headers.length
      };
    } catch (error) {
      console.error('[FileDataParser] CSV解析失败:', error);
      throw new ParseError('CSV解析失败: ' + (error as Error).message, 'CSV_PARSE_ERROR');
    }
  }

  /**
   * 解析CSV行
   */
  private parseCSVLine(line: string): string[] {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;
    let i = 0;

    while (i < line.length) {
      const char = line[i];
      const nextChar = line[i + 1];

      if (char === '"') {
        if (inQuotes && nextChar === '"') {
          // 转义的引号
          current += '"';
          i += 2;
        } else {
          // 开始或结束引号
          inQuotes = !inQuotes;
          i++;
        }
      } else if (char === ',' && !inQuotes) {
        // 字段分隔符
        result.push(current.trim());
        current = '';
        i++;
      } else {
        current += char;
        i++;
      }
    }

    // 添加最后一个字段
    result.push(current.trim());

    return result;
  }

  /**
   * 解析Excel文件（简化版本）
   * 注意：这是一个基础实现，完整的Excel解析需要第三方库
   */
  private async parseExcel(fileUri: string, fileName: string): Promise<ParsedData> {
    try {
      // 这里使用简化的CSV格式作为Excel解析的占位符
      // 在实际项目中，您需要集成 xlsx.js 或其他Excel解析库

      console.warn('[FileDataParser] Excel解析功能需要第三方库支持，当前使用CSV解析作为替代');

      // 暂时按CSV格式解析
      const content = await this.readFileContent(fileUri);
      return this.parseCSV(content, fileName);
    } catch (error) {
      console.error('[FileDataParser] Excel解析失败:', error);
      throw new ParseError('Excel解析失败: ' + (error as Error).message, 'EXCEL_PARSE_ERROR');
    }
  }

  /**
   * 提取文件名
   */
  private extractFileName(fileUri: string): string {
    const lastSlash = fileUri.lastIndexOf('/');
    const lastQuestion = fileUri.lastIndexOf('?');

    let fileName = fileUri.substring(lastSlash + 1);
    if (lastQuestion > -1) {
      fileName = fileName.substring(0, lastQuestion);
    }

    return decodeURIComponent(fileName);
  }

  /**
   * 检测文件类型
   */
  private detectFileType(fileName: string): 'csv' | 'excel' {
    const extension = fileName.toLowerCase().split('.').pop();

    switch (extension) {
      case 'csv':
        return 'csv';
      case 'xlsx':
      case 'xls':
        return 'excel';
      default:
        throw new ParseError(`不支持的文件类型: ${extension}`, 'UNSUPPORTED_FILE_TYPE');
    }
  }

  /**
   * 验证解析结果
   */
  public validateParsedData(parsedData: ParsedData): ValidationResult {
    const errors: string[] = [];

    // 检查是否有数据
    if (parsedData.data.length === 0) {
      errors.push('文件中没有有效数据');
    }

    // 检查是否有表头
    if (parsedData.headers.length === 0) {
      errors.push('文件中没有表头信息');
    }

    // 检查数据一致性
    if (parsedData.data.length > 0) {
      const expectedColumnCount = parsedData.headers.length;
      const inconsistentRows = parsedData.data.filter(row => {
        return Object.keys(row).length !== expectedColumnCount;
      });

      if (inconsistentRows.length > 0) {
        errors.push(`发现 ${inconsistentRows.length} 行数据列数与表头不匹配`);
      }
    }

    const result: ValidationResult = {
      isValid: errors.length === 0,
      errors
    };
    return result;
  }

  /**
   * 获取数据预览
   */
  public getDataPreview(parsedData: ParsedData, maxRows: number = 5): ParsedData {
    return {
      headers: parsedData.headers,
      data: parsedData.data.slice(0, maxRows),
      fileName: parsedData.fileName,
      fileType: parsedData.fileType,
      rowCount: Math.min(parsedData.rowCount, maxRows),
      columnCount: parsedData.columnCount
    };
  }
}

// 导出单例实例
export const fileDataParser = FileDataParser.getInstance();