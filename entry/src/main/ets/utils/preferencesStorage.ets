import preferences from '@ohos.data.preferences';
import { Context } from '@ohos.abilityAccessCtrl';

/**
 * 简单的键值存储服务
 * 使用HarmonyOS的Preferences API进行数据持久化
 */
export class PreferencesStorage {
  private storage: preferences.Preferences | null = null;
  private context: Context | null = null;

  constructor() {
    // 延迟初始化Context
  }

  /**
   * 设置Context（必须在使用前调用）
   */
  setContext(context: Context): void {
    this.context = context;
  }

  /**
   * 初始化存储
   */
  async initialize(): Promise<void> {
    try {
      if (!this.context) {
        throw new Error('Context not set. Call setContext() first.');
      }

      // 获取应用存储路径，使用固定路径避免类型问题
      const dataDir = '/data/storage/el2/base';
      const options: preferences.Options = {
        name: `${dataDir}/pomodoro_settings`
      };
      this.storage = await preferences.getPreferences(this.context, options);
      console.info('PreferencesStorage: Storage initialized successfully');
    } catch (error) {
      console.error('PreferencesStorage: Failed to initialize storage', error);
      throw new Error(`Failed to initialize storage: ${error}`);
    }
  }

  /**
   * 保存字符串值
   */
  async saveString(key: string, value: string): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      await this.storage.put(key, value);
      await this.storage.flush();
      console.info(`PreferencesStorage: Saved string ${key} = ${value}`);
    } catch (error) {
      console.error(`PreferencesStorage: Failed to save string ${key}`, error);
      throw new Error(`Failed to save string: ${error}`);
    }
  }

  /**
   * 保存数字值
   */
  async saveNumber(key: string, value: number): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      await this.storage.put(key, value);
      await this.storage.flush();
      console.info(`PreferencesStorage: Saved number ${key} = ${value}`);
    } catch (error) {
      console.error(`PreferencesStorage: Failed to save number ${key}`, error);
      throw new Error(`Failed to save number: ${error}`);
    }
  }

  /**
   * 保存布尔值
   */
  async saveBoolean(key: string, value: boolean): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      await this.storage.put(key, value);
      await this.storage.flush();
      console.info(`PreferencesStorage: Saved boolean ${key} = ${value}`);
    } catch (error) {
      console.error(`PreferencesStorage: Failed to save boolean ${key}`, error);
      throw new Error(`Failed to save boolean: ${error}`);
    }
  }

  /**
   * 保存对象（JSON序列化）
   */
  async saveObject(key: string, value: object): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const jsonValue = JSON.stringify(value);
      await this.storage.put(key, jsonValue);
      await this.storage.flush();
      console.info(`PreferencesStorage: Saved object ${key}`);
    } catch (error) {
      console.error(`PreferencesStorage: Failed to save object ${key}`, error);
      throw new Error(`Failed to save object: ${error}`);
    }
  }

  /**
   * 获取字符串值
   */
  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const value = await this.storage.get(key, defaultValue);
      console.info(`PreferencesStorage: Retrieved string ${key} = ${value}`);
      return value as string;
    } catch (error) {
      console.error(`PreferencesStorage: Failed to get string ${key}`, error);
      return defaultValue;
    }
  }

  /**
   * 获取数字值
   */
  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const value = await this.storage.get(key, defaultValue);
      console.info(`PreferencesStorage: Retrieved number ${key} = ${value}`);
      return value as number;
    } catch (error) {
      console.error(`PreferencesStorage: Failed to get number ${key}`, error);
      return defaultValue;
    }
  }

  /**
   * 获取布尔值
   */
  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const value = await this.storage.get(key, defaultValue);
      console.info(`PreferencesStorage: Retrieved boolean ${key} = ${value}`);
      return value as boolean;
    } catch (error) {
      console.error(`PreferencesStorage: Failed to get boolean ${key}`, error);
      return defaultValue;
    }
  }

  /**
   * 获取对象（JSON反序列化）
   */
  async getObject<T>(key: string, defaultValue: T): Promise<T> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const jsonValue = await this.storage.get(key, JSON.stringify(defaultValue));
      const value: T = JSON.parse(jsonValue as string) as T;
      console.info(`PreferencesStorage: Retrieved object ${key}`);
      return value as T;
    } catch (error) {
      console.error(`PreferencesStorage: Failed to get object ${key}`, error);
      return defaultValue;
    }
  }

  /**
   * 删除键
   */
  async remove(key: string): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      await this.storage.delete(key);
      await this.storage.flush();
      console.info(`PreferencesStorage: Removed key ${key}`);
    } catch (error) {
      console.error(`PreferencesStorage: Failed to remove key ${key}`, error);
      throw new Error(`Failed to remove key: ${error}`);
    }
  }

  /**
   * 检查键是否存在
   */
  async hasKey(key: string): Promise<boolean> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      const hasKey = await this.storage.has(key);
      console.info(`PreferencesStorage: Key ${key} exists: ${hasKey}`);
      return hasKey;
    } catch (error) {
      console.error(`PreferencesStorage: Failed to check key ${key}`, error);
      return false;
    }
  }

  /**
   * 清空所有数据
   */
  async clear(): Promise<void> {
    if (!this.storage) {
      throw new Error('Storage not initialized');
    }

    try {
      await this.storage.clear();
      await this.storage.flush();
      console.info('PreferencesStorage: Cleared all data');
    } catch (error) {
      console.error('PreferencesStorage: Failed to clear data', error);
      throw new Error(`Failed to clear data: ${error}`);
    }
  }

  /**
   * 关闭存储
   */
  async close(): Promise<void> {
    if (this.storage) {
      try {
        await this.storage.flush();
        console.info('PreferencesStorage: Storage closed');
      } catch (error) {
        console.error('PreferencesStorage: Failed to close storage', error);
      }
      this.storage = null;
    }
  }
}

/**
 * 单例实例
 */
let storageInstance: PreferencesStorage | null = null;

/**
 * 获取存储实例
 */
export function getStorageInstance(): PreferencesStorage {
  if (!storageInstance) {
    storageInstance = new PreferencesStorage();
  }
  return storageInstance;
}

/**
 * 设置存储实例（用于测试）
 */
export function setStorageInstance(instance: PreferencesStorage): void {
  storageInstance = instance;
}