/**
 * 异步操作管理器
 * 提供请求取消、并发控制、重试机制等功能
 * @module asyncManager
 */

import { ErrorHandler, AppError, ErrorCode } from './errorHandler';

export interface AsyncOptions {
  timeout?: number; // 超时时间（毫秒）
  retryCount?: number; // 重试次数
  retryDelay?: number; // 重试延迟（毫秒）
  signal?: AbortSignal; // 取消信号
  onProgress?: (progress: number) => void; // 进度回调
}

export interface AsyncTask<T> {
  id: string;
  promise: Promise<T>;
  cancel: () => void;
  isCompleted: boolean;
  isCancelled: boolean;
}

export class AsyncManager {
  private static instance: AsyncManager;
  private activeTasks: Map<string, any> = new Map();
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
    taskFn: (signal: AbortSignal) => Promise<T>,
    options: AsyncOptions = {}
  ): Promise<T> {
    const {
      timeout = 30000, // 默认30秒超时
      retryCount = 2, // 默认重试2次
      retryDelay = 1000, // 默认重试延迟1秒
      signal,
      onProgress
    } = options;

    let lastError: Error | AppError | null = null;

    for (let attempt = 0; attempt <= retryCount; attempt++) {
      const taskId = this.generateTaskId();

      try {
        // 创建AbortController用于取消操作
        const controller = new AbortController();
        const finalSignal = signal || controller.signal;

        // 注册任务
        this.activeTasks.set(taskId, controller);

        // 创建超时Promise
        const timeoutPromise = timeout > 0 ? this.createTimeoutPromise(timeout, finalSignal) : null;

        // 执行任务
        const taskPromise = taskFn(finalSignal);

        // 等待任务完成或超时
        const result = timeoutPromise
          ? await Promise.race([taskPromise, timeoutPromise])
          : await taskPromise;

        // 任务成功完成
        this.activeTasks.delete(taskId);
        return result;

      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));

        // 如果是取消操作，直接抛出错误
        if (lastError.name === 'AbortError') {
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
          const progress = (attempt + 1) / (retryCount + 1) * 50; // 最多50%进度用于重试
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
    taskFn: (signal: AbortSignal) => Promise<T>,
    options: AsyncOptions = {}
  ): AsyncTask<T> {
    const taskId = this.generateTaskId();
    const controller = new AbortController();

    const promise = this.execute(taskFn, {
      ...options,
      signal: controller.signal
    });

    const task: AsyncTask<T> = {
      id: taskId,
      promise,
      cancel: () => {
        controller.abort();
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
    taskFns: Array<(signal: AbortSignal) => Promise<T>>,
    options: AsyncOptions & { concurrency?: number } = {}
  ): Promise<T[]> {
    const { concurrency = 3, ...executeOptions } = options;

    if (taskFns.length === 0) {
      return [];
    }

    if (concurrency >= taskFns.length) {
      // 并发数足够，直接并行执行
      const promises = taskFns.map(taskFn =>
        this.execute(taskFn, executeOptions)
      );
      return Promise.all(promises);
    }

    // 控制并发数量
    const results: T[] = [];
    const executing: Promise<void>[] = [];

    for (const taskFn of taskFns) {
      const promise = this.execute(taskFn, executeOptions)
        .then(result => {
          results.push(result);
        });

      executing.push(promise);

      if (executing.length >= concurrency) {
        await Promise.race(executing);
        // 移除已完成的任务
        const stillExecuting = executing.filter(p =>
          p !== Promise.race(executing)
        );
        executing.length = 0;
        executing.push(...stillExecuting);
      }
    }

    await Promise.all(executing);
    return results;
  }

  /**
   * 取消所有活跃任务
   */
  cancelAllTasks(): void {
    for (const controller of this.activeTasks.values()) {
      controller.abort();
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
  private createTimeoutPromise(timeoutMs: number, signal: AbortSignal): Promise<never> {
    return new Promise((_, reject) => {
      const timeoutId = setTimeout(() => {
        reject(new AppError(
          ErrorCode.API_TIMEOUT,
          `Operation timed out after ${timeoutMs}ms`,
          '操作超时，请稍后重试'
        ));
      }, timeoutMs);

      // 监听取消信号
      if (signal) {
        signal.addEventListener('abort', () => {
          clearTimeout(timeoutId);
          reject(new DOMException('Operation cancelled', 'AbortError'));
        });
      }
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
  debounce<T extends (...args: any[]) => any>(
    fn: T,
    delay: number
  ): (...args: Parameters<T>) => void {
    let timeoutId: number | null = null;

    return (...args: Parameters<T>) => {
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
  throttle<T extends (...args: any[]) => any>(
    fn: T,
    delay: number
  ): (...args: Parameters<T>) => void {
    let lastCall = 0;

    return (...args: Parameters<T>) => {
      const now = Date.now();
      if (now - lastCall >= delay) {
        fn(...args);
        lastCall = now;
      }
    };
  }
}

// 导出单例实例
export const asyncManager = AsyncManager.getInstance();