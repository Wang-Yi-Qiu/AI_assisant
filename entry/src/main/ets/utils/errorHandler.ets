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
  QWEN_ERROR = 'QWEN_ERROR'
}

export class AppError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public userMessage?: string,
    public details?: any
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class ErrorHandler {
  private static readonly ERROR_MESSAGES: Record<ErrorCode, string> = {
    [ErrorCode.NETWORK_ERROR]: '网络连接失败，请检查网络设置',
    [ErrorCode.API_TIMEOUT]: '请求超时，请稍后重试',
    [ErrorCode.API_ERROR]: 'API调用失败，请稍后重试',

    [ErrorCode.FILE_TOO_LARGE]: '文件过大，请选择较小的文件',
    [ErrorCode.FILE_READ_ERROR]: '文件读取失败，请检查文件是否损坏',
    [ErrorCode.FILE_PARSE_ERROR]: '文件格式解析失败，请检查文件内容',
    [ErrorCode.FILE_NOT_FOUND]: '未找到指定文件',

    [ErrorCode.INVALID_INPUT]: '输入数据格式无效，请检查数据格式',
    [ErrorCode.DATA_FORMAT_ERROR]: '数据格式错误，请检查数据内容',
    [ErrorCode.INVALID_JSON_OUTPUT]: 'AI返回格式异常，请重试',
    [ErrorCode.INVALID_MODEL_OUTPUT]: 'AI返回的图表配置不符合要求',

    [ErrorCode.AUTH_ERROR]: '认证失败，请重新登录',
    [ErrorCode.TOKEN_EXPIRED]: '登录已过期，请重新登录',
    [ErrorCode.USER_NOT_FOUND]: '用户信息不存在，请重新登录',

    [ErrorCode.CHART_RENDER_ERROR]: '图表渲染失败，请重试',
    [ErrorCode.CHART_EXPORT_ERROR]: '图表导出失败，请重试',
    [ErrorCode.CHART_CONFIG_INVALID]: '图表配置无效',

    [ErrorCode.SYSTEM_ERROR]: '系统异常，请稍后重试',
    [ErrorCode.UNKNOWN_ERROR]: '服务异常，请稍后重试',

    [ErrorCode.QWEN_ERROR]: 'AI服务调用失败，请稍后重试'
  };

  /**
   * 处理错误并返回用户友好的错误消息
   * @param error 错误对象
   * @param context 错误发生的上下文
   * @returns 用户友好的错误消息
   */
  static handle(error: unknown, context?: string): AppError {
    // 记录详细错误信息用于调试
    console.error(`[ErrorHandler] ${context || 'Unknown Context'}:`, error);

    // 如果已经是AppError，直接返回
    if (error instanceof AppError) {
      return error;
    }

    // 处理网络错误
    if (this.isNetworkError(error)) {
      return new AppError(
        ErrorCode.NETWORK_ERROR,
        `Network error in ${context}`,
        this.ERROR_MESSAGES[ErrorCode.NETWORK_ERROR],
        { originalError: error }
      );
    }

    // 处理API错误
    if (this.isApiError(error)) {
      const errorCode = this.getApiErrorCode(error);
      return new AppError(
        errorCode,
        `API error in ${context}`,
        this.ERROR_MESSAGES[errorCode] || this.ERROR_MESSAGES[ErrorCode.API_ERROR],
        { originalError: error }
      );
    }

    // 处理文件相关错误
    if (this.isFileError(error)) {
      const errorCode = this.getFileErrorCode(error);
      return new AppError(
        errorCode,
        `File error in ${context}`,
        this.ERROR_MESSAGES[errorCode],
        { originalError: error }
      );
    }

    // 处理通用Error对象
    if (error instanceof Error) {
      return new AppError(
        ErrorCode.SYSTEM_ERROR,
        error.message,
        error.message || this.ERROR_MESSAGES[ErrorCode.SYSTEM_ERROR],
        { stack: error.stack }
      );
    }

    // 处理其他未知错误
    return new AppError(
      ErrorCode.UNKNOWN_ERROR,
      'Unknown error occurred',
      this.ERROR_MESSAGES[ErrorCode.UNKNOWN_ERROR],
      { originalError: error }
    );
  }

  /**
   * 判断是否为网络错误
   */
  private static isNetworkError(error: unknown): boolean {
    if (error instanceof Error) {
      return error.message.includes('network') ||
             error.message.includes('Network') ||
             error.message.includes('timeout') ||
             error.message.includes('Timeout') ||
             error.message.includes('connection') ||
             error.message.includes('Connection');
    }
    return false;
  }

  /**
   * 判断是否为API错误
   */
  private static isApiError(error: unknown): boolean {
    if (typeof error === 'object' && error !== null) {
      const errorObj = error as any;
      return errorObj.status || errorObj.statusCode || errorObj.code;
    }
    return false;
  }

  /**
   * 从API错误中获取错误代码
   */
  private static getApiErrorCode(error: any): ErrorCode {
    if (error.code && Object.values(ErrorCode).includes(error.code)) {
      return error.code as ErrorCode;
    }

    const status = error.status || error.statusCode;
    if (status === 401) return ErrorCode.AUTH_ERROR;
    if (status === 404) return ErrorCode.NOT_FOUND;
    if (status === 413) return ErrorCode.FILE_TOO_LARGE;
    if (status >= 500) return ErrorCode.SYSTEM_ERROR;
    if (status >= 400) return ErrorCode.API_ERROR;

    return ErrorCode.API_ERROR;
  }

  /**
   * 判断是否为文件相关错误
   */
  private static isFileError(error: unknown): boolean {
    if (error instanceof Error) {
      return error.message.includes('file') ||
             error.message.includes('File') ||
             error.message.includes('read') ||
             error.message.includes('parse') ||
             error.message.includes('ENOENT') ||
             error.message.includes('EACCES');
    }
    return false;
  }

  /**
   * 从文件错误中获取错误代码
   */
  private static getFileErrorCode(error: Error): ErrorCode {
    const message = error.message.toLowerCase();

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
    console.warn('[ErrorHandler] Error reported:', {
      code: error.code,
      message: error.message,
      userMessage: error.userMessage,
      details: error.details,
      timestamp: new Date().toISOString()
    });
  }
}