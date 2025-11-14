/**
 * 配置管理测试
 * @module config.test
 */

import { AppConfig, setAppConfig, getAppConfig } from '../../main/ets/utils/config';
import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';

export default function configTest() {
  describe('Config Management Tests', () => {
    const originalConfig = getAppConfig();

    afterEach(() => {
      // 恢复原始配置
      setAppConfig(originalConfig);
    });

    it('should set and get app config', () => {
      const testConfig: AppConfig = {
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-anon-key'
      };

      setAppConfig(testConfig);
      const retrievedConfig = getAppConfig();

      expect(retrievedConfig.supabaseUrl).toBe(testConfig.supabaseUrl);
      expect(retrievedConfig.supabaseAnonKey).toBe(testConfig.supabaseAnonKey);
    });

    it('should handle empty config', () => {
      const emptyConfig: AppConfig = {
        supabaseUrl: '',
        supabaseAnonKey: ''
      };

      setAppConfig(emptyConfig);
      const retrievedConfig = getAppConfig();

      expect(retrievedConfig.supabaseUrl).toBe('');
      expect(retrievedConfig.supabaseAnonKey).toBe('');
    });

    it('should handle partial config updates', () => {
      const partialConfig: Partial<AppConfig> = {
        supabaseAnonKey: 'updated-key'
      };

      setAppConfig({
        ...getAppConfig(),
        ...partialConfig
      });

      const updatedConfig = getAppConfig();
      expect(updatedConfig.supabaseAnonKey).toBe('updated-key');
    });

    it('should provide default values', () => {
      const defaultConfig: AppConfig = {
        supabaseUrl: '',
        supabaseAnonKey: ''
      };

      setAppConfig(defaultConfig);
      const retrievedConfig = getAppConfig();

      expect(typeof retrievedConfig.supabaseUrl).toBe('string');
      expect(typeof retrievedConfig.supabaseAnonKey).toBe('string');
    });
  });
}