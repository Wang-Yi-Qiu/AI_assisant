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

// 根据HarmonyOS最佳实践，使用Object类型作为headers（避免索引访问问题）
export type HttpResponseHeaders = Record<string, string>;
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
        reject(new Error(`网络请求超时，请检查网络连接 (${options.timeout}ms)`));
      }, options.timeout);

      try {
        // 将headers转换为Record<string, string>格式（过滤undefined值）
        // 注意：ArkTS不支持for...in，需要手动复制已知字段
        const headerRecord: Record<string, string> = {};
        if (options.headers) {
          const headers = options.headers;
          // 手动复制已知的header字段
          if (headers['content-type']) {
            headerRecord['content-type'] = headers['content-type'];
          }
          if (headers['accept']) {
            headerRecord['accept'] = headers['accept'];
          }
          if (headers['authorization']) {
            headerRecord['authorization'] = headers['authorization'];
          }
          if (headers['apikey']) {
            headerRecord['apikey'] = headers['apikey'];
          }
          if (headers['X-User-Api-Key']) {
            headerRecord['X-User-Api-Key'] = headers['X-User-Api-Key'];
          }
          if (headers['X-User-Id']) {
            headerRecord['X-User-Id'] = headers['X-User-Id'];
          }
        }

        httpRequest.request(url, {
          method: options.method as http.RequestMethod || http.RequestMethod.GET,
          header: headerRecord,
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
          // 改进错误消息，确保网络错误被正确识别
          const errorMsg = error.message || String(error);
          const errorCode = error.code || 0;
          console.error('[httpClient] HTTP请求异常:', {
            message: errorMsg,
            code: errorCode,
            error: error
          });
          
          let errorMessage = `HTTP请求失败: ${errorMsg}`;
          
          // 根据错误代码判断网络问题
          if (errorCode === 2300001 || errorMsg.includes('network') || 
              errorMsg.includes('网络') || errorMsg.includes('连接') ||
              errorMsg.includes('timeout') || errorMsg.includes('超时') ||
              errorMsg.includes('ECONNREFUSED') || errorMsg.includes('ENOTFOUND') ||
              errorMsg.includes('DNS') || errorMsg.includes('unreachable')) {
            errorMessage = `网络连接失败: ${errorMsg}。请检查：\n1. 网络连接是否正常\n2. VPN是否影响连接\n3. 防火墙设置\n4. Supabase服务是否可访问`;
          }
          
          // 检查是否是网络连接错误
          const lowerMsg = errorMsg.toLowerCase();
          if (lowerMsg.includes('network') || lowerMsg.includes('timeout') || 
              lowerMsg.includes('connection') || lowerMsg.includes('连接') ||
              lowerMsg.includes('超时') || lowerMsg.includes('网络') ||
              lowerMsg.includes('econnrefused') || lowerMsg.includes('enotfound')) {
            errorMessage = `网络连接失败: ${errorMsg}`;
          }
          
          reject(new Error(errorMessage));
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
  async get(url: string, headers?: HttpRequestHeaders | Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'GET', headers: headers as HttpRequestHeaders });
  }

  /**
   * POST请求
   */
  async post(url: string, body?: string, headers?: HttpRequestHeaders | Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'POST', body, headers: headers as HttpRequestHeaders });
  }

  /**
   * PUT请求
   */
  async put(url: string, body?: string, headers?: HttpRequestHeaders | Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'PUT', body, headers: headers as HttpRequestHeaders });
  }

  /**
   * DELETE请求
   */
  async delete(url: string, headers?: HttpRequestHeaders | Record<string, string>): Promise<HttpResponse> {
    return this.request(url, { method: 'DELETE', headers: headers as HttpRequestHeaders });
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
   * 合并HTTP头部（手动复制字段，ArkTS不支持展开运算符和Object.assign）
   */
  private mergeHeaders(base: HttpRequestHeaders, additional?: HttpRequestHeaders): HttpRequestHeaders {
    const result: HttpRequestHeaders = {};
    
    // 手动复制基础headers
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
    if (base['X-User-Api-Key']) {
      result['X-User-Api-Key'] = base['X-User-Api-Key'];
    }
    
    // 合并额外的headers（优先使用additional的值）
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
      if (additional['X-User-Api-Key']) {
        result['X-User-Api-Key'] = additional['X-User-Api-Key'];
      }
      if (additional['X-User-Id']) {
        result['X-User-Id'] = additional['X-User-Id'];
      }
    }

    return result;
  }

  /**
   * 将HttpRequestHeaders转换为Record<string, string>（过滤undefined值）
   * 注意：HttpRequestHeaders已经是Record<string, string>类型，这里主要用于类型转换
   */
  private headersToRecord(headers: HttpRequestHeaders): Record<string, string> {
    // 手动复制已知字段（ArkTS不支持for...in）
    const result: Record<string, string> = {};
    if (headers['content-type']) {
      result['content-type'] = headers['content-type'];
    }
    if (headers['accept']) {
      result['accept'] = headers['accept'];
    }
    if (headers['authorization']) {
      result['authorization'] = headers['authorization'];
    }
    if (headers['apikey']) {
      result['apikey'] = headers['apikey'];
    }
    return result;
  }

  /**
   * 合并HTTP头部和认证头部（手动复制字段）
   */
  private mergeHeadersWithAuth(base: HttpRequestHeaders, auth: AuthHeaders): HttpRequestHeaders {
    const result: HttpRequestHeaders = {};
    
    // 手动复制基础headers
    if (base['content-type']) {
      result['content-type'] = base['content-type'];
    }
    if (base['accept']) {
      result['accept'] = base['accept'];
    }
    
    // 添加认证headers（优先于基础headers）
    result['apikey'] = auth.apikey;
    result['authorization'] = auth.Authorization;

    return result;
  }

  /**
   * 转换响应头部（手动复制已知字段，ArkTS不支持for...in）
   */
  private convertResponseHeaders(header?: object): HttpResponseHeaders | undefined {
    if (!header) {
      return undefined;
    }

    try {
      // 尝试将header转换为Record类型
      const headerRecord = header as Record<string, string>;
      const result: HttpResponseHeaders = {};
      
      // 手动复制已知的header字段（ArkTS不支持for...in）
      if (headerRecord['content-type']) {
        result['content-type'] = headerRecord['content-type'];
      }
      if (headerRecord['content-length']) {
        result['content-length'] = headerRecord['content-length'];
      }
      if (headerRecord['authorization']) {
        result['authorization'] = headerRecord['authorization'];
      }
      if (headerRecord['cache-control']) {
        result['cache-control'] = headerRecord['cache-control'];
      }
      if (headerRecord['etag']) {
        result['etag'] = headerRecord['etag'];
      }
      
      return result;
    } catch (error) {
      console.warn('转换响应头部失败:', error);
      return undefined;
    }
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
   * @param path 请求路径
   * @param body 请求体
   * @param sessionToken 会话令牌（可选）
   * @param customHeaders 自定义请求头（可选，用于传递用户 API Key 等）
   */
  async supabasePost(path: string, body?: string, sessionToken?: string, customHeaders?: HttpRequestHeaders): Promise<HttpResponse> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const url = `${supabaseUrl}${path}`;

    console.log('[httpClient] ========== 发起Supabase POST请求 ==========');
    console.log('[httpClient] URL:', url);
    console.log('[httpClient] Path:', path);
    console.log('[httpClient] Body长度:', body ? body.length : 0);
    console.log('[httpClient] Body预览:', body ? body.substring(0, 200) : 'null');
    console.log('[httpClient] Has SessionToken:', !!sessionToken);

    const baseHeaders: HttpRequestHeaders = {
      'content-type': 'application/json',
      'accept': 'application/json'
    };

    const authHeaders = this.createAuthHeaders(sessionToken);
    console.log('[httpClient] Auth Headers - Has API Key:', !!authHeaders.apikey);
    console.log('[httpClient] Auth Headers - API Key长度:', authHeaders.apikey ? authHeaders.apikey.length : 0);
    console.log('[httpClient] Auth Headers - Has Authorization:', !!authHeaders.Authorization);
    
    // 合并认证头部
    let mergedHeaders = this.mergeHeadersWithAuth(baseHeaders, authHeaders);
    
    // 合并自定义头部（如果提供），自定义头部优先级更高
    if (customHeaders) {
      mergedHeaders = this.mergeHeaders(mergedHeaders, customHeaders);
      // 手动添加自定义头部中的 X-User-Api-Key（如果存在）
      if (customHeaders['X-User-Api-Key']) {
        mergedHeaders['X-User-Api-Key'] = customHeaders['X-User-Api-Key'];
      }
    }

    try {
      const response = await this.post(url, body, mergedHeaders);
      console.log('[httpClient] 请求成功 - Status:', response.status);
      console.log('[httpClient] Response Data Type:', typeof response.data);
      console.log('[httpClient] Response Data Length:', typeof response.data === 'string' ? response.data.length : 'N/A');
      return response;
    } catch (error) {
      console.error('[httpClient] 请求失败:', error);
      console.error('[httpClient] 错误类型:', error instanceof Error ? error.constructor.name : typeof error);
      console.error('[httpClient] 错误消息:', error instanceof Error ? error.message : String(error));
      // ArkTS限制：throw 语句只能抛出 Error 类型
      throw error instanceof Error ? error : new Error(String(error));
    }
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

  const lowerMessage = errorMessage.toLowerCase();
  
  if (lowerMessage.includes('超时') || lowerMessage.includes('timeout')) {
    return '网络请求超时，请检查网络连接';
  } else if (lowerMessage.includes('网络连接失败') || lowerMessage.includes('network') || 
             lowerMessage.includes('connection') || lowerMessage.includes('连接失败')) {
    return '网络连接失败，请检查网络设置';
  } else if (lowerMessage.includes('http错误: 401') || lowerMessage.includes('认证失败')) {
    return '认证失败，请重新登录';
  } else if (lowerMessage.includes('http错误: 404')) {
    return '请求的资源不存在';
  } else if (lowerMessage.includes('http错误: 500')) {
    return '服务器内部错误，请稍后重试';
  } else if (lowerMessage.includes('http错误: 504')) {
    return '服务器超时，请稍后重试';
  } else {
    return errorMessage || '网络请求失败，请检查网络设置';
  }
}