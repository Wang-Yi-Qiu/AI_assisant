/**
 * 样本数据管理器：加载和管理预设的样本数据
 * @module sampleDataManager
 */

import { ErrorHandler, AppError, ErrorCode } from './errorHandler';
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

/**
 * 样本数据元数据接口
 */
export interface SampleDataset {
  id: string;
  name: string;
  description: string;
  filePath: string;
  category: 'sales' | 'users' | 'timeseries' | 'finance' | 'other';
  chartType?: 'line' | 'bar' | 'pie' | 'scatter';
}

/**
 * 样本数据列表元数据（5种样本数据）
 */
const SAMPLE_DATA_LIST: SampleDataset[] = [
  {
    id: 'sales-monthly',
    name: '月度销售数据',
    description: '展示月度销售趋势的示例数据，适合折线图和柱状图',
    filePath: 'sample-data/sales-monthly.json',
    category: 'sales',
    chartType: 'line'
  },
  {
    id: 'users-growth',
    name: '用户增长数据',
    description: '展示用户增长趋势的示例数据，适合折线图和柱状图',
    filePath: 'sample-data/users-growth.json',
    category: 'users',
    chartType: 'line'
  },
  {
    id: 'products-category',
    name: '产品分类占比数据',
    description: '展示产品分类占比的示例数据，适合饼图',
    filePath: 'sample-data/products-category.json',
    category: 'other',
    chartType: 'pie'
  },
  {
    id: 'sales-profit',
    name: '销售与利润关系数据',
    description: '展示销售与利润关系的示例数据，适合散点图',
    filePath: 'sample-data/sales-profit.json',
    category: 'sales',
    chartType: 'scatter'
  },
  {
    id: 'timeseries-daily',
    name: '时间序列数据',
    description: '展示时间序列的示例数据，适合折线图',
    filePath: 'sample-data/timeseries-daily.json',
    category: 'timeseries',
    chartType: 'line'
  }
];

/**
 * 获取所有可用样本数据列表
 * @returns SampleDataset[] 样本数据列表
 */
export function getSampleDataList(): SampleDataset[] {
  return SAMPLE_DATA_LIST;
}

/**
 * 根据ID获取样本数据元数据
 * @param id 样本数据ID
 * @returns SampleDataset | undefined 样本数据元数据
 */
export function getSampleDataById(id: string): SampleDataset | undefined {
  return SAMPLE_DATA_LIST.find(item => item.id === id);
}

/**
 * 加载指定的样本数据
 * @param sampleId 样本数据ID
 * @param context 应用上下文（可选，如果不提供则尝试从全局获取）
 * @returns Promise<string> 样本数据的JSON字符串
 * @throws {AppError} 当文件不存在、格式错误或加载失败时
 */
export async function loadSampleData(sampleId: string, context?: common.UIAbilityContext): Promise<string> {
  // 查找样本数据元数据
  const sampleData = getSampleDataById(sampleId);
  if (!sampleData) {
    throw new AppError(
      ErrorCode.FILE_NOT_FOUND,
      `Sample data not found: ${sampleId}`,
      '样本数据不存在，请手动输入数据'
    );
  }

  try {
    // 获取应用上下文
    let appContext: common.UIAbilityContext | null = context || null;
    if (!appContext) {
      try {
        // 尝试从全局获取上下文（需要应用初始化时设置）
        appContext = getContext() as common.UIAbilityContext;
      } catch {
        throw new AppError(
          ErrorCode.SYSTEM_ERROR,
          'Application context not available',
          '应用上下文不可用，请稍后重试'
        );
      }
    }

    if (!appContext) {
      throw new AppError(
        ErrorCode.SYSTEM_ERROR,
        'Application context not available',
        '应用上下文不可用，请稍后重试'
      );
    }

    // 从 rawfile 加载资源（使用同步方法，在异步函数中调用）
    const rm = appContext.resourceManager;
    let rawFileContent: string;
    try {
      const bytes: Uint8Array = rm.getRawFileContentSync(sampleData.filePath);
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      rawFileContent = decoder.decodeWithStream(new Uint8Array(bytes), { stream: false });
    } catch (fileError) {
      const errorMessage = fileError instanceof Error ? fileError.message : String(fileError);
      if (errorMessage.includes('not found') || errorMessage.includes('ENOENT') || errorMessage.includes('文件不存在')) {
        throw new AppError(
          ErrorCode.FILE_NOT_FOUND,
          `Sample data file not found: ${sampleId}`,
          '样本数据文件不存在，请手动输入数据',
          { originalError: fileError as Error | object | string | null | undefined }
        );
      }
      throw new AppError(
        ErrorCode.FILE_READ_ERROR,
        `Failed to read sample data file: ${sampleId}`,
        '样本数据文件读取失败，请手动输入数据',
        { originalError: fileError as Error | object | string | null | undefined }
      );
    }
    
    if (!rawFileContent || rawFileContent.trim().length === 0) {
      throw new AppError(
        ErrorCode.DATA_FORMAT_ERROR,
        `Sample data is empty: ${sampleId}`,
        '样本数据无效，请手动输入数据'
      );
    }

    // 验证JSON格式
    try {
      const parsed = JSON.parse(rawFileContent);
      // 验证数据包含至少1个数据点
      if (Array.isArray(parsed)) {
        if (parsed.length === 0) {
          throw new AppError(
            ErrorCode.DATA_FORMAT_ERROR,
            `Sample data has no data points: ${sampleId}`,
            '样本数据不完整，请手动输入数据'
          );
        }
      } else if (typeof parsed === 'object') {
        // 检查对象是否有数据字段
        const hasData = 'data' in parsed || 'values' in parsed || Object.keys(parsed).length > 0;
        if (!hasData) {
          throw new AppError(
            ErrorCode.DATA_FORMAT_ERROR,
            `Sample data has no valid data: ${sampleId}`,
            '样本数据不完整，请手动输入数据'
          );
        }
      }
    } catch (parseError) {
      if (parseError instanceof AppError) {
        throw parseError;
      }
      throw new AppError(
        ErrorCode.FILE_PARSE_ERROR,
        `Invalid JSON format in sample data: ${sampleId}`,
        '样本数据格式错误，请手动输入数据',
        { originalError: parseError as Error | object | string | null | undefined }
      );
    }

    return rawFileContent;
  } catch (error) {
    // 处理文件读取错误
    if (error instanceof AppError) {
      throw error;
    }

    // 其他错误
    throw ErrorHandler.handle(error, 'loadSampleData');
  }
}

/**
 * 获取应用上下文（辅助函数）
 * 注意：这需要在应用初始化时设置全局上下文
 */
let globalContext: common.UIAbilityContext | null = null;

/**
 * 设置全局应用上下文
 * @param context 应用上下文
 */
export function setGlobalContext(context: common.UIAbilityContext): void {
  globalContext = context;
}

/**
 * 获取全局应用上下文
 * @returns 应用上下文或null
 */
function getContext(): common.UIAbilityContext | null {
  return globalContext;
}

/**
 * 加载所有样本数据（用于预加载或验证）
 * @param context 应用上下文（可选）
 * @returns Promise<Map<string, string>> 样本数据映射（ID -> JSON字符串）
 */
export async function loadAllSampleData(context?: common.UIAbilityContext): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  const errors: string[] = [];

  for (const sampleData of SAMPLE_DATA_LIST) {
    try {
      const content = await loadSampleData(sampleData.id, context);
      result.set(sampleData.id, content);
    } catch (error) {
      const errorMessage = error instanceof AppError ? error.userMessage : 
                          (error instanceof Error ? error.message : String(error));
      errors.push(`${sampleData.name}: ${errorMessage}`);
    }
  }

  // 如果有部分失败，记录警告但不抛出错误
  if (errors.length > 0 && errors.length < SAMPLE_DATA_LIST.length) {
    console.warn('部分样本数据加载失败:', errors);
  } else if (errors.length === SAMPLE_DATA_LIST.length) {
    // 全部失败时抛出错误
    throw new AppError(
      ErrorCode.FILE_READ_ERROR,
      'All sample data files failed to load',
      '所有样本数据加载失败，请手动输入数据'
    );
  }

  return result;
}

