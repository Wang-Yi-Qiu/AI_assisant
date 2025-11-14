/**
 * HTTP客户端测试
 * @module httpClient.test
 */

import { httpClient, handleHttpError, RequestManager } from '../../main/ets/utils/httpClient';
import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';

export default function httpClientTest() {
  describe('HTTP Client Tests', () => {
    it('should create HTTP client instance', () => {
      expect(httpClient).not().toBeNull();
      expect(httpClient.getActiveRequestCount()).toBe(0);
    });

    it('should handle error messages correctly', () => {
      // 测试超时错误
      const timeoutError = new Error('HTTP请求超时 (10000ms)');
      expect(handleHttpError(timeoutError)).toBe('网络请求超时，请检查网络连接');

      // 测试401错误
      const authError = new Error('HTTP错误: 401');
      expect(handleHttpError(authError)).toBe('认证失败，请重新登录');

      // 测试404错误
      const notFoundError = new Error('HTTP错误: 404');
      expect(handleHttpError(notFoundError)).toBe('请求的资源不存在');

      // 测试通用错误
      const genericError = new Error('网络连接失败');
      expect(handleHttpError(genericError)).toBe('网络连接失败');

      // 测试非Error对象
      const stringError = 'Unknown error';
      expect(handleHttpError(stringError)).toBe('网络请求失败，请稍后重试');
    });

    it('should create request manager', () => {
      const manager = new RequestManager('TestComponent');
      expect(manager).not().toBeNull();
      expect(typeof manager.cleanup).toBe('function');
    });

    it('should handle JSON parsing', async () => {
      const mockResponse = {
        status: 200,
        data: '{"test": "value"}'
      };

      try {
        const result = await httpClient.parseJsonResponse(mockResponse);
        expect(result).toEqual({ test: 'value' });
      } catch (error) {
        expect().fail('JSON解析应该成功');
      }
    });

    it('should handle invalid JSON', async () => {
      const mockResponse = {
        status: 200,
        data: 'invalid json'
      };

      try {
        await httpClient.parseJsonResponse(mockResponse);
        expect().fail('应该抛出解析错误');
      } catch (error) {
        expect(error instanceof Error).toBeTrue();
        expect(error.message).toContain('JSON解析失败');
      }
    });
  });
}