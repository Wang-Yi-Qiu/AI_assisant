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

// 使用明确的HTTP头部接口
export interface HttpResponseHeaders {
  'content-type'?: string;
  'content-length'?: string;
  'authorization'?: string;
  'cache-control'?: string;
  'etag'?: string;
}

export type HttpRequestHeaders = Record<string, string>;

export interface HttpResponse {
  status: number;
  data: string | object;
  headers?: HttpResponseHeaders;
}

export interface RequestOptions {
  method?: string;
  headers?: HttpRequestHeaders;
  body?: string;
  timeout?: number;
}

interface AuthHeaders {
  apikey: string;
  Authorization: string;
}

class HttpClient {
  private readonly defaultConfig: HttpClientConfig;
  private readonly activeRequests: Set<http.HttpRequest> = new Set();

  constructor(config: HttpClientConfig = {}) {
    this.defaultConfig = {
      timeout: config.timeout || 10000,
      retries: config.retries || 2,
      retryDelay: config.retryDelay || 1000
    };
  }

  /**
   * 执行HTTP请求
   */
  async request(url: string, options: RequestOptions = {}): Promise<HttpResponse> {
    // 创建基础headers
    const baseHeaders: HttpRequestHeaders = {
      'content-type': 'application/json',
      'accept': 'application/json'
    };

    // 合并用户提供的headers
    const mergedHeaders = this.mergeHeaders(baseHeaders, options.headers);

    const finalOptions: RequestOptions = {
      method: options.method || 'GET',
      timeout: options.timeout || this.defaultConfig.timeout,
      headers: mergedHeaders,
      body: options.body
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
          connectTimeout: Math.min((options.timeout || 0) / 2, 6000),
          expectDataType: http.HttpDataType.STRING,
        }).then((response: http.HttpResponse) => {
          clearTimeout(timeoutId);

          const httpResponse: HttpResponse = {
            status: response.responseCode,
            data: response.result as string,
            headers: this.convertResponseHeaders(response.header)
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

    const requests = Array.from(this.activeRequests.values());
    for (let i = 0; i < requests.length; i++) {
      const request = requests[i];
      try {
        request.destroy();
      } catch (error) {
        console.warn('取消请求时出错:', error);
      }
    }

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
  async parseJsonResponse<T = object>(response: HttpResponse): Promise<T> {
    try {
      if (typeof response.data === 'string') {
        return JSON.parse(response.data) as T;
      } else if (typeof response.data === 'object' && response.data !== null) {
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
   * 合并HTTP头部
   */
  private mergeHeaders(base: HttpRequestHeaders, additional?: HttpRequestHeaders): HttpRequestHeaders {
    const result: HttpRequestHeaders = {};

    // 复制基础headers
    if (base['content-type']) {
      result['content-type'] = base['content-type'];
    }
    if (base['accept']) {
      result['accept'] = base['accept'];
    }
    if (base['authorization']) {
      result['authorization'] = base['authorization'];
    }
    if (base['apikey']) {
      result['apikey'] = base['apikey'];
    }

    // 复制额外的headers
    if (additional) {
      if (additional['content-type']) {
        result['content-type'] = additional['content-type'];
      }
      if (additional['accept']) {
        result['accept'] = additional['accept'];
      }
      if (additional['authorization']) {
        result['authorization'] = additional['authorization'];
      }
      if (additional['apikey']) {
        result['apikey'] = additional['apikey'];
      }
    }

    return result;
  }

  /**
   * 合并HTTP头部和认证头部
   */
  private mergeHeadersWithAuth(base: HttpRequestHeaders, auth: AuthHeaders): HttpRequestHeaders {
    const result: HttpRequestHeaders = {};

    // 复制基础headers
    const contentType = base['content-type'];
    if (contentType) {
      result['content-type'] = contentType;
    }
    const accept = base['accept'];
    if (accept) {
      result['accept'] = accept;
    }
    const authorization = base['authorization'];
    if (authorization) {
      result['authorization'] = authorization;
    }
    const apikey = base['apikey'];
    if (apikey) {
      result['apikey'] = apikey;
    }

    // 复制认证headers（注意：AuthHeaders使用不同的键名）
    result['apikey'] = auth.apikey;
    result['authorization'] = auth.Authorization;

    return result;
  }

  /**
   * 转换响应头部
   */
  private convertResponseHeaders(header?: object): HttpResponseHeaders | undefined {
    if (!header) {
      return undefined;
    }

    const result: HttpResponseHeaders = {};

    // 使用类型断言和可选链操作符避免索引访问
    const headerObj = header as Record<string, string>;

    const contentType = headerObj['content-type'];
    if (contentType) {
      result['content-type'] = contentType;
    }
    const contentLength = headerObj['content-length'];
    if (contentLength) {
      result['content-length'] = contentLength;
    }
    const authorization = headerObj['authorization'];
    if (authorization) {
      result['authorization'] = authorization;
    }
    const cacheControl = headerObj['cache-control'];
    if (cacheControl) {
      result['cache-control'] = cacheControl;
    }
    const etag = headerObj['etag'];
    if (etag) {
      result['etag'] = etag;
    }

    return result;
  }

  /**
   * 创建带认证的请求头
   */
  private createAuthHeaders(sessionToken?: string): AuthHeaders {
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

    const baseHeaders: HttpRequestHeaders = {
      'content-type': 'application/json',
      'accept': 'application/json'
    };

    const authHeaders = this.createAuthHeaders(sessionToken);
    const mergedHeaders = this.mergeHeadersWithAuth(baseHeaders, authHeaders);

    return this.get(url, mergedHeaders);
  }

  /**
   * Supabase认证POST请求
   */
  async supabasePost(path: string, body?: string, sessionToken?: string): Promise<HttpResponse> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const url = `${supabaseUrl}${path}`;

    const baseHeaders: HttpRequestHeaders = {
      'content-type': 'application/json',
      'accept': 'application/json'
    };

    const authHeaders = this.createAuthHeaders(sessionToken);
    const mergedHeaders = this.mergeHeadersWithAuth(baseHeaders, authHeaders);

    return this.post(url, body, mergedHeaders);
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
export function handleHttpError(error: Error | string | object): string {
  let errorMessage: string;

  if (error instanceof Error) {
    errorMessage = error.message;
  } else if (typeof error === 'string') {
    errorMessage = error;
  } else {
    errorMessage = '未知错误';
  }

  if (errorMessage.includes('超时')) {
    return '网络请求超时，请检查网络连接';
  } else if (errorMessage.includes('HTTP错误: 401')) {
    return '认证失败，请重新登录';
  } else if (errorMessage.includes('HTTP错误: 404')) {
    return '请求的资源不存在';
  } else if (errorMessage.includes('HTTP错误: 500')) {
    return '服务器内部错误，请稍后重试';
  } else if (errorMessage.includes('HTTP错误: 504')) {
    return '服务器超时，请稍后重试';
  } else {
    return errorMessage || '网络请求失败';
  }
}