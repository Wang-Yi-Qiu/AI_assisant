/**
 * 异步操作管理器
 * 提供请求取消、并发控制、重试机制等功能
 * @module asyncManager
 */

import { ErrorHandler, AppError, ErrorCode } from './errorHandler';

// 自定义取消令牌，替代AbortSignal
export interface CancellationToken {
  cancelled: boolean;
  cancel(): void;
}

export interface AsyncOptions {
  timeout?: number; // 超时时间（毫秒）
  retryCount?: number; // 重试次数
  retryDelay?: number; // 重试延迟（毫秒）
  token?: CancellationToken; // 取消令牌
  onProgress?: (progress: number) => void; // 进度回调
}

export interface AsyncTask<T> {
  id: string;
  promise: Promise<T>;
  cancel: () => void;
  isCompleted: boolean;
  isCancelled: boolean;
}

// 扩展选项接口，用于并发控制
interface ExecuteAllOptions extends AsyncOptions {
  concurrency?: number;
}

class CancellationTokenImpl implements CancellationToken {
  public cancelled = false;

  cancel(): void {
    this.cancelled = true;
  }
}

export class AsyncManager {
  private static instance: AsyncManager;
  private activeTasks: Map<string, CancellationTokenImpl> = new Map();
  private taskCounter = 0;

  static getInstance(): AsyncManager {
    if (!AsyncManager.instance) {
      AsyncManager.instance = new AsyncManager();
    }
    return AsyncManager.instance;
  }

  /**
   * 执行带超时和重试的异步任务
   * @param taskFn 任务函数
   * @param options 执行选项
   */
  async execute<T>(
    taskFn: (token: CancellationToken) => Promise<T>,
    options: AsyncOptions = {}
  ): Promise<T> {
    const timeout = options.timeout || 30000; // 默认30秒超时
    const retryCount = options.retryCount || 2; // 默认重试2次
    const retryDelay = options.retryDelay || 1000; // 默认重试延迟1秒
    const token = options.token;
    const onProgress = options.onProgress;

    let lastError: Error | AppError | null = null;

    for (let attempt = 0; attempt <= retryCount; attempt++) {
      const taskId = this.generateTaskId();

      try {
        // 创建取消令牌
        const controller: CancellationTokenImpl = token as CancellationTokenImpl || new CancellationTokenImpl();
        const finalToken: CancellationToken = controller;

        // 注册任务
        this.activeTasks.set(taskId, controller);

        // 创建超时Promise
        const timeoutPromise: Promise<never> | null = timeout > 0 ? this.createTimeoutPromise(timeout, finalToken) : null;

        // 执行任务
        const taskPromise: Promise<T> = taskFn(finalToken);

        // 等待任务完成或超时
        let result: T;
        if (timeoutPromise) {
          result = await this.racePromises<T>(taskPromise, timeoutPromise);
        } else {
          result = await taskPromise;
        }

        // 任务成功完成
        this.activeTasks.delete(taskId);
        return result;

      } catch (error) {
        const errorObj: Error | AppError = error instanceof Error ? error : new Error(String(error));
        lastError = errorObj;

        // 如果是取消操作，直接抛出错误
        if (errorObj.message.includes('cancelled')) {
          throw new AppError(
            ErrorCode.API_TIMEOUT,
            'Operation cancelled',
            '操作已取消'
          );
        }

        // 如果是最后一次尝试，直接抛出错误
        if (attempt === retryCount) {
          break;
        }

        // 等待重试延迟
        if (retryDelay > 0) {
          await this.delay(retryDelay);
        }

        // 报告进度
        if (onProgress) {
          const progress: number = (attempt + 1) / (retryCount + 1) * 50; // 最多50%进度用于重试
          onProgress(progress);
        }
      } finally {
        this.activeTasks.delete(taskId);
      }
    }

    // 所有重试都失败了，抛出最后的错误
    throw ErrorHandler.handle(lastError, 'AsyncManager.execute');
  }

  /**
   * 创建可取消的异步任务
   * @param taskFn 任务函数
   * @param options 选项
   */
  createTask<T>(
    taskFn: (token: CancellationToken) => Promise<T>,
    options: AsyncOptions = {}
  ): AsyncTask<T> {
    const taskId = this.generateTaskId();
    const controller = new CancellationTokenImpl();

    const executeOptions: AsyncOptions = {
      timeout: options.timeout,
      retryCount: options.retryCount,
      retryDelay: options.retryDelay,
      onProgress: options.onProgress,
      token: controller
    };

    const promise: Promise<T> = this.execute<T>(taskFn, executeOptions);

    const task: AsyncTask<T> = {
      id: taskId,
      promise,
      cancel: () => {
        controller.cancel();
        this.activeTasks.delete(taskId);
      },
      isCompleted: false,
      isCancelled: false
    };

    // 监听任务完成状态
    promise
      .then(() => {
        task.isCompleted = true;
      })
      .catch(() => {
        // 错误也视为完成
        task.isCompleted = true;
      })
      .finally(() => {
        this.activeTasks.delete(taskId);
      });

    return task;
  }

