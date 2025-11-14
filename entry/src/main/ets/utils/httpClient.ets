/**
 * HTTP客户端封装：提供统一的HTTP请求处理，包含内存管理和错误处理
 * @module httpClient
 */

import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import { getAppConfig } from './config';

export interface HttpClientConfig {
  timeout?: number;
  retries?: number;
  retryDelay?: number;
}

export interface HttpResponse {
  status: number;
  data: string | object;
  headers?: Record<string, string>;
}

export interface RequestOptions {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  timeout?: number;
}

class HttpClient {
  private readonly defaultConfig: HttpClientConfig;
  private readonly activeRequests: Set<http.HttpRequest> = new Set();

  constructor(config: HttpClientConfig = {}) {
    this.defaultConfig = {
      timeout: 10000,
      retries: 2,
      retryDelay: 1000,
      ...config
    };
  }

  /**
   * 执行HTTP请求
   */
  async request(url: string, options: RequestOptions = {}): Promise<HttpResponse> {
    const finalOptions = {
      method: 'GET',
      timeout: this.defaultConfig.timeout,
      ...options,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...options.headers
      }
    };

    let lastError: Error | null = null;
    let attempt = 0;
    const maxAttempts = (this.defaultConfig.retries || 0) + 1;

    while (attempt < maxAttempts) {
      attempt++;

      try {
        const response = await this.executeRequest(url, finalOptions);
        return response;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        console.warn(`HTTP请求失败 (尝试 ${attempt}/${maxAttempts}):`, lastError.message);

        if (attempt < maxAttempts) {
          // 指数退避
          const delay = this.defaultConfig.retryDelay! * Math.pow(2, attempt - 1);
          await this.sleep(delay);
        }
      }
    }

    throw lastError || new Error('HTTP请求失败');
  }

  /**
   * 执行单个HTTP请求
   */
  private async executeRequest(url: string, options: RequestOptions): Promise<HttpResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();

      // 添加到活跃请求跟踪
      this.activeRequests.add(httpRequest);

      const cleanup = () => {
        this.activeRequests.delete(httpRequest);
        try {
          httpRequest.destroy();
        } catch (error) {
          console.warn('销毁HTTP请求时出错:', error);
        }
      };

      // 设置超时
      const timeoutId = setTimeout(() => {
        cleanup();
        reject(new Error(`HTTP请求超时 (${options.timeout}ms)`));
      }, options.timeout);

      try {
        httpRequest.request(url, {
          method: options.method as http.RequestMethod || http.RequestMethod.GET,
          header: options.headers,
          extraData: options.body,
          readTimeout: options.timeout,
          connectTimeout: Math.min(options.timeout! / 2, 6000),
          expectDataType: http.HttpDataType.STRING,
        }).then((response: http.Response) => {
          clearTimeout(timeoutId);

          const httpResponse: HttpResponse = {
            status: response.responseCode,
            data: response.result as string,
            headers: response.header as Record<string, string>
          };

          if (response.responseCode >= 200 && response.responseCode < 300) {
            cleanup();
            resolve(httpResponse);
          } else {
            cleanup();
            reject(new Error(`HTTP错误: ${response.responseCode}`));
          }
        }).catch((error: BusinessError) => {
          clearTimeout(timeoutId);
          cleanup();
          reject(new Error(`HTTP请求失败: ${error.message}`));
        });
      } catch (error) {
        clearTimeout(timeoutId);
        cleanup();
        reject(error);
      }
    });
  }

  /**
   * GET请求
   */
  async get(url: string, headers?: Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'GET', headers });
  }

  /**
   * POST请求
   */
  async post(url: string, body?: string, headers?: Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'POST', body, headers });
  }

  /**
   * PUT请求
   */
  async put(url: string, body?: string, headers?: Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'PUT', body, headers });
  }

  /**
   * DELETE请求
   */
  async delete(url: string, headers?: Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'DELETE', headers });
  }

  /**
   * 取消所有活跃请求
   */
  cancelAllRequests(): void {
    console.log(`取消 ${this.activeRequests.size} 个活跃HTTP请求`);

    this.activeRequests.forEach((request) => {
      try {
        request.destroy();
      } catch (error) {
        console.warn('取消请求时出错:', error);
      }
    });

    this.activeRequests.clear();
  }

  /**
   * 获取活跃请求数量
   */
  getActiveRequestCount(): number {
    return this.activeRequests.size;
  }

  /**
   * 解析JSON响应
   */
  async parseJsonResponse<T = any>(response: HttpResponse): Promise<T> {
    try {
      if (typeof response.data === 'string') {
        return JSON.parse(response.data) as T;
      } else if (typeof response.data === 'object') {
        return response.data as T;
      } else {
        throw new Error('无法解析JSON响应');
      }
    } catch (error) {
      throw new Error('JSON解析失败: ' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /**
   * 睡眠函数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 创建带认证的请求头
   */
  private createAuthHeaders(sessionToken?: string): Record<string, string> {
    const cfg = getAppConfig();
    const anonKey = cfg.supabaseAnonKey || '';

    return {
      'apikey': anonKey,
      'Authorization': sessionToken ? `Bearer ${sessionToken}` : `Bearer ${anonKey}`,
    };
  }

  /**
   * Supabase认证GET请求
   */
  async supabaseGet(path: string, sessionToken?: string): Promise<HttpResponse> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const url = `${supabaseUrl}${path}`;

    const headers = {
      ...this.createAuthHeaders(sessionToken),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    return this.get(url, headers);
  }

  /**
   * Supabase认证POST请求
   */
  async supabasePost(path: string, body?: string, sessionToken?: string): Promise<HttpResponse> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const url = `${supabaseUrl}${path}`;

    const headers = {
      ...this.createAuthHeaders(sessionToken),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    return this.post(url, body, headers);
  }
}

// 导出单例实例
export const httpClient = new HttpClient({
  timeout: 10000,
  retries: 2,
  retryDelay: 1000
});

// 页面生命周期管理
export class RequestManager {
  private component: string;

  constructor(componentName: string) {
    this.component = componentName;
  }

  /**
   * 页面销毁时清理请求
   */
  cleanup(): void {
    console.log(`清理 ${this.component} 的HTTP请求`);
    httpClient.cancelAllRequests();
  }
}

// 全局错误处理
export function handleHttpError(error: unknown): string {
  if (error instanceof Error) {
    if (error.message.includes('超时')) {
      return '网络请求超时，请检查网络连接';
    } else if (error.message.includes('HTTP错误: 401')) {
      return '认证失败，请重新登录';
    } else if (error.message.includes('HTTP错误: 404')) {
      return '请求的资源不存在';
    } else if (error.message.includes('HTTP错误: 500')) {
      return '服务器内部错误，请稍后重试';
    } else if (error.message.includes('HTTP错误: 504')) {
      return '服务器超时，请稍后重试';
    } else {
      return error.message || '网络请求失败';
    }
  }
  return '网络请求失败，请稍后重试';
}