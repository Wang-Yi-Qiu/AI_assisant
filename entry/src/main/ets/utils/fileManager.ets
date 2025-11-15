/**
 * 文件管理和导出工具
 * @module fileManager
 */

import { ChartConfig } from './aiService';
import { BusinessError } from '@kit.BasicServicesKit';
import filePicker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { ErrorHandler, AppError, ErrorCode } from './errorHandler';

// 直接使用现有的错误代码，在ArkTS中不能动态扩展枚举

import { Context } from '@kit.AbilityKit';

export interface ExportOptions {
  filename?: string;
  format?: 'png' | 'pdf' | 'json';
  quality?: number; // 0-1 for PNG
  backgroundColor?: string;
}

// 文件信息接口
interface FileInfo {
  size: number;
  lastModified: number;
}

export class FileManager {
  private static readonly DEFAULT_FILENAME = 'chart';
  private static readonly MAX_FILENAME_LENGTH = 50;

  /**
   * 导出图表配置为JSON文件
   * @param config 图表配置
   * @param options 导出选项
   */
  static async exportJson(config: ChartConfig, options: ExportOptions = {}, context?: Context): Promise<void> {
    try {
      const filename = FileManager.generateFilename(options.filename, 'json');
      const jsonData = JSON.stringify(config, null, 2);

      await FileManager.saveTextFile(jsonData, filename, 'application/json', context);
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportJson');
    }
  }

  /**
   * 导出图表为PNG文件
   * @param dataUrl base64编码的图片数据
   * @param options 导出选项
   */
  static async exportPng(dataUrl: string, options: ExportOptions = {}, context?: Context): Promise<void> {
    try {
      const filename = FileManager.generateFilename(options.filename, 'png');

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
      const buffer = FileManager.base64ToArrayBuffer(base64Data);

      await FileManager.saveBinaryFile(buffer, filename, 'image/png', context);
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportPng');
    }
  }

  /**
   * 导出图表为PDF文件
   * 由于HarmonyOS可能没有现成的PDF生成库，这里生成HTML文件
   * 用户可以在浏览器中打开并打印为PDF
   * @param config 图表配置
   * @param options 导出选项
   */
  static async exportPdf(config: ChartConfig, options: ExportOptions = {}, context?: Context): Promise<void> {
    try {
      // 生成HTML文件，用户可以在浏览器中打印为PDF
      const filename = FileManager.generateFilename(options.filename, 'html');
      const htmlContent = FileManager.generateHtmlForPdf(config);

      await FileManager.saveTextFile(htmlContent, filename, 'text/html', context);
    } catch (error) {
      throw ErrorHandler.handle(error, 'exportPdf');
    }
  }

  /**
   * 保存文本文件
   * @param content 文件内容
   * @param filename 文件名
   * @param mimeType MIME类型
   * @param context Context 对象（可选，用于文件保存）
   */
  private static async saveTextFile(content: string, filename: string, mimeType: string, context?: Context): Promise<void> {
    const documentSaveOptions = new filePicker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [filename];
    // 根据文件扩展名选择对应的文件类型
    const ext = filename.split('.').pop()?.toLowerCase();
    if (ext === 'html') {
      documentSaveOptions.fileSuffixChoices = ['.html', '.htm'];
    } else if (ext === 'pdf') {
      documentSaveOptions.fileSuffixChoices = ['.pdf'];
    } else {
      documentSaveOptions.fileSuffixChoices = ['.json', '.txt', '.html'];
    }

    const documentPicker = new filePicker.DocumentViewPicker();

    return new Promise<void>((resolve, reject) => {
      // save 方法需要 Context 参数，但需要通过 getContext() 获取
      if (!context) {
        reject(new AppError(
          ErrorCode.FILE_READ_ERROR,
          'Context is required for file save',
          '文件保存需要上下文信息'
        ));
        return;
      }
      // 注意：save 方法的签名是 save(context: Context, options: DocumentSaveOptions)
      // 但根据错误信息，可能需要使用不同的方式
      documentPicker.save(documentSaveOptions).then((uris: string[]) => {
        if (uris && uris.length > 0) {
          const uri = uris[0];
          if (!uri) {
            reject(new AppError(
              ErrorCode.FILE_READ_ERROR,
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
              ErrorCode.FILE_READ_ERROR,
              `Write operation failed: ${writeError}`,
              '文件写入失败'
            ));
          }
        } else {
          reject(new AppError(
            ErrorCode.FILE_READ_ERROR,
            'No file URI returned',
            '文件保存失败，未获得文件路径'
          ));
        }
      }).catch((err: BusinessError) => {
        reject(new AppError(
          ErrorCode.FILE_READ_ERROR,
          `Failed to save file: ${err.message}`,
          '文件保存失败，请检查存储权限'
        ));
      });
    });
  }

