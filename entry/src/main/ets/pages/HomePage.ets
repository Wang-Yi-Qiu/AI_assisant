/**
 * 首页：上传或输入数据，触发图表生成
 * @module HomePage
 */

import { generateChart, ChartConfig, UserData, CSVData } from '../utils/aiService';

/**
 * 从文本输入生成图表
 * @param text 用户输入的文本（可以是JSON字符串、CSV文本等）
 * @returns Promise<ChartConfig> 生成的图表配置
 * @throws {Error} 当输入无效或生成失败时
 */
export async function onGenerateFromText(text: string): Promise<ChartConfig> {
  if (!text || text.trim().length === 0) {
    throw new Error('输入不能为空，请提供数据');
  }

  const data = parseUserInput(text.trim());
  return await generateChart(data);
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

  const data = parseFileContent(fileContent, fileName);
  return await generateChart(data);
}

/**
 * 解析用户输入的文本
 * 尝试解析为JSON，失败则返回原始文本
 */
export function parseUserInput(text: string): UserData {
  // 尝试解析为JSON
  if (text.trim().startsWith('{') || text.trim().startsWith('[')) {
    try {
      const parsed = JSON.parse(text) as Record<string, string | number | boolean | null>;
      return parsed;
    } catch {
      // JSON解析失败，继续作为原始文本处理
    }
  }
  // 返回原始文本或CSV解析结果
  return parseCSV(text);
}

/**
 * 解析CSV格式数据（简单实现）
 */
export function parseCSV(csvText: string): CSVData | string {
  // TODO: 使用CSV解析库（如papaparse）进行完整解析
  const lines = csvText.split('\n').filter(line => line.trim());
  if (lines.length === 0) return csvText;

  const headers = lines[0].split(',').map(h => h.trim());
  const rows = lines.slice(1).map(line => {
    const values = line.split(',').map(v => v.trim());
    const obj: Record<string, string> = {};
    headers.forEach((header, i) => {
      obj[header] = values[i] || '';
    });
    return obj;
  });

  const result: CSVData = { headers, data: rows };
  return result;
}

/**
 * 根据文件扩展名解析文件内容
 */
export function parseFileContent(content: string, fileName: string): UserData {
  const ext = fileName.split('.').pop()?.toLowerCase();
  
  switch (ext) {
    case 'json':
      try {
        const parsed = JSON.parse(content) as Record<string, string | number | boolean | null>;
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


