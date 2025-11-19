/**
 * 配额服务：查询和管理用户 API 调用配额
 * @module quotaService
 */

import { getSupabaseUrl, getSupabaseAnonKey } from './supabaseClient';
import { authService } from './authService';
import http from '@ohos.net.http';

export interface UserQuota {
  total: number;
  used: number;
  remaining: number;
}

/**
 * 获取用户配额信息
 * @returns Promise<UserQuota | null> 配额信息，如果查询失败返回 null
 */
export async function getUserQuota(): Promise<UserQuota | null> {
  try {
    const baseUrl = getSupabaseUrl().replace(/\/$/, '');
    const anonKey = getSupabaseAnonKey();
    const userId = authService.getUserId();
    const sessionToken = authService.getSessionToken();

    if (!anonKey) {
      console.warn('[quotaService] 缺少 Supabase anon key');
      return null;
    }

    if (!userId || userId === 'anonymous') {
      // 匿名用户无法查询配额
      return null;
    }

    const url = `${baseUrl}/rest/v1/user_quotas?user_id=eq.${encodeURIComponent(userId)}&select=*`;
    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'apikey': anonKey,
          'Authorization': `Bearer ${sessionToken || anonKey}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000,
      });

      httpRequest.destroy();

      if (response.responseCode < 200 || response.responseCode >= 300) {
        console.warn(`[quotaService] 查询配额失败: ${response.responseCode}`);
        return null;
      }

      interface QuotaRow {
        total_quota?: number;
        used_quota?: number;
      }
      
      const text = String(response.result || '[]');
      const quotas = JSON.parse(text) as Array<QuotaRow>;

      if (quotas && quotas.length > 0) {
        const quota = quotas[0];
        const total = quota.total_quota || 10;
        const used = quota.used_quota || 0;
        return {
          total: total,
          used: used,
          remaining: total - used
        };
      } else {
        // 如果没有配额记录，返回默认值（首次使用）
        return {
          total: 10,
          used: 0,
          remaining: 10
        };
      }
    } catch (requestError) {
      httpRequest.destroy();
      if (requestError instanceof Error) {
        throw requestError;
      } else {
        throw new Error(String(requestError));
      }
    }
  } catch (error) {
    console.error('[quotaService] 获取配额失败:', error);
    return null;
  }
}

