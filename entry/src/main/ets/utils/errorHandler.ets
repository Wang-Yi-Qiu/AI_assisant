/**
 * 统一错误处理系统
 * @module errorHandler
 */

export enum ErrorCode {
  // 网络相关错误
  NETWORK_ERROR = 'NETWORK_ERROR',
  API_TIMEOUT = 'API_TIMEOUT',
  API_ERROR = 'API_ERROR',

  // 文件相关错误
  FILE_TOO_LARGE = 'FILE_TOO_LARGE',
  FILE_READ_ERROR = 'FILE_READ_ERROR',
  FILE_PARSE_ERROR = 'FILE_PARSE_ERROR',
  FILE_NOT_FOUND = 'FILE_NOT_FOUND',

  // 数据相关错误
  INVALID_INPUT = 'INVALID_INPUT',
  DATA_FORMAT_ERROR = 'DATA_FORMAT_ERROR',
  INVALID_JSON_OUTPUT = 'INVALID_JSON_OUTPUT',
  INVALID_MODEL_OUTPUT = 'INVALID_MODEL_OUTPUT',

  // 认证相关错误
  AUTH_ERROR = 'AUTH_ERROR',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  USER_NOT_FOUND = 'USER_NOT_FOUND',

  // 图表相关错误
  CHART_RENDER_ERROR = 'CHART_RENDER_ERROR',
  CHART_EXPORT_ERROR = 'CHART_EXPORT_ERROR',
  CHART_CONFIG_INVALID = 'CHART_CONFIG_INVALID',

  // 系统相关错误
  SYSTEM_ERROR = 'SYSTEM_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',

  // AI服务相关错误
  QWEN_ERROR = 'QWEN_ERROR',

  // AI洞察相关错误
  INSIGHT_TIMEOUT = 'INSIGHT_TIMEOUT',
  INSIGHT_SERVICE_UNAVAILABLE = 'INSIGHT_SERVICE_UNAVAILABLE',
  INSIGHT_GENERATION_FAILED = 'INSIGHT_GENERATION_FAILED',
  INSIGHT_INVALID_RESPONSE = 'INSIGHT_INVALID_RESPONSE',
  INSIGHT_CACHE_ERROR = 'INSIGHT_CACHE_ERROR',

  // 添加缺少的错误代码
  NOT_FOUND = 'NOT_FOUND'
}

export interface ErrorDetails {
  originalError?: Error | object | string | null | undefined;
  stack?: string;
  context?: string;
  timestamp?: string;
}

// API错误对象接口（放在类外面）
interface ApiErrorObject {
  code?: string;
  status?: number;
  statusCode?: number;
}

export class AppError extends Error {
  public code: ErrorCode;
  public userMessage?: string;
  public details?: ErrorDetails;

  constructor(code: ErrorCode, message: string, userMessage?: string, details?: ErrorDetails) {
    super(message);
    this.code = code;
    this.userMessage = userMessage;
    this.details = details;
    this.name = 'AppError';
  }
}

export class ErrorHandler {
  /**
   * 获取错误消息
   */
  private static getErrorMessage(errorCode: ErrorCode): string {
    switch (errorCode) {
      case ErrorCode.NETWORK_ERROR:
        return '网络连接失败，请检查网络设置';
      case ErrorCode.API_TIMEOUT:
        return '请求超时，请稍后重试';
      case ErrorCode.API_ERROR:
        return 'API调用失败，请稍后重试';

      case ErrorCode.FILE_TOO_LARGE:
        return '文件过大，请选择较小的文件';
      case ErrorCode.FILE_READ_ERROR:
        return '文件读取失败，请检查文件是否损坏';
      case ErrorCode.FILE_PARSE_ERROR:
        return '文件格式解析失败，请检查文件内容';
      case ErrorCode.FILE_NOT_FOUND:
        return '未找到指定文件';

      case ErrorCode.INVALID_INPUT:
        return '输入数据格式无效，请检查数据格式';
      case ErrorCode.DATA_FORMAT_ERROR:
        return '数据格式错误，请检查数据内容';
      case ErrorCode.INVALID_JSON_OUTPUT:
        return 'AI返回格式异常，请重试';
      case ErrorCode.INVALID_MODEL_OUTPUT:
        return 'AI返回的图表配置不符合要求';

      case ErrorCode.AUTH_ERROR:
        return '认证失败，请重新登录';
      case ErrorCode.TOKEN_EXPIRED:
        return '登录已过期，请重新登录';
      case ErrorCode.USER_NOT_FOUND:
        return '用户信息不存在，请重新登录';

      case ErrorCode.CHART_RENDER_ERROR:
        return '图表渲染失败，请重试';
      case ErrorCode.CHART_EXPORT_ERROR:
        return '图表导出失败，请重试';
      case ErrorCode.CHART_CONFIG_INVALID:
        return '图表配置无效';

      case ErrorCode.SYSTEM_ERROR:
        return '系统异常，请稍后重试';
      case ErrorCode.UNKNOWN_ERROR:
        return '服务异常，请稍后重试';

      case ErrorCode.QWEN_ERROR:
        return 'AI服务调用失败，请稍后重试';

      case ErrorCode.INSIGHT_TIMEOUT:
        return 'AI洞察生成超时，请稍后重试';
      case ErrorCode.INSIGHT_SERVICE_UNAVAILABLE:
        return 'AI洞察暂时不可用，请稍后重试';
      case ErrorCode.INSIGHT_GENERATION_FAILED:
        return 'AI洞察生成失败，请稍后重试';
      case ErrorCode.INSIGHT_INVALID_RESPONSE:
        return '洞察数据格式错误，请稍后重试';
      case ErrorCode.INSIGHT_CACHE_ERROR:
        return '洞察缓存错误，请稍后重试';

      default:
        return '服务异常，请稍后重试';
    }
  }