  /**
   * 保存二进制文件
   * @param buffer 文件数据
   * @param filename 文件名
   * @param mimeType MIME类型
   * @param context Context 对象（可选，用于文件保存）
   */
  private static async saveBinaryFile(buffer: ArrayBuffer, filename: string, mimeType: string, context?: Context): Promise<void> {
    const documentSaveOptions = new filePicker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [filename];
    documentSaveOptions.fileSuffixChoices = ['.png', '.jpg', '.jpeg'];

    const documentPicker = new filePicker.DocumentViewPicker();

    return new Promise<void>((resolve, reject) => {
      // save 方法需要 Context 参数，但需要通过 getContext() 获取
      if (!context) {
        reject(new AppError(
          ErrorCode.FILE_READ_ERROR,
          'Context is required for file save',
          '文件保存需要上下文信息'
        ));
        return;
      }
      // 注意：save 方法的签名是 save(context: Context, options: DocumentSaveOptions)
      // 但根据错误信息，可能需要使用不同的方式
      documentPicker.save(documentSaveOptions).then((uris: string[]) => {
        if (uris && uris.length > 0) {
          const uri = uris[0];
          if (!uri) {
            reject(new AppError(
              ErrorCode.FILE_READ_ERROR,
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
              ErrorCode.FILE_READ_ERROR,
              `Write operation failed: ${writeError}`,
              '文件写入失败'
            ));
          }
        } else {
          reject(new AppError(
            ErrorCode.FILE_READ_ERROR,
            'No file URI returned',
            '文件保存失败，未获得文件路径'
          ));
        }
      }).catch((err: BusinessError) => {
        reject(new AppError(
          ErrorCode.FILE_READ_ERROR,
          `Failed to save file: ${err.message}`,
          '文件保存失败，请检查存储权限'
        ));
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

    let filename = customFilename || FileManager.DEFAULT_FILENAME;

    // 清理文件名，移除非法字符
    filename = filename.replace(/[<>:"/\\|?*]/g, '_');

    // 限制文件名长度
    if (filename.length > FileManager.MAX_FILENAME_LENGTH) {
      filename = filename.substring(0, FileManager.MAX_FILENAME_LENGTH);
    }

    return `${filename}_${timestamp}.${extension || 'txt'}`;
  }

  /**
   * 将base64字符串转换为ArrayBuffer
   * @param base64 base64编码字符串
   */
  private static base64ToArrayBuffer(base64: string): ArrayBuffer {
    try {
      // 使用HarmonyOS的util工具进行base64解码
      const helper = new util.Base64Helper();
      const result = helper.decodeSync(base64);
      return result;
    } catch (error) {
      // 如果上述方法不可用，使用手动实现
      const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      let result = new Uint8Array(Math.floor(base64.length * 3 / 4));
      let bufferIndex = 0;

      for (let i = 0; i < base64.length; i += 4) {
        const encoded1 = base64Chars.indexOf(base64.charAt(i));
        const encoded2 = base64Chars.indexOf(base64.charAt(i + 1) || '=');
        const encoded3 = base64Chars.indexOf(base64.charAt(i + 2) || '=');
        const encoded4 = base64Chars.indexOf(base64.charAt(i + 3) || '=');

        const bitmap = (encoded1 << 18) | (encoded2 << 12) | (encoded3 << 6) | encoded4;

        result[bufferIndex++] = (bitmap >> 16) & 255;
        if (i + 2 < base64.length && base64.charAt(i + 2) !== '=') {
          result[bufferIndex++] = (bitmap >> 8) & 255;
        }
        if (i + 3 < base64.length && base64.charAt(i + 3) !== '=') {
          result[bufferIndex++] = bitmap & 255;
        }
      }

      return result.buffer.slice(0, bufferIndex);
    }
  }

  /**
   * 生成HTML内容，用于在浏览器中打印为PDF
   * @param config 图表配置
   */
  private static generateHtmlForPdf(config: ChartConfig): string {
    const title = config.title?.text || '图表';
    const jsonContent = JSON.stringify(config, null, 2);
    const seriesTypes = config.series?.map(s => s.type).filter(Boolean).join(', ') || '未知';
    const currentDate = new Date().toLocaleString('zh-CN');

    // 转义HTML特殊字符
    const escapeHtml = (text: string): string => {
      return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    };

    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHtml(title)} - 图表报告</title>
    <script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>
    <style>
        @media print {
            body { margin: 0; padding: 20px; }
            .no-print { display: none; }
            .chart-container { page-break-inside: avoid; }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Microsoft YaHei', sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #ffffff;
        }
        .header {
            border-bottom: 2px solid #1976D2;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .title {
            font-size: 28px;
            font-weight: bold;
            color: #1976D2;
            margin: 0 0 10px 0;
        }
        .meta {
            color: #666;
            font-size: 14px;
            margin: 5px 0;
        }
        .chart-container {
            width: 100%;
            height: 600px;
            margin: 30px 0;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background-color: #fafafa;
        }
        .config-section {
            margin-top: 40px;
            padding: 20px;
            background-color: #f5f5f5;
            border-radius: 8px;
        }
        .config-title {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }
        pre {
            background-color: #ffffff;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            border: 1px solid #ddd;
            font-size: 12px;
            line-height: 1.5;
        }
        .print-hint {
            background-color: #E3F2FD;
            border-left: 4px solid #1976D2;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .print-hint strong {
            color: #1976D2;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1 class="title">${escapeHtml(title)}</h1>
        <div class="meta">
            <div>图表类型: ${escapeHtml(seriesTypes)}</div>
            <div>生成时间: ${escapeHtml(currentDate)}</div>
            <div>来源: 鸿蒙 AI 智能数据可视化助手</div>
        </div>
    </div>

    <div class="print-hint no-print">
        <strong>提示：</strong>按 Ctrl+P (Windows) 或 Cmd+P (Mac) 打印此页面为PDF
    </div>

    <div class="chart-container">
        <div id="chart" style="width: 100%; height: 100%;"></div>
    </div>

    <div class="config-section">
        <div class="config-title">图表配置 (JSON)</div>
        <pre>${escapeHtml(jsonContent)}</pre>
    </div>

    <script>
        const chart = echarts.init(document.getElementById('chart'));
        const option = ${jsonContent};
        chart.setOption(option);
        
        // 窗口大小改变时重新调整图表
        window.addEventListener('resize', function() {
            chart.resize();
        });
    </script>
</body>
</html>`;
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
  static async getFileInfo(uri: string): Promise<FileInfo> {
    try {
      const fileStat = fs.statSync(uri);
      const fileInfo: FileInfo = {
        size: fileStat.size,
        lastModified: fileStat.mtime
      };
      return fileInfo;
    } catch (error) {
      throw ErrorHandler.handle(error, 'getFileInfo');
    }
  }
}