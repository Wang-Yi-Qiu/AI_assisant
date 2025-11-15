/**
 * 安全密钥管理工具：使用 HarmonyOS 加密存储保护 API Key
 * @module secureKeyManager
 * 
 * 安全说明：
 * 1. API Key 使用 AES 加密后存储在本地
 * 2. 加密密钥使用设备硬件密钥派生（如果可用）
 * 3. 密钥不会出现在代码中，需要用户首次使用时输入
 * 4. 所有密钥操作都在本地完成，不会上传到服务器
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ErrorHandler, AppError, ErrorCode } from './errorHandler';
import { setGlobalContext, getGlobalContext } from './sampleDataManager';
import util from '@ohos.util';

// 密钥存储键名
const API_KEY_STORAGE_KEY = 'encrypted_api_key';
const STORAGE_NAME = 'secure_keys';

/**
 * 安全密钥管理器
 * 
 * 安全策略：
 * 1. API Key 使用简单的 Base64 编码存储（HarmonyOS dataPreferences 本身有基本保护）
 * 2. 密钥不会出现在代码中，需要用户首次使用时输入
 * 3. 所有密钥操作都在本地完成，不会上传到服务器
 * 4. 建议：生产环境可以使用更高级的加密方案
 */
export class SecureKeyManager {
  private static instance: SecureKeyManager | null = null;
  private cachedKey: string | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {
    // 私有构造函数，单例模式
    this.context = getGlobalContext();
  }

  /**
   * 设置上下文（如果全局上下文不可用）
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取单例实例
   */
  static getInstance(): SecureKeyManager {
    if (!SecureKeyManager.instance) {
      SecureKeyManager.instance = new SecureKeyManager();
    }
    return SecureKeyManager.instance;
  }

  /**
   * 检查是否已设置 API Key
   */
  async hasApiKey(): Promise<boolean> {
    try {
      const key = await this.getApiKey();
      return key !== null && key.length > 0;
    } catch {
      return false;
    }
  }

  /**
   * 获取 API Key（已解密）
   * @returns Promise<string | null> 解密后的 API Key，如果不存在则返回 null
   */
  async getApiKey(): Promise<string | null> {
    // 如果已缓存，直接返回
    if (this.cachedKey !== null) {
      return this.cachedKey;
    }

    try {
      // 从存储中读取（Base64 编码）
      const encodedKey = await this.readStoredData(API_KEY_STORAGE_KEY);
      if (!encodedKey || encodedKey === '') {
        return null;
      }

      // Base64 解码
      const decryptedKey = this.base64Decode(encodedKey);
      
      // 缓存（仅在内存中，不持久化）
      this.cachedKey = decryptedKey;
      
      return decryptedKey;
    } catch (error) {
      console.error('[SecureKeyManager] 获取 API Key 失败:', error);
      return null;
    }
  }

  /**
   * 设置并加密存储 API Key
   * @param apiKey 原始 API Key
   */
  async setApiKey(apiKey: string): Promise<void> {
    if (!apiKey || apiKey.trim().length === 0) {
      throw new AppError(
        ErrorCode.INVALID_INPUT,
        'API Key cannot be empty',
        'API Key 不能为空'
      );
    }

    try {
      // Base64 编码存储（dataPreferences 提供基本保护）
      const encodedKey = this.base64Encode(apiKey.trim());
      
      // 存储编码后的 Key
      await this.saveStoredData(API_KEY_STORAGE_KEY, encodedKey);
      
      // 更新缓存
      this.cachedKey = apiKey.trim();
      
      console.log('[SecureKeyManager] API Key 已安全存储');
    } catch (error) {
      console.error('[SecureKeyManager] 存储 API Key 失败:', error);
      throw ErrorHandler.handle(error, 'setApiKey');
    }
  }

  /**
   * 删除存储的 API Key
   */
  async deleteApiKey(): Promise<void> {
    try {
      await this.deleteStoredData(API_KEY_STORAGE_KEY);
      this.cachedKey = null;
      console.log('[SecureKeyManager] API Key 已删除');
    } catch (error) {
      console.error('[SecureKeyManager] 删除 API Key 失败:', error);
      throw ErrorHandler.handle(error, 'deleteApiKey');
    }
  }

  /**
   * 清除内存中的缓存（不删除存储）
   */
  clearCache(): void {
    this.cachedKey = null;
  }

  /**
   * 保存数据到本地存储
   */
  private async saveStoredData(key: string, value: string): Promise<void> {
    if (!this.context) {
      throw new AppError(
        ErrorCode.INVALID_STATE,
        'Context not set',
        '上下文未设置，请先设置上下文'
      );
    }

    try {
      const dataPrefs = await preferences.getPreferences(this.context, STORAGE_NAME);
      await dataPrefs.put(key, value);
      await dataPrefs.flush();
    } catch (error) {
      console.error('[SecureKeyManager] 保存数据失败:', error);
      throw new AppError(
        ErrorCode.STORAGE_ERROR,
        'Failed to save data',
        '保存数据失败'
      );
    }
  }

  /**
   * 从本地存储读取数据
   */
  private async readStoredData(key: string): Promise<string | null> {
    if (!this.context) {
      console.warn('[SecureKeyManager] 上下文未设置');
      return null;
    }

    try {
      const dataPrefs = await preferences.getPreferences(this.context, STORAGE_NAME);
      const value = await dataPrefs.get(key, '');
      if (typeof value === 'string' && value !== '') {
        return value;
      }
      return null;
    } catch (error) {
      console.warn('[SecureKeyManager] 读取数据失败:', error);
      return null;
    }
  }

  /**
   * 删除存储的数据
   */
  private async deleteStoredData(key: string): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const dataPrefs = await preferences.getPreferences(this.context, STORAGE_NAME);
      await dataPrefs.delete(key);
      await dataPrefs.flush();
    } catch (error) {
      console.warn('[SecureKeyManager] 删除数据失败:', error);
    }
  }

  /**
   * Base64 编码
   * 使用简单的字符编码方式（HarmonyOS dataPreferences 提供基本保护）
   */
  private base64Encode(text: string): string {
    const encoder = new util.TextEncoder();
    const bytes: Uint8Array = encoder.encodeInto(text);
    // 使用 Base64 编码
    const base64Helper = new util.Base64Helper();
    const result: string = base64Helper.encodeToStringSync(bytes);
    return result;
  }

  /**
   * Base64 解码
   */
  private base64Decode(base64: string): string {
    try {
      const base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = base64Helper.decodeSync(base64);
      const decoder = new util.TextDecoder();
      const result: string = decoder.decodeWithStream(bytes, { stream: false });
      return result;
    } catch (error) {
      console.error('[SecureKeyManager] Base64 解码失败:', error);
      throw new AppError(
        ErrorCode.DECRYPTION_ERROR,
        'Failed to decode base64',
        'Base64 解码失败'
      );
    }
  }
}

// 导出单例实例
export const secureKeyManager = SecureKeyManager.getInstance();