  /**
   * 处理错误并返回用户友好的错误消息
   * @param error 错误对象（ArkTS不支持unknown，使用联合类型）
   * @param context 错误发生的上下文
   * @returns 用户友好的错误消息
   */
  static handle(error: Error | object | string | null | undefined, context?: string): AppError {
    // 记录详细错误信息用于调试
    console.error(`[ErrorHandler] ${context || 'Unknown Context'}:`, error);

    // 如果已经是AppError，直接返回
    if (error instanceof AppError) {
      return error;
    }

    // 处理网络错误
    if (ErrorHandler.isNetworkError(error)) {
      // 过滤 undefined，确保类型匹配
      const originalError: Error | object | string | null = 
        (error === undefined || error === null) ? null : 
        (typeof error === 'string' ? error : (error as Error | object));
      return new AppError(
        ErrorCode.NETWORK_ERROR,
        `Network error in ${context}`,
        ErrorHandler.getErrorMessage(ErrorCode.NETWORK_ERROR),
        { originalError: originalError }
      );
    }

    // 处理API错误
    if (ErrorHandler.isApiError(error)) {
      // 确保 error 是 object 类型才能调用 getApiErrorCode
      // 如果 error 不是 object，创建一个默认的 ApiErrorObject
      let errorObj: object;
      if (typeof error === 'object' && error !== null) {
        errorObj = error as object;
      } else {
        // 创建一个符合 ApiErrorObject 接口的空对象
        const defaultError: ApiErrorObject = {};
        errorObj = defaultError;
      }
      const errorCode = ErrorHandler.getApiErrorCode(errorObj);
      // 过滤 undefined，确保类型匹配
      const originalError: Error | object | string | null = 
        (error === undefined || error === null) ? null : 
        (typeof error === 'string' ? error : (error as Error | object));
      return new AppError(
        errorCode,
        `API error in ${context}`,
        ErrorHandler.getErrorMessage(errorCode),
        { originalError: originalError }
      );
    }

    // 处理文件相关错误
    if (ErrorHandler.isFileError(error)) {
      // 确保 error 不是 undefined 再调用 getFileErrorCode
      const errorForCode: Error | string | object = 
        (error === undefined || error === null) ? new Error('File error') : 
        (typeof error === 'string' ? error : (error as Error | object));
      const errorCode = ErrorHandler.getFileErrorCode(errorForCode);
      // 过滤 undefined，确保类型匹配
      const originalError: Error | object | string | null = 
        (error === undefined || error === null) ? null : 
        (typeof error === 'string' ? error : (error as Error | object));
      return new AppError(
        errorCode,
        `File error in ${context}`,
        ErrorHandler.getErrorMessage(errorCode),
        { originalError: originalError }
      );
    }

    // 处理通用Error对象
    if (error instanceof Error) {
      return new AppError(
        ErrorCode.SYSTEM_ERROR,
        error.message,
        error.message || ErrorHandler.getErrorMessage(ErrorCode.SYSTEM_ERROR),
        { stack: error.stack }
      );
    }

    // 处理其他未知错误
    return new AppError(
      ErrorCode.UNKNOWN_ERROR,
      'Unknown error occurred',
      ErrorHandler.getErrorMessage(ErrorCode.UNKNOWN_ERROR),
      { originalError: error as Error | object | string | null | undefined }
    );
  }

  /**
   * 判断是否为网络错误
   */
  private static isNetworkError(error: Error | object | string | null | undefined): boolean {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      return message.includes('network') ||
             message.includes('timeout') ||
             message.includes('connection') ||
             message.includes('连接') ||
             message.includes('超时') ||
             message.includes('网络') ||
             message.includes('econnrefused') ||
             message.includes('enotfound') ||
             message.includes('econnreset') ||
             message.includes('etimedout') ||
             message.includes('网络连接失败') ||
             message.includes('网络请求超时');
    } else if (typeof error === 'string') {
      const message = error.toLowerCase();
      return message.includes('network') ||
             message.includes('timeout') ||
             message.includes('connection') ||
             message.includes('连接') ||
             message.includes('超时') ||
             message.includes('网络');
    }
    return false;
  }

  /**
   * 判断是否为API错误
   */
  private static isApiError(error: Error | object | string | null | undefined): boolean {
    if (typeof error === 'object' && error !== null) {
      const errorObj = error as Record<string, string | number | boolean | null | undefined>;
      return errorObj.status !== undefined ||
             errorObj.statusCode !== undefined ||
             errorObj.code !== undefined;
    }
    return false;
  }

  /**
   * 从API错误中获取错误代码
   */
  private static getApiErrorCode(error: object): ErrorCode {
    const errorObj = error as ApiErrorObject;
    const errorCode = errorObj.code;

    if (errorCode) {
      // 验证是否为有效的错误代码
      const validCodes: string[] = [
        ErrorCode.NETWORK_ERROR,
        ErrorCode.API_TIMEOUT,
        ErrorCode.API_ERROR,
        ErrorCode.FILE_TOO_LARGE,
        ErrorCode.FILE_READ_ERROR,
        ErrorCode.FILE_PARSE_ERROR,
        ErrorCode.FILE_NOT_FOUND,
        ErrorCode.INVALID_INPUT,
        ErrorCode.DATA_FORMAT_ERROR,
        ErrorCode.INVALID_JSON_OUTPUT,
        ErrorCode.INVALID_MODEL_OUTPUT,
        ErrorCode.AUTH_ERROR,
        ErrorCode.TOKEN_EXPIRED,
        ErrorCode.USER_NOT_FOUND,
        ErrorCode.CHART_RENDER_ERROR,
        ErrorCode.CHART_EXPORT_ERROR,
        ErrorCode.CHART_CONFIG_INVALID,
        ErrorCode.SYSTEM_ERROR,
        ErrorCode.QWEN_ERROR,
        ErrorCode.INSIGHT_TIMEOUT,
        ErrorCode.INSIGHT_SERVICE_UNAVAILABLE,
        ErrorCode.INSIGHT_GENERATION_FAILED,
        ErrorCode.INSIGHT_INVALID_RESPONSE,
        ErrorCode.INSIGHT_CACHE_ERROR,
        ErrorCode.NOT_FOUND
      ];
      if (validCodes.includes(errorCode)) {
        return errorCode as ErrorCode;
      }
    }

    const status = errorObj.status || errorObj.statusCode;
    if (status === 401) return ErrorCode.AUTH_ERROR;
    if (status === 404) return ErrorCode.FILE_NOT_FOUND;
    if (status === 413) return ErrorCode.FILE_TOO_LARGE;
    if (status && status >= 500) return ErrorCode.SYSTEM_ERROR;
    if (status && status >= 400) return ErrorCode.API_ERROR;

    return ErrorCode.API_ERROR;
  }

  /**
   * 判断是否为文件相关错误
   */
  private static isFileError(error: Error | object | string | null | undefined): boolean {
    if (error instanceof Error) {
      const message = error.message;
      return message.includes('file') ||
             message.includes('File') ||
             message.includes('read') ||
             message.includes('parse') ||
             message.includes('ENOENT') ||
             message.includes('EACCES');
    }
    return false;
  }

  /**
   * 从文件错误中获取错误代码
   */
  private static getFileErrorCode(error: Error | string | object): ErrorCode {
    let message: string;

    if (error instanceof Error) {
      message = error.message.toLowerCase();
    } else if (typeof error === 'string') {
      message = error.toLowerCase();
    } else {
      message = 'unknown file error';
    }

    if (message.includes('too large') || message.includes('size')) {
      return ErrorCode.FILE_TOO_LARGE;
    }
    if (message.includes('not found') || message.includes('enoent')) {
      return ErrorCode.FILE_NOT_FOUND;
    }
    if (message.includes('parse') || message.includes('format')) {
      return ErrorCode.FILE_PARSE_ERROR;
    }

    return ErrorCode.FILE_READ_ERROR;
  }

  /**
   * 上报错误到监控系统（可选实现）
   */
  static reportError(error: AppError): void {
    // 这里可以集成错误上报服务
    // 注意：ArkTS不支持对象字面量作为类型，需要明确类型
    interface ErrorReport {
      code: ErrorCode;
      message: string;
      userMessage?: string;
      details?: ErrorDetails;
      timestamp: string;
    }
    const report: ErrorReport = {
      code: error.code,
      message: error.message,
      userMessage: error.userMessage,
      details: error.details,
      timestamp: new Date().toISOString()
    };
    console.warn('[ErrorHandler] Error reported:', report);
  }
}