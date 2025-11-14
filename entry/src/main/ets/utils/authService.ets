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
  async signUp(credentials: SignUpCredentials): Promise<{ user: User | null; error: Error | null }> {
    try {
      const response = await this.makeAuthRequest('/auth/v1/signup', {
        method: 'POST',
        body: JSON.stringify({
          email: credentials.email,
          password: credentials.password,
          gotrue_meta_security: {
            captcha_token: ''
          }
        })
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);
        const user = result.user;

        if (user && result.session) {
          this.currentUser = {
            id: user.id,
            email: user.email,
            created_at: user.created_at
          };
          this.sessionToken = result.session.access_token;

          return { user: this.currentUser, error: null };
        }
      } else {
        const errorData = JSON.parse(response.result as string);
        throw new Error(errorData.msg || '注册失败');
      }

      return { user: null, error: new Error('注册失败') };
    } catch (error) {
      console.error('注册失败:', error);
      return { user: null, error: error instanceof Error ? error : new Error('注册失败') };
    }
  }

  /**
   * 用户登录
   */
  async signIn(credentials: SignInCredentials): Promise<{ user: User | null; error: Error | null }> {
    try {
      const response = await this.makeAuthRequest('/auth/v1/token?grant_type=password', {
        method: 'POST',
        body: JSON.stringify({
          email: credentials.email,
          password: credentials.password
        })
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);

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
        const errorData = JSON.parse(response.result as string);
        throw new Error(errorData.msg || '登录失败');
      }

      return { user: null, error: new Error('登录失败') };
    } catch (error) {
      console.error('登录失败:', error);
      return { user: null, error: error instanceof Error ? error : new Error('登录失败') };
    }
  }

  /**
   * 用户登出
   */
  async signOut(): Promise<{ error: Error | null }> {
    try {
      if (this.sessionToken) {
        await this.makeAuthRequest('/auth/v1/logout', {
          method: 'POST'
        });
      }

      this.currentUser = null;
      this.sessionToken = null;

      return { error: null };
    } catch (error) {
      console.error('登出失败:', error);
      // 即使网络请求失败，也要清除本地状态
      this.currentUser = null;
      this.sessionToken = null;
      return { error: error instanceof Error ? error : new Error('登出失败') };
    }
  }

  /**
   * 刷新会话
   */
  async refreshSession(): Promise<{ error: Error | null }> {
    try {
      if (!this.sessionToken) {
        throw new Error('没有有效的会话令牌');
      }

      const response = await this.makeAuthRequest('/auth/v1/token?grant_type=refresh_token', {
        method: 'POST',
        body: JSON.stringify({
          refresh_token: this.sessionToken
        })
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string);

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
      return { error: error instanceof Error ? error : new Error('刷新会话失败') };
    }
  }

  /**
   * 检查会话状态
   */
  async checkSession(): Promise<{ user: User | null; error: Error | null }> {
    try {
      if (!this.sessionToken) {
        return { user: null, error: null };
      }

      const response = await this.makeAuthRequest('/auth/v1/user', {
        method: 'GET'
      });

      if (response.responseCode === 200) {
        const user = JSON.parse(response.result as string);
        this.currentUser = {
          id: user.id,
          email: user.email,
          created_at: user.created_at
        };
        return { user: this.currentUser, error: null };
      } else {
        this.currentUser = null;
        this.sessionToken = null;
        return { user: null, error: new Error('会话已过期') };
      }
    } catch (error) {
      console.error('检查会话失败:', error);
      this.currentUser = null;
      this.sessionToken = null;
      return { user: null, error: error instanceof Error ? error : new Error('检查会话失败') };
    }
  }

  /**
   * 发起认证请求的通用方法
   */
  private async makeAuthRequest(path: string, options: {
    method: string;
    body?: string;
  }): Promise<http.Response> {
    const cfg = getAppConfig();
    const supabaseUrl = cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
    const anonKey = cfg.supabaseAnonKey || '';

    const url = `${supabaseUrl}${path}`;
    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(url, {
        method: options.method,
        header: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': this.sessionToken ? `Bearer ${this.sessionToken}` : `Bearer ${anonKey}`,
        },
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
}

// 导出单例实例
export const authService = new AuthService();