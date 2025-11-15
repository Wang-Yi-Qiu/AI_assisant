/**
 * 认证服务：处理用户登录、注册和会话管理
 * @module authService
 */

import { getAppConfig } from './config';
import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';

export interface User {
  id: string;
  email: string;
  created_at?: string;
}

// Supabase specific interfaces
interface SupabaseUser {
  id: string;
  email: string;
  created_at?: string;
}

interface SupabaseSession {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
}

interface SupabaseAuthResponse {
  user?: SupabaseUser;
  session?: SupabaseSession;
  access_token?: string;
}

interface SupabaseErrorResponse {
  msg?: string;
  error?: string;
  error_description?: string;
}

interface AuthRequestHeaders {
  'Content-Type': string;
  'apikey': string;
  'Authorization': string;
}

// 注册和登录请求数据接口
interface SignUpRequestData {
  email: string;
  password: string;
  gotrue_meta_security: GotrueMetaSecurity;
}

interface SignInRequestData {
  email: string;
  password: string;
}

interface GotrueMetaSecurity {
  captcha_token: string;
}

interface RefreshTokenRequestData {
  refresh_token: string;
}

// 认证响应结果接口
interface AuthResult {
  user: User | null;
  error: Error | null;
}

interface AuthSessionResult {
  error: Error | null;
}

// 用户查询结果接口
interface UserSessionResult {
  user: User | null;
  error: Error | null;
}

export interface AuthState {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
}

export interface SignInCredentials {
  email: string;
  password: string;
}

export interface SignUpCredentials {
  email: string;
  password: string;
}

// 导出认证结果接口供其他文件使用
export { AuthResult, AuthSessionResult, UserSessionResult };

interface AuthRequestOptions {
  method: string;
  body?: string;
}

class AuthService {
  private currentUser: User | null = null;
  private sessionToken: string | null = null;

  /**
   * 获取当前认证状态
   */
  getAuthState(): AuthState {
    return {
      user: this.currentUser,
      isLoading: false,
      isAuthenticated: !!this.currentUser && !!this.sessionToken
    };
  }

  /**
   * 获取当前用户
   */
  getCurrentUser(): User | null {
    return this.currentUser;
  }

  /**
   * 获取会话令牌
   */
  getSessionToken(): string | null {
    return this.sessionToken;
  }

  /**
   * 用户注册
   */
  async signUp(credentials: SignUpCredentials): Promise<AuthResult> {
    try {
      const requestData: SignUpRequestData = {
        email: credentials.email,
        password: credentials.password,
        gotrue_meta_security: {
          captcha_token: ''
        }
      };

      const options: AuthRequestOptions = {
        method: 'POST',
        body: JSON.stringify(requestData)
      };

      const response = await this.makeAuthRequest('/auth/v1/signup', options);

      if (response.responseCode === 200) {
        const result = this.parseAuthResponse(response.result as string);

        if (result.user && result.session) {
          this.currentUser = {
            id: result.user.id,
            email: result.user.email,
            created_at: result.user.created_at
          };
          this.sessionToken = result.session.access_token;

          return { user: this.currentUser, error: null };
        }
      } else {
        const errorData = this.parseErrorResponse(response.result as string);
        const errorMsg = errorData.msg || errorData.error || '注册失败';
        throw new Error(errorMsg);
      }

      return { user: null, error: new Error('注册失败') };
    } catch (error) {
      console.error('注册失败:', error);
      const authError = error instanceof Error ? error : new Error('注册失败');
      return { user: null, error: authError };
    }
  }

  /**
   * 用户登录
   */
  async signIn(credentials: SignInCredentials): Promise<AuthResult> {
    try {
      const requestData: SignInRequestData = {
        email: credentials.email,
        password: credentials.password
      };

      const options: AuthRequestOptions = {
        method: 'POST',
        body: JSON.stringify(requestData)
      };

      const response = await this.makeAuthRequest('/auth/v1/token?grant_type=password', options);

      if (response.responseCode === 200) {
        const result = this.parseAuthResponse(response.result as string);

        if (result.user && result.access_token) {
          this.currentUser = {
            id: result.user.id,
            email: result.user.email,
            created_at: result.user.created_at
          };
          this.sessionToken = result.access_token;

          return { user: this.currentUser, error: null };
        }
      } else {
        const errorData = this.parseErrorResponse(response.result as string);
        const errorMsg = errorData.msg || errorData.error || '登录失败';
        throw new Error(errorMsg);
      }

      return { user: null, error: new Error('登录失败') };
    } catch (error) {
      console.error('登录失败:', error);
      const authError = error instanceof Error ? error : new Error('登录失败');
      return { user: null, error: authError };
    }
  }

  /**
   * 用户登出
   */
  async signOut(): Promise<AuthSessionResult> {
    try {
      if (this.sessionToken) {
        const options: AuthRequestOptions = {
          method: 'POST'
        };
        await this.makeAuthRequest('/auth/v1/logout', options);
      }

      this.currentUser = null;
      this.sessionToken = null;

      return { error: null };
    } catch (error) {
      console.error('登出失败:', error);
      // 即使网络请求失败，也要清除本地状态
      this.currentUser = null;
      this.sessionToken = null;
      const authError = error instanceof Error ? error : new Error('登出失败');
      return { error: authError };
    }
  }

  /**
   * 刷新会话
   */
  async refreshSession(): Promise<AuthSessionResult> {
    try {
      if (!this.sessionToken) {
        throw new Error('没有有效的会话令牌');
      }

      const requestData: RefreshTokenRequestData = {
        refresh_token: this.sessionToken
      };

      const options: AuthRequestOptions = {
        method: 'POST',
        body: JSON.stringify(requestData)
      };

      const response = await this.makeAuthRequest('/auth/v1/token?grant_type=refresh_token', options);

      if (response.responseCode === 200) {
        const result = this.parseAuthResponse(response.result as string);

        if (result.access_token && result.user) {
          this.sessionToken = result.access_token;
          this.currentUser = {
            id: result.user.id,
            email: result.user.email,
            created_at: result.user.created_at
          };
        }
      }

      return { error: null };
    } catch (error) {
      console.error('刷新会话失败:', error);
      this.currentUser = null;
      this.sessionToken = null;
      const authError = error instanceof Error ? error : new Error('刷新会话失败');
      return { error: authError };
    }
  }

  /**
   * 检查会话状态
   */
  async checkSession(): Promise<UserSessionResult> {
    try {
      if (!this.sessionToken) {
        return { user: null, error: null };
      }

      const options: AuthRequestOptions = {
        method: 'GET'
      };

      const response = await this.makeAuthRequest('/auth/v1/user', options);

      if (response.responseCode === 200) {
        const result = this.parseAuthResponse(response.result as string);
        if (result.user) {
          this.currentUser = {
            id: result.user.id,
            email: result.user.email,
            created_at: result.user.created_at
          };
          return { user: this.currentUser, error: null };
        } else {
          this.currentUser = null;
          this.sessionToken = null;
          return { user: null, error: new Error('用户信息解析失败') };
        }
      } else {
        this.currentUser = null;
        this.sessionToken = null;
        return { user: null, error: new Error('会话已过期') };
      }
    } catch (error) {
      console.error('检查会话失败:', error);
      this.currentUser = null;
      this.sessionToken = null;
      const authError = error instanceof Error ? error : new Error('检查会话失败');
      return { user: null, error: authError };
    }
  }

  /**
   * 发起认证请求的通用方法
   */
  private async makeAuthRequest(path: string, options: AuthRequestOptions): Promise<http.HttpResponse> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const anonKey = cfg.supabaseAnonKey || '';

    const url = `${supabaseUrl}${path}`;
    const httpRequest = http.createHttp();

    try {
      const headers: AuthRequestHeaders = {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': this.sessionToken ? `Bearer ${this.sessionToken}` : `Bearer ${anonKey}`,
      };

      // httpRequest.request 可能抛出异常，已在外部try-catch中处理
      const response = await httpRequest.request(url, {
        method: options.method as http.RequestMethod || http.RequestMethod.GET,
        header: headers,
        extraData: options.body,
        readTimeout: 10000,
        connectTimeout: 6000,
      });

      return response;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 获取用户ID（用于数据库查询）
   */
  getUserId(): string {
    return this.currentUser?.id || 'anonymous';
  }

  /**
   * 解析认证响应
   */
  private parseAuthResponse(response: string): SupabaseAuthResponse {
    try {
      return JSON.parse(response) as SupabaseAuthResponse;
    } catch (error) {
      throw new Error('响应解析失败');
    }
  }

  /**
   * 解析错误响应
   */
  private parseErrorResponse(response: string): SupabaseErrorResponse {
    try {
      return JSON.parse(response) as SupabaseErrorResponse;
    } catch (error) {
      return { msg: '未知错误' };
    }
  }
}

// 导出单例实例
export const authService = new AuthService();