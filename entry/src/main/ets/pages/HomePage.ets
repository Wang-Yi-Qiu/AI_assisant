/**
 * 首页：上传或输入数据，触发图表生成
 * @module HomePage
 */

import { generateChart, ChartConfig, UserData, CSVData, CancellationToken } from '../utils/aiService';

// 用户数据接口 - 避免使用索引签名
interface UserJSONObject {
  data: object; // 使用通用对象类型
}

interface CSVDataRow {
  values: string[]; // 使用数组结构替代索引签名
}

/**
 * 从文本输入生成图表
 * @param text 用户输入的文本（可以是JSON字符串、CSV文本等）
 * @param token CancellationToken用于取消操作
 * @returns Promise<ChartConfig> 生成的图表配置
 * @throws {Error} 当输入无效或生成失败时
 */
export async function onGenerateFromText(text: string, token?: CancellationToken): Promise<ChartConfig> {
  if (!text || text.trim().length === 0) {
    throw new Error('输入不能为空，请提供数据');
  }

  // 检查取消信号
  if (token?.cancelled) {
    throw new Error('操作已取消');
  }

  const data = parseUserInput(text.trim());

  // 再次检查取消信号
  if (token?.cancelled) {
    throw new Error('操作已取消');
  }

  return await generateChart(data, token);
}

/**
 * 从文件上传生成图表
 * @param fileContent 文件内容（文本格式）
 * @param fileName 文件名（用于推断格式）
 */
export async function onGenerateFromFile(fileContent: string, fileName: string): Promise<ChartConfig> {
  if (!fileContent || fileContent.trim().length === 0) {
    throw new Error('文件内容为空');
  }

  try {
    const data = parseFileContent(fileContent, fileName);
    return await generateChart(data);
  } catch (error) {
    throw new Error(`文件解析失败: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * 解析用户输入的文本
 * 尝试解析为JSON，失败则返回原始文本
 */
export function parseUserInput(text: string): UserData {
  // 尝试解析为JSON
  if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
    try {
      const parsed = JSON.parse(text) as object;
      return parsed;
    } catch {
      // JSON解析失败，继续作为原始文本处理
    }
  }
  // 返回原始文本或CSV解析结果
  return parseCSV(text);
}

// 解析CSV行的辅助函数（ArkTS不支持嵌套函数，需要提取到外部）
function parseCSVLine(line: string): string[] {
    const fields: string[] = [];
    let currentField = '';
    let inQuotes = false;
    let i = 0;

    while (i < line.length) {
      const char = line[i];
      const nextChar = i + 1 < line.length ? line[i + 1] : '';

      if (char === '"') {
        if (inQuotes && nextChar === '"') {
          // 转义的引号
          currentField += '"';
          i += 2;
        } else if (inQuotes && nextChar === ',') {
          // 引号结束，后面是逗号
          inQuotes = false;
          i += 2;
        } else if (!inQuotes && currentField.length === 0) {
          // 引号开始
          inQuotes = true;
          i++;
        } else {
          // 普通引号字符（在引号内）
          currentField += char;
          i++;
        }
      } else if (char === ',' && !inQuotes) {
        // 字段分隔符
        fields.push(currentField.trim());
        currentField = '';
        i++;
      } else {
        currentField += char;
        i++;
      }
    }

    // 添加最后一个字段
    fields.push(currentField.trim());

  return fields;
}

/**
 * 解析CSV格式数据（支持引号、转义等复杂情况）
 * 实现RFC 4180标准的CSV解析
 */
export function parseCSV(csvText: string): CSVData | string {
  const lines = csvText.split(/\r?\n/).filter(line => line.trim().length > 0);
  if (lines.length === 0) return csvText;

  try {
    // 解析表头
    const headers = parseCSVLine(lines[0]).map(h => {
      // 移除引号（如果存在）
      return h.replace(/^"|"$/g, '');
    });

    if (headers.length === 0) {
      return csvText;
    }

    // 解析数据行
    const rows = lines.slice(1).map(line => {
      const values = parseCSVLine(line).map(v => {
        // 移除引号（如果存在）
        return v.replace(/^"|"$/g, '');
      });
      // 确保每行的列数与表头一致
      while (values.length < headers.length) {
        values.push('');
      }
      // 创建CSVDataRow对象（ArkTS不支持对象字面量类型，需要明确类型）
      const row: CSVDataRow = { values: values.slice(0, headers.length) };
      return row;
    });

    // 过滤掉空行
    const validRows = rows.filter(row => 
      row.values.some(v => v.trim().length > 0)
    );

    if (validRows.length === 0) {
      return csvText;
    }

    const result: CSVData = { headers, data: validRows };
    return result;
  } catch (error) {
    console.error('CSV解析失败:', error);
    // 解析失败时返回原始文本
    return csvText;
  }
}

/**
 * 根据文件扩展名解析文件内容
 */
export function parseFileContent(content: string, fileName: string): UserData {
  const ext = fileName.split('.').pop()?.toLowerCase();
  
  switch (ext) {
    case 'json':
      try {
        const parsed = JSON.parse(content) as object;
        return parsed;
      } catch {
        throw new Error('JSON文件格式无效');
      }
    case 'csv':
      return parseCSV(content);
    case 'txt':
    default:
      return parseUserInput(content);
  }
}