  /**
   * 并发执行多个任务
   * @param taskFns 任务函数数组
   * @param options 选项
   */
  async executeAll<T>(
    taskFns: Array<(token: CancellationToken) => Promise<T>>,
    options: ExecuteAllOptions = {}
  ): Promise<T[]> {
    const concurrency = options.concurrency || 3;

    if (taskFns.length === 0) {
      return [];
    }

    const executeOptions: AsyncOptions = {
      timeout: options.timeout,
      retryCount: options.retryCount,
      retryDelay: options.retryDelay,
      onProgress: options.onProgress,
      token: options.token
    };

    if (concurrency >= taskFns.length) {
      // 并发数足够，直接并行执行
      const results: T[] = [];
      for (let i = 0; i < taskFns.length; i++) {
        const result: T = await this.execute<T>(taskFns[i], executeOptions);
        results.push(result);
      }
      return results;
    }

    // 控制并发数量
    const results: T[] = [];
    const promises: Promise<T>[] = [];

    for (let i = 0; i < taskFns.length; i++) {
      if (promises.length < concurrency) {
        promises.push(this.execute<T>(taskFns[i], executeOptions));
      } else {
        // 等待一个任务完成
        const completedResult: T = await Promise.race(promises);
        results.push(completedResult);

        // 移除第一个已完成的promise并添加新的
        let foundIndex: number = -1;
        for (let j = 0; j < promises.length; j++) {
          if (promises[j] === Promise.resolve(completedResult)) {
            foundIndex = j;
            break;
          }
        }
        if (foundIndex >= 0) {
          promises.splice(foundIndex, 1);
        }
        promises.push(this.execute<T>(taskFns[i], executeOptions));
      }
    }

    // 等待剩余任务完成
    const remainingResults: T[] = await Promise.all(promises);
    results.push(...remainingResults);

    return results;
  }

  /**
   * 取消所有活跃任务
   */
  cancelAllTasks(): void {
    for (const controller of this.activeTasks.values()) {
      controller.cancel();
    }
    this.activeTasks.clear();
  }

  /**
   * 获取活跃任务数量
   */
  getActiveTaskCount(): number {
    return this.activeTasks.size;
  }

  /**
   * 创建超时Promise
   */
  private createTimeoutPromise(timeoutMs: number, token: CancellationToken): Promise<never> {
    return new Promise<never>((_, reject) => {
      const timeoutId: number = setTimeout(() => {
        reject(new AppError(
          ErrorCode.API_TIMEOUT,
          `Operation timed out after ${timeoutMs}ms`,
          '操作超时，请稍后重试'
        ));
      }, timeoutMs);

      // 监听取消信号
      if (token) {
        const checkCancel: number = setInterval(() => {
          if (token.cancelled) {
            clearTimeout(timeoutId);
            clearInterval(checkCancel);
            reject(new Error('Operation cancelled'));
          }
        }, 100);
      }
    });
  }

  /**
   * 替代Promise.race
   */
  private async racePromises<T>(promise1: Promise<T>, promise2: Promise<never>): Promise<T> {
    let completed: boolean = false;

    return new Promise<T>((resolve, reject) => {
      promise1.then((result: T) => {
        if (!completed) {
          completed = true;
          resolve(result);
        }
      }).catch((error: Error | object | string) => {
        if (!completed) {
          completed = true;
          reject(error);
        }
      });

      promise2.catch((error: Error | object | string) => {
        if (!completed) {
          completed = true;
          reject(error);
        }
      });
    });
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 生成任务ID
   */
  private generateTaskId(): string {
    return `task_${++this.taskCounter}_${Date.now()}`;
  }

  /**
   * 防抖函数
   * @param fn 要防抖的函数
   * @param delay 延迟时间
   */
  debounce<T extends (...args: Array<object | string | number | boolean | null | undefined>) => object | string | number | boolean | null | undefined>(
    fn: T,
    delay: number
  ): (...args: Array<object | string | number | boolean | null | undefined>) => void {
    let timeoutId: number | null = null;

    return (...args: Array<object | string | number | boolean | null | undefined>): void => {
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout(() => {
        fn(...args);
        timeoutId = null;
      }, delay);
    };
  }

  /**
   * 节流函数
   * @param fn 要节流的函数
   * @param delay 延迟时间
   */
  throttle<T extends (...args: Array<object | string | number | boolean | null | undefined>) => object | string | number | boolean | null | undefined>(
    fn: T,
    delay: number
  ): (...args: Array<object | string | number | boolean | null | undefined>) => void {
    let lastCall: number = 0;

    return (...args: Array<object | string | number | boolean | null | undefined>): void => {
      const now: number = Date.now();
      if (now - lastCall >= delay) {
        fn(...args);
        lastCall = now;
      }
    };
  }
}

// 导出单例实例
export const asyncManager = AsyncManager.getInstance();