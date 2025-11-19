/**
 * AI服务封装：调用Edge Function generate_chart_qwen生成图表配置
 * @module aiService
 */

import { saveChart, getSupabaseUrl, getSupabaseAnonKey } from './supabaseClient';
import { startTimer, endTimer, newRequestId, LogPayload } from './metrics';
import { httpClient, handleHttpError, RequestManager } from './httpClient';
import { ErrorHandler, AppError, ErrorCode } from './errorHandler';
import { isChartConfig, isValidUserData, validateAndCleanString } from './typeGuard';

// 自定义取消令牌，替代AbortSignal
export interface CancellationToken {
  cancelled: boolean;
  cancel(): void;
  onCancel(callback: () => void): void;
}

// 自定义取消异常，替代DOMException
class OperationCancelledException extends Error {
  constructor(message: string = '操作已取消') {
    super(message);
    this.name = 'OperationCancelledException';
  }
}

class CancellationTokenImpl implements CancellationToken {
  public cancelled = false;
  private callbacks: (() => void)[] = [];

  cancel(): void {
    if (!this.cancelled) {
      this.cancelled = true;
      for (const callback of this.callbacks) {
        callback();
      }
      this.callbacks = [];
    }
  }

  onCancel(callback: () => void): void {
    if (this.cancelled) {
      callback();
    } else {
      this.callbacks.push(callback);
    }
  }
}

// 明确的数据点接口
export interface EChartsDataPoint {
  name: string;
  value: number | string;
}

// 明确的格式化参数接口
export interface EChartsFormatterParams {
  name: string;
  value: number | string;
  componentType?: string;
  seriesType?: string;
  seriesName?: string;
  seriesIndex?: number;
  dataIndex?: number;
}

export interface EChartsTitle {
  text?: string;
  subtext?: string;
  left?: string | number;
  top?: string | number;
  textStyle?: {
    color?: string;
    fontSize?: number;
    fontWeight?: 'normal' | 'bold' | 'bolder' | 'lighter';
  };
}

export interface EChartsAxis {
  type?: 'category' | 'value' | 'time' | 'log';
  data?: string[] | number[];
  name?: string;
  nameLocation?: 'start' | 'middle' | 'end';
  nameTextStyle?: {
    color?: string;
    fontSize?: number;
  };
}

export interface EChartsSeriesItem {
  type: string;
  name?: string;
  data?: number[] | EChartsDataPoint[] | unknown[];
  xAxisIndex?: number;
  yAxisIndex?: number;
  color?: string | string[];
  itemStyle?: {
    color?: string;
    borderWidth?: number;
    borderColor?: string;
  };
  label?: {
    show?: boolean;
    position?: 'top' | 'left' | 'right' | 'bottom' | 'inside' | 'outside';
    formatter?: string | ((params: EChartsFormatterParams) => string);
  };
}

export interface EChartsLegend {
  data?: string[];
  orient?: 'horizontal' | 'vertical';
  left?: string | number;
  top?: string | number;
}

export interface EChartsGrid {
  left?: string | number;
  top?: string | number;
  right?: string | number;
  bottom?: string | number;
  containLabel?: boolean;
}

export interface ChartConfig {
  title?: EChartsTitle;
  tooltip?: {
    trigger?: 'item' | 'axis';
    axisPointer?: {
      type?: 'line' | 'shadow' | 'cross';
    };
  };
  legend?: EChartsLegend;
  grid?: EChartsGrid;
  xAxis?: EChartsAxis | EChartsAxis[];
  yAxis?: EChartsAxis | EChartsAxis[];
  series: EChartsSeriesItem[];
  color?: string[];
  backgroundColor?: string;
}

export interface CSVData {
  headers: string[];
  data: CSVDataRow[];
}

interface CSVDataRow {
  values: string[];
}

export type UserData = string | object | CSVData;

export interface ErrorResponse { code: string; message?: string; errors?: string[] }

let lastGeneratedConfig: ChartConfig | null = null;

/**
 * 生成图表配置
 * @param userData 用户输入的数据（CSV解析后的对象、结构化JSON或字符串）
 * @param token CancellationToken用于取消操作
 * @returns Promise<ChartConfig> ECharts配置对象
 * @throws {AppError} 当API调用失败或返回错误时
 */
export async function generateChart(userData: UserData, token?: CancellationToken): Promise<ChartConfig> {
  // 1. 输入验证
  if (!isValidUserData(userData)) {
    throw new AppError(
      ErrorCode.INVALID_INPUT,
      'Invalid user data provided',
      '输入数据格式无效，请检查数据内容',
      { originalError: userData }
    );
  }

  // 2. 清理和验证字符串输入
  let cleanedData: UserData;
  if (typeof userData === 'string') {
    cleanedData = validateAndCleanString(userData);
  } else {
    cleanedData = userData;
  }

  // 检查取消信号
  if (token?.cancelled) {
    throw new OperationCancelledException();
  }

  const url = getEdgeUrl();
  const requestId = newRequestId();
  const timer = startTimer('chart_generation_client');

  try {
    // 使用清理后的数据，创建自定义HTTP客户端实例以处理取消
    const requestManager = new RequestManager('generateChart');

    // 设置取消检查
    let cancelled = false;
    if (token) {
      token.onCancel(() => {
        cancelled = true;
        requestManager.cleanup();
      });
    }

    const response = await httpClient.supabasePost('/functions/v1/generate_chart_qwen', JSON.stringify(cleanedData));

    if (cancelled) {
      throw new OperationCancelledException();
    }

    if (response.status < 200 || response.status >= 300) {
      let errorData: ErrorResponse = { code: 'UNKNOWN_ERROR' };
      try {
        errorData = await httpClient.parseJsonResponse<ErrorResponse>(response);
      } catch {
        // 忽略解析错误，使用默认值
      }

      // 将API错误代码映射到ErrorCode
      let errorCode: ErrorCode;
      switch (errorData.code) {
        case 'INVALID_INPUT':
          errorCode = ErrorCode.INVALID_INPUT;
          break;
        case 'INVALID_JSON_OUTPUT':
          errorCode = ErrorCode.INVALID_JSON_OUTPUT;
          break;
        case 'INVALID_MODEL_OUTPUT':
          errorCode = ErrorCode.INVALID_MODEL_OUTPUT;
          break;
        case 'QWEN_ERROR':
          errorCode = ErrorCode.QWEN_ERROR;
          break;
        default:
          errorCode = ErrorCode.API_ERROR;
          break;
      }

      const duration = Date.now() - timer.start;
      const errorPayload: LogPayload = {
        action: timer.id,
        duration: duration,
        timestamp: new Date().toISOString(),
        requestId: requestId,
        ok: false,
        code: errorData.code || 'UNKNOWN_ERROR',
      };
      endTimer(timer, errorPayload);

      const appError = new AppError(
        errorCode,
        `API error: ${errorData.code}`,
        'API调用失败，请稍后重试',
        { originalError: errorData }
      );
      ErrorHandler.reportError(appError);
      throw appError;
    }

    const rawData = await httpClient.parseJsonResponse<unknown>(response);

    // 使用类型守卫验证返回的配置
    if (!isChartConfig(rawData)) {
      throw new AppError(
        ErrorCode.INVALID_MODEL_OUTPUT,
        'Invalid chart configuration returned',
        'AI生成的图表配置无效，请重试',
        rawData
      );
    }

    const config: ChartConfig = {
      title: rawData.title || { text: '生成的图表' },
      series: rawData.series || [{
        type: 'bar',
        data: [{ name: '示例', value: 50 }]
      }]
    };

    lastGeneratedConfig = config;
    const duration = Date.now() - timer.start;
    const successPayload: LogPayload = {
      action: timer.id,
      duration: duration,
      timestamp: new Date().toISOString(),
      requestId: requestId,
      ok: true,
    };
    endTimer(timer, successPayload);

    // 保存到Supabase（需要认证token）
    try {
      await saveChart(config);
    } catch (saveError) {
      console.warn('保存图表记录失败:', saveError);
      // 不阻塞主流程，仅警告
    }

    return config;
  } catch (error) {
    // 如果已经是AppError，直接重新抛出
    if (error instanceof AppError) {
      throw error;
    }

    // 否则使用ErrorHandler处理
    const appError = ErrorHandler.handle(error, 'generateChart');
    const duration = Date.now() - timer.start;
    const errorPayload: LogPayload = {
      action: timer.id,
      duration: duration,
      timestamp: new Date().toISOString(),
      requestId: requestId,
      ok: false,
      code: appError.code,
    };
    endTimer(timer, errorPayload);

    ErrorHandler.reportError(appError);
    throw appError;
  }
}

/**
 * 获取最近生成的图表配置
 */
export function getLastGeneratedConfig(): ChartConfig | null {
  return lastGeneratedConfig;
}

/**
 * 获取Edge Function URL
 * 应从环境配置或应用配置中读取
 */
function getEdgeUrl(): string {
  // 从配置读取 Supabase 基础 URL 并拼接函数路径
  const base = getSupabaseUrl().replace(/\/$/, '');
  return `${base}/functions/v1/generate_chart_qwen`;
}


