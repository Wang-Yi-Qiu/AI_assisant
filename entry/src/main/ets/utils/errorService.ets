import promptAction from '@ohos.promptAction';

/**
 * 错误类型枚举
 */
export enum ErrorType {
  NETWORK = 'network',
  STORAGE = 'storage',
  PERMISSION = 'permission',
  VALIDATION = 'validation',
  UNKNOWN = 'unknown'
}

/**
 * 错误信息接口
 */
export interface ErrorInfo {
  type: ErrorType;
  message: string;
  userMessage: string;
  timestamp: number;
}

/**
 * 用户友好的错误提示服务
 */
export class UserFriendlyErrorService {
  private static instance: UserFriendlyErrorService | null = null;
  private errorHistory: ErrorInfo[] = [];

  private constructor() {}

  static getInstance(): UserFriendlyErrorService {
    if (!UserFriendlyErrorService.instance) {
      UserFriendlyErrorService.instance = new UserFriendlyErrorService();
    }
    return UserFriendlyErrorService.instance;
  }

  /**
   * 显示用户友好的错误提示
   */
  showError(error: Error | string, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): void {
    let errorInfo: ErrorInfo;

    if (typeof error === 'string') {
      errorInfo = {
        type,
        message: error,
        userMessage: this.getUserFriendlyMessage(error, type, context),
        timestamp: Date.now()
      };
    } else {
      errorInfo = {
        type,
        message: error.message || String(error),
        userMessage: this.getUserFriendlyMessage(error.message || String(error), type, context),
        timestamp: Date.now()
      };
    }

    // 记录错误
    this.errorHistory.push(errorInfo);

    // 限制错误历史记录数量
    if (this.errorHistory.length > 50) {
      this.errorHistory = this.errorHistory.slice(-50);
    }

    // 显示Toast提示
    this.showToast(errorInfo.userMessage);

    // 记录到控制台
    console.error(`[${type.toUpperCase()}] ${context ? `[${context}] ` : ''}${errorInfo.message}`);
  }

  /**
   * 显示成功提示
   */
  showSuccess(message: string): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 2000,
        bottom: '50%'
      });
    } catch (error) {
      console.error('ErrorService: Failed to show success toast', error);
    }
    console.info(`[SUCCESS] ${message}`);
  }

  /**
   * 显示加载提示
   */
  showLoading(message: string = '加载中...'): void {
    try {
      promptAction.showDialog({
        title: '请稍候',
        message: message,
        buttons: [
          {
            text: '取消',
            color: '#999999'
          }
        ]
      });
    } catch (error) {
      console.error('ErrorService: Failed to show loading dialog', error);
    }
  }

  /**
   * 显示确认对话框
   */
  async showConfirm(title: string, message: string): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: title,
        message: message,
        buttons: [
          {
            text: '取消',
            color: '#999999'
          },
          {
            text: '确定',
            color: '#007DFF'
          }
        ]
      });
      return result.index === 1; // 第二个按钮（确定）的索引是1
    } catch (error) {
      console.error('显示确认对话框失败:', error);
      return false;
    }
  }

  /**
   * 显示Toast提示
   */
  private showToast(message: string): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 3000,
        bottom: '50%'
      });
    } catch (error) {
      console.error('ErrorService: Failed to show toast', error);
    }
  }

  /**
   * 获取用户友好的错误信息
   */
  private getUserFriendlyMessage(error: string, type: ErrorType, context: string): string {
    switch (type) {
      case ErrorType.NETWORK:
        return '网络连接异常，请检查网络设置后重试';
      case ErrorType.STORAGE:
        return '数据保存失败，请检查存储空间或重试';
      case ErrorType.PERMISSION:
        return '缺少必要权限，请在设置中开启相关权限';
      case ErrorType.VALIDATION:
        return '输入数据不正确，请检查后重新输入';
      default:
        // 尝试根据错误内容提供更具体的提示
        if (error.includes('storage') || error.includes('存储')) {
          return '数据保存失败，请重试';
        } else if (error.includes('network') || error.includes('网络') || error.includes('connection')) {
          return '网络连接异常，请检查网络设置';
        } else if (error.includes('permission') || error.includes('权限')) {
          return '权限不足，请在设置中开启相关权限';
        } else if (error.includes('timeout') || error.includes('超时')) {
          return '操作超时，请重试';
        } else {
          return '操作失败，请重试';
        }
    }
  }

  /**
   * 获取错误历史
   */
  getErrorHistory(): ErrorInfo[] {
    return [...this.errorHistory];
  }

  /**
   * 清空错误历史
   */
  clearErrorHistory(): void {
    this.errorHistory = [];
  }

  /**
   * 获取最近的错误
   */
  getLastError(): ErrorInfo | null {
    return this.errorHistory.length > 0 ? this.errorHistory[this.errorHistory.length - 1] : null;
  }

  /**
   * 检查是否有特定类型的错误
   */
  hasErrorType(type: ErrorType): boolean {
    return this.errorHistory.some(error => error.type === type);
  }
}

/**
 * 全局错误处理函数
 */
export function handleError(error: Error | string, type: ErrorType = ErrorType.UNKNOWN, context: string = ''): void {
  UserFriendlyErrorService.getInstance().showError(error, type, context);
}

/**
 * 快捷函数：网络错误
 */
export function handleNetworkError(error: Error | string, context: string = ''): void {
  handleError(error, ErrorType.NETWORK, context);
}

/**
 * 快捷函数：存储错误
 */
export function handleStorageError(error: Error | string, context: string = ''): void {
  handleError(error, ErrorType.STORAGE, context);
}

/**
 * 快捷函数：权限错误
 */
export function handlePermissionError(error: Error | string, context: string = ''): void {
  handleError(error, ErrorType.PERMISSION, context);
}

/**
 * 快捷函数：验证错误
 */
export function handleValidationError(error: Error | string, context: string = ''): void {
  handleError(error, ErrorType.VALIDATION, context);
}

/**
 * 快捷函数：成功提示
 */
export function showSuccess(message: string): void {
  UserFriendlyErrorService.getInstance().showSuccess(message);
}

/**
 * 快捷函数：确认对话框
 */
export async function showConfirm(title: string, message: string): Promise<boolean> {
  return UserFriendlyErrorService.getInstance().showConfirm(title, message);
}