/**
 * 文件管理和导出工具
 * @module fileManager
 */

import { ChartConfig } from './aiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker } from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { ErrorHandler, AppError, ErrorCode } from './errorHandler';

export interface ExportOptions {
  filename?: string;
  format?: 'png' | 'pdf' | 'json';
  quality?: number; // 0-1 for PNG
  backgroundColor?: string;
}

export class FileManager {
  private static readonly DEFAULT_FILENAME = 'chart';
  private static readonly MAX_FILENAME_LENGTH = 50;

  /**
   * 导出图表配置为JSON文件
   * @param config 图表配置
   * @param options 导出选项
   */
  static async exportJson(config: ChartConfig, options: ExportOptions = {}): Promise<void> {
    try {
      const filename = this.generateFilename(options.filename, 'json');
      const jsonData = JSON.stringify(config, null, 2);

      await this.saveTextFile(jsonData, filename, 'application/json');
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportJson');
    }
  }

  /**
   * 导出图表为PNG文件
   * @param dataUrl base64编码的图片数据
   * @param options 导出选项
   */
  static async exportPng(dataUrl: string, options: ExportOptions = {}): Promise<void> {
    try {
      const filename = this.generateFilename(options.filename, 'png');

      // 验证data URL格式
      if (!dataUrl.startsWith('data:image/')) {
        throw new AppError(
          ErrorCode.CHART_EXPORT_ERROR,
          'Invalid image data URL',
          '图表图片数据格式无效'
        );
      }

      // 提取base64数据
      const base64Data = dataUrl.split(',')[1];
      if (!base64Data) {
        throw new AppError(
          ErrorCode.CHART_EXPORT_ERROR,
          'No image data found',
          '图表图片数据为空'
        );
      }

      // 将base64转换为ArrayBuffer
      const buffer = this.base64ToArrayBuffer(base64Data);

      await this.saveBinaryFile(buffer, filename, 'image/png');
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportPng');
    }
  }

  /**
   * 导出图表为PDF文件（简化实现）
   * @param config 图表配置
   * @param options 导出选项
   */
  static async exportPdf(config: ChartConfig, options: ExportOptions = {}): Promise<void> {
    try {
      const filename = this.generateFilename(options.filename, 'pdf');

      // 简化的PDF导出：将JSON配置保存为PDF格式的文本文件
      // 在实际项目中，这里应该使用PDF生成库
      const pdfContent = this.generateSimplePdfContent(config);

      await this.saveTextFile(pdfContent, filename, 'application/pdf');
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportPdf');
    }
  }

  /**
   * 保存文本文件
   * @param content 文件内容
   * @param filename 文件名
   * @param mimeType MIME类型
   */
  private static async saveTextFile(content: string, filename: string, mimeType: string): Promise<void> {
    const documentPicker = new picker.DocumentViewPicker();

    return new Promise<void>((resolve, reject) => {
      documentPicker.save((err: BusinessError, uri: string) => {
        if (err) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            `Failed to save file: ${err.message}`,
            '文件保存失败，请检查存储权限'
          ));
          return;
        }

        if (!uri) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            'No file URI returned',
            '文件保存失败，未获得文件路径'
          ));
          return;
        }

        try {
          const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          const buffer = new ArrayBuffer(content.length);
          const view = new Uint8Array(buffer);

          // 将字符串转换为字节数组
          for (let i = 0; i < content.length; i++) {
            view[i] = content.charCodeAt(i);
          }

          fs.writeSync(file.fd, buffer);
          fs.closeSync(file);

          console.log(`文件保存成功: ${uri}`);
          resolve();
        } catch (writeError) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            `Write operation failed: ${writeError}`,
            '文件写入失败'
          ));
        }
      });
    });
  }

  /**
   * 保存二进制文件
   * @param buffer 文件数据
   * @param filename 文件名
   * @param mimeType MIME类型
   */
  private static async saveBinaryFile(buffer: ArrayBuffer, filename: string, mimeType: string): Promise<void> {
    const documentPicker = new picker.DocumentViewPicker();

    return new Promise<void>((resolve, reject) => {
      documentPicker.save((err: BusinessError, uri: string) => {
        if (err) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            `Failed to save file: ${err.message}`,
            '文件保存失败，请检查存储权限'
          ));
          return;
        }

        if (!uri) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            'No file URI returned',
            '文件保存失败，未获得文件路径'
          ));
          return;
        }

        try {
          const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          fs.writeSync(file.fd, buffer);
          fs.closeSync(file);

          console.log(`文件保存成功: ${uri}`);
          resolve();
        } catch (writeError) {
          reject(new AppError(
            ErrorCode.FILE_WRITE_ERROR,
            `Write operation failed: ${writeError}`,
            '文件写入失败'
          ));
        }
      });
    });
  }

  /**
   * 生成文件名
   * @param customFilename 自定义文件名
   * @param extension 文件扩展名
   */
  private static generateFilename(customFilename?: string, extension?: string): string {
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[:-]/g, '');

    let filename = customFilename || this.DEFAULT_FILENAME;

    // 清理文件名，移除非法字符
    filename = filename.replace(/[<>:"/\\|?*]/g, '_');

    // 限制文件名长度
    if (filename.length > this.MAX_FILENAME_LENGTH) {
      filename = filename.substring(0, this.MAX_FILENAME_LENGTH);
    }

    return `${filename}_${timestamp}.${extension || 'txt'}`;
  }

  /**
   * 将base64字符串转换为ArrayBuffer
   * @param base64 base64编码字符串
   */
  private static base64ToArrayBuffer(base64: string): ArrayBuffer {
    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);

    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    return bytes.buffer;
  }

  /**
   * 生成简化的PDF内容（实际项目中应使用专门的PDF库）
   * @param config 图表配置
   */
  private static generateSimplePdfContent(config: ChartConfig): string {
    // 这是一个简化的PDF实现
    // 在实际项目中，应该使用专业的PDF生成库
    const title = config.title?.text || '图表';
    const jsonContent = JSON.stringify(config, null, 2);

    return `%PDF-1.4
1 0 obj
<<
/Title (${title})
/Creator (AI Assistant HarmonyOS)
>>
endobj

2 0 obj
<<
/Length ${jsonContent.length}
>>
stream
${jsonContent}
endstream
endobj

xref
0 3
0000000000 65535 f
0000000010 00000 n
0000000079 00000 n
trailer
<<
/Size 3
/Root 1 0 R
>>
startxref
${jsonContent.length + 120}
%%EOF`;
  }

  /**
   * 检查文件大小限制
   * @param size 文件大小（字节）
   * @param maxSize 最大允许大小（字节）
   */
  static checkFileSize(size: number, maxSize: number = 10 * 1024 * 1024): void {
    if (size > maxSize) {
      throw new AppError(
        ErrorCode.FILE_TOO_LARGE,
        `File size ${size} exceeds limit ${maxSize}`,
        `文件过大，最大支持 ${Math.round(maxSize / 1024 / 1024)}MB`
      );
    }
  }

  /**
   * 获取文件信息
   * @param uri 文件URI
   */
  static async getFileInfo(uri: string): Promise<{ size: number; lastModified: number }> {
    try {
      const stat = fs.statSync(uri);
      return {
        size: stat.size,
        lastModified: stat.mtime
      };
    } catch (error) {
      throw ErrorHandler.handle(error, 'getFileInfo');
    }
  }
}