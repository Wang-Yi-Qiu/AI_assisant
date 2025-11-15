/**
 * AI服务封装：调用Edge Function generate_chart_qwen生成图表配置
 * @module aiService
 */

import { saveChart, getSupabaseUrl, getSupabaseAnonKey } from './supabaseClient';
import { startTimer, endTimer, newRequestId, LogPayload } from './metrics';
import { httpClient, handleHttpError, RequestManager, HttpRequestHeaders } from './httpClient';
import { ErrorHandler, AppError, ErrorCode, ErrorDetails } from './errorHandler';
import { isChartConfig, isValidUserData, validateAndCleanString } from './typeGuard';
import { secureKeyManager } from './secureKeyManager';
import { authService } from './authService';

// 自定义取消令牌，替代AbortSignal
export interface CancellationToken {
  cancelled: boolean;
  cancel(): void;
  onCancel?(callback: () => void): void;
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

// ECharts文本样式接口
interface EChartsTextStyle {
  color?: string;
  fontSize?: number;
  fontWeight?: 'normal' | 'bold' | 'bolder' | 'lighter';
}

export interface EChartsTitle {
  text?: string;
  subtext?: string;
  left?: string | number;
  top?: string | number;
  textStyle?: EChartsTextStyle;
}

// ECharts轴文本样式接口
interface EChartsAxisTextStyle {
  color?: string;
  fontSize?: number;
}

export interface EChartsAxis {
  type?: 'category' | 'value' | 'time' | 'log';
  data?: string[] | number[];
  name?: string;
  nameLocation?: 'start' | 'middle' | 'end';
  nameTextStyle?: EChartsAxisTextStyle;
}

// ECharts系列项样式接口
interface EChartsItemStyle {
  color?: string;
  borderWidth?: number;
  borderColor?: string;
}

// ECharts标签接口
interface EChartsLabel {
  show?: boolean;
  position?: 'top' | 'left' | 'right' | 'bottom' | 'inside' | 'outside';
  formatter?: string | ((params: EChartsFormatterParams) => string);
}

export interface EChartsSeriesItem {
  type: string;
  name?: string;
  data?: number[] | EChartsDataPoint[] | (number | string | object)[];
  xAxisIndex?: number;
  yAxisIndex?: number;
  color?: string | string[];
  itemStyle?: EChartsItemStyle;
  label?: EChartsLabel;
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

// ECharts工具提示轴指针接口
interface EChartsTooltipAxisPointer {
  type?: 'line' | 'shadow' | 'cross';
}

// ECharts工具提示接口
interface EChartsTooltip {
  trigger?: 'item' | 'axis';
  axisPointer?: EChartsTooltipAxisPointer;
}

export interface ChartConfig {
  title?: EChartsTitle;
  tooltip?: EChartsTooltip;
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
let lastUserData: UserData | null = null; // 保存原始用户数据，用于重新生成

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
    // ArkTS不支持结构类型，需要明确转换
    const errorDetails: ErrorDetails = { originalError: userData as Error | object | string | null | undefined };
    throw new AppError(
      ErrorCode.INVALID_INPUT,
      'Invalid user data provided',
      '输入数据格式无效，请检查数据内容',
      errorDetails
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

  // 诊断日志
  console.log('[aiService] ========== 开始调用AI服务生成图表 ==========');
  console.log('[aiService] Edge Function URL:', url);
  console.log('[aiService] Request ID:', requestId);
  console.log('[aiService] User Data Type:', typeof cleanedData);
  console.log('[aiService] User Data Preview:', typeof cleanedData === 'string' ? 
    cleanedData.substring(0, 200) : JSON.stringify(cleanedData).substring(0, 200));

  try {
    // 使用清理后的数据，创建自定义HTTP客户端实例以处理取消
    const requestManager = new RequestManager('generateChart');

    // 设置取消检查
    let cancelled = false;
    if (token && token.onCancel) {
      token.onCancel(() => {
        cancelled = true;
        requestManager.cleanup();
      });
    } else if (token) {
      // 如果没有 onCancel 方法，使用轮询检查
      const checkInterval = setInterval(() => {
        if (token.cancelled) {
          cancelled = true;
          requestManager.cleanup();
          clearInterval(checkInterval);
        }
      }, 100);
    }

    // 获取用户 API Key（如果已设置）
    const userApiKey = await secureKeyManager.getApiKey();
    const sessionToken = authService.getSessionToken();
    const userId = authService.getUserId();
    
    // 构建自定义请求头（如果用户提供了 API Key）
    const customHeaders: HttpRequestHeaders = {};
    if (userApiKey) {
      customHeaders['X-User-Api-Key'] = userApiKey;
      console.log('[aiService] 使用用户提供的 API Key');
    } else {
      console.log('[aiService] 未检测到用户 API Key，将使用服务端默认 Key（如有）');
      // 传递用户ID用于配额管理
      if (userId) {
        customHeaders['X-User-Id'] = userId;
      }
    }

    const response = await httpClient.supabasePost(
      '/functions/v1/generate_chart_qwen', 
      JSON.stringify(cleanedData),
      sessionToken ?? undefined,
      customHeaders
    );

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

      // ArkTS不支持结构类型，需要明确转换
      const errorDetails: ErrorDetails = { 
        originalError: errorData as Error | object | string | null | undefined 
      };
      const appError = new AppError(
        errorCode,
        `API error: ${errorData.code}`,
        'API调用失败，请稍后重试',
        errorDetails
      );
      ErrorHandler.reportError(appError);
      throw appError;
    }

    const rawData = await httpClient.parseJsonResponse<ChartConfig>(response);

    // 使用类型守卫验证返回的配置
    if (!isChartConfig(rawData)) {
      throw new AppError(
        ErrorCode.INVALID_MODEL_OUTPUT,
        'Invalid chart configuration returned',
        'AI生成的图表配置无效，请重试',
        { originalError: rawData }
      );
    }

    const config: ChartConfig = rawData;

    lastGeneratedConfig = config;
    lastUserData = cleanedData; // 保存原始数据用于重新生成
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

    // 详细记录错误信息
    console.error('[aiService] 图表生成过程出错:', error);
    console.error('[aiService] 错误类型:', error instanceof Error ? error.constructor.name : typeof error);
    console.error('[aiService] 错误消息:', error instanceof Error ? error.message : String(error));
    
    // 检查是否是网络相关错误
    if (error instanceof Error) {
      const errorMsg = error.message.toLowerCase();
      if (errorMsg.includes('network') || errorMsg.includes('网络') || 
          errorMsg.includes('timeout') || errorMsg.includes('超时') ||
          errorMsg.includes('连接') || errorMsg.includes('connection') ||
          errorMsg.includes('dns') || errorMsg.includes('unreachable') ||
          errorMsg.includes('econnrefused') || errorMsg.includes('enotfound')) {
        console.error('[aiService] 检测到网络连接问题，可能是：');
        console.error('[aiService] 1. VPN影响网络连接');
        console.error('[aiService] 2. 网络不稳定');
        console.error('[aiService] 3. Supabase服务无法访问');
        console.error('[aiService] 4. 防火墙或代理设置问题');
      }
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
 * 获取最近使用的原始数据（用于重新生成）
 */
export function getLastUserData(): UserData | null {
  return lastUserData;
}

/**
 * 清除保存的图表配置和原始数据
 */
export function clearLastGeneratedData(): void {
  lastGeneratedConfig = null;
  lastUserData = null;
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

/**
 * AI洞察建议接口
 */
export interface InsightSuggestion {
  type: string;
  text: string;
  priority?: 'high' | 'medium' | 'low';
}

/**
 * AI洞察元数据接口
 */
export interface InsightMetadata {
  model?: string;
  generatedAt?: string;
  dataHash?: string;
}

/**
 * AI洞察响应接口
 */
export interface InsightResponse {
  insightText: string;
  confidence?: number;
  suggestions?: InsightSuggestion[];
  metadata?: InsightMetadata;
}

/**
 * 洞察类型
 */
export type InsightType = 'chart' | 'focus';

/**
 * 图表洞察请求数据
 */
export interface ChartInsightData {
  chartConfig?: ChartConfig;
  rawData?: string;
}

/**
 * 专注洞察请求数据
 */
export interface FocusInsightData {
  userId: string;
  period: 'week' | 'month' | 'year';
  periodStart: string; // ISO date string
  periodEnd: string; // ISO date string
  focusData: object;
}

/**
 * 洞察请求数据
 */
export type InsightData = ChartInsightData | FocusInsightData;

// 洞察内存缓存（缓存时间1小时）
interface InsightCacheItem {
  data: InsightResponse;
  expiresAt: number; // 时间戳（毫秒）
}

const insightCache = new Map<string, InsightCacheItem>();

/**
 * 生成图表数据AI洞察
 * @param data 图表配置或原始数据
 * @param token CancellationToken用于取消操作
 * @returns Promise<InsightResponse> AI生成的洞察
 * @throws {AppError} 当API调用失败或返回错误时
 */
export async function generateChartInsight(
  data: ChartInsightData,
  token?: CancellationToken
): Promise<InsightResponse> {
  return generateInsight('chart', data, token);
}

/**
 * 生成专注数据AI洞察
 * @param data 专注数据
 * @param token CancellationToken用于取消操作
 * @returns Promise<InsightResponse> AI生成的洞察
 * @throws {AppError} 当API调用失败或返回错误时
 */
export async function generateFocusInsight(
  data: FocusInsightData,
  token?: CancellationToken
): Promise<InsightResponse> {
  return generateInsight('focus', data, token);
}

/**
 * 生成AI洞察（通用方法）
 * @param type 洞察类型
 * @param data 洞察数据
 * @param token CancellationToken用于取消操作
 * @returns Promise<InsightResponse> AI生成的洞察
 * @throws {AppError} 当API调用失败或返回错误时
 */
async function generateInsight(
  type: InsightType,
  data: InsightData,
  token?: CancellationToken
): Promise<InsightResponse> {
  // 检查取消信号
  if (token?.cancelled) {
    throw new OperationCancelledException();
  }

  // 生成缓存键
  const cacheKey = generateCacheKey(type, data);
  
  // 检查缓存
  const cached = insightCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }

  // 清除过期缓存
  clearExpiredCache();

  const url = getInsightEdgeUrl();
  const requestId = newRequestId();
  const timer = startTimer('insight_generation_client');

  // 请求体接口
  interface InsightRequestBody {
    type: InsightType;
    data: InsightData;
  }

  try {
    // 构建请求体
    const requestBody: InsightRequestBody = {
      type: type,
      data: data
    };

    // 使用自定义HTTP客户端实例
    const requestManager = new RequestManager('generateInsight');

    // 设置取消检查
    let cancelled = false;
    if (token && token.onCancel) {
      token.onCancel(() => {
        cancelled = true;
        requestManager.cleanup();
      });
    } else if (token) {
      const checkInterval = setInterval(() => {
        if (token.cancelled) {
          cancelled = true;
          requestManager.cleanup();
          clearInterval(checkInterval);
        }
      }, 100);
    }

    // 获取用户 API Key（如果已设置）
    const userApiKey = await secureKeyManager.getApiKey();
    const sessionToken = authService.getSessionToken();
    const userId = authService.getUserId();
    
    // 构建自定义请求头（如果用户提供了 API Key）
    const customHeaders: HttpRequestHeaders = {};
    if (userApiKey) {
      customHeaders['X-User-Api-Key'] = userApiKey;
      console.log('[aiService] 使用用户提供的 API Key（洞察生成）');
    } else {
      console.log('[aiService] 未检测到用户 API Key，将使用服务端默认 Key（如有）');
      // 传递用户ID用于配额管理
      if (userId) {
        customHeaders['X-User-Id'] = userId;
      }
    }

    // 设置5秒超时
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => {
        reject(new AppError(
          ErrorCode.INSIGHT_TIMEOUT,
          'Insight generation timeout',
          'AI洞察生成超时，请稍后重试'
        ));
      }, 5000);
    });

    const responsePromise = httpClient.supabasePost(
      '/functions/v1/generate_insight',
      JSON.stringify(requestBody),
      sessionToken ?? undefined,
      customHeaders
    );

    const response = await Promise.race([responsePromise, timeoutPromise]);

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
        case 'INSIGHT_TIMEOUT':
          errorCode = ErrorCode.INSIGHT_TIMEOUT;
          break;
        case 'INSIGHT_SERVICE_UNAVAILABLE':
          errorCode = ErrorCode.INSIGHT_SERVICE_UNAVAILABLE;
          break;
        case 'INSIGHT_GENERATION_FAILED':
          errorCode = ErrorCode.INSIGHT_GENERATION_FAILED;
          break;
        case 'INSIGHT_INVALID_RESPONSE':
          errorCode = ErrorCode.INSIGHT_INVALID_RESPONSE;
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

      const errorDetails: ErrorDetails = { 
        originalError: errorData as Error | object | string | null | undefined 
      };
      // 获取错误消息（通过创建临时AppError实例）
      const tempError = new AppError(errorCode, '', '');
      const userMessage = tempError.userMessage || 'AI洞察生成失败，请稍后重试';
      
      const appError = new AppError(
        errorCode,
        `API error: ${errorData.code}`,
        userMessage,
        errorDetails
      );
      ErrorHandler.reportError(appError);
      throw appError;
    }

    const rawData = await httpClient.parseJsonResponse<InsightResponse>(response);

    // 验证响应格式
    if (!rawData || !rawData.insightText || rawData.insightText.trim().length === 0) {
      throw new AppError(
        ErrorCode.INSIGHT_INVALID_RESPONSE,
        'Invalid insight response format',
        '洞察数据格式错误，请稍后重试',
        { originalError: rawData }
      );
    }

    const insight: InsightResponse = rawData;

    // 存储到缓存（缓存时间1小时）
    const expiresAt = Date.now() + 60 * 60 * 1000; // 1小时
    insightCache.set(cacheKey, {
      data: insight,
      expiresAt: expiresAt
    });

    const duration = Date.now() - timer.start;
    const successPayload: LogPayload = {
      action: timer.id,
      duration: duration,
      timestamp: new Date().toISOString(),
      requestId: requestId,
      ok: true
    };
    endTimer(timer, successPayload);

    return insight;
  } catch (error) {
    // 如果已经是AppError，直接重新抛出
    if (error instanceof AppError) {
      throw error;
    }

    // 否则使用ErrorHandler处理
    const appError = ErrorHandler.handle(error, 'generateInsight');
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
 * 生成缓存键
 * @param type 洞察类型
 * @param data 洞察数据
 * @returns string 缓存键
 */
function generateCacheKey(type: InsightType, data: InsightData): string {
  // 简单的哈希函数（用于生成缓存键）
  const dataStr = JSON.stringify(data);
  let hash = 0;
  for (let i = 0; i < dataStr.length; i++) {
    const char = dataStr.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  
  if (type === 'chart') {
    return `chart-${Math.abs(hash)}`;
  } else {
    const focusData = data as FocusInsightData;
    return `focus-${focusData.userId}-${focusData.period}`;
  }
}

/**
 * 清除过期的缓存项
 */
function clearExpiredCache(): void {
  const now = Date.now();
  const keys: string[] = [];
  insightCache.forEach((item, key) => {
    if (item.expiresAt <= now) {
      keys.push(key);
    }
  });
  for (let i = 0; i < keys.length; i++) {
    insightCache.delete(keys[i]);
  }
}

/**
 * 获取洞察Edge Function URL
 */
function getInsightEdgeUrl(): string {
  const base = getSupabaseUrl().replace(/\/$/, '');
  return `${base}/functions/v1/generate_insight`;
}


