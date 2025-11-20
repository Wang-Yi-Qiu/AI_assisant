/**
 * 图表缓存管理器
 * 实现智能缓存策略，减少重复计算和API调用
 */

import { getStorageInstance } from '../utils/preferencesStorage';
import { generateUUID } from '../utils/uuid';

/**
 * 缓存条目接口
 */
export interface CacheEntry {
  key: string;
  data: any;
  timestamp: number;
  expiryTime: number;
  hitCount: number;
  dataSize: number;
  hash: string;
  metadata?: {
    chartType?: string;
    dataSize?: number;
    processingTime?: number;
    version?: string;
  };
}

/**
 * 缓存配置接口
 */
export interface CacheConfig {
  maxSize: number;          // 最大缓存条目数
  maxMemorySize: number;    // 最大内存使用量（字节）
  defaultTtl: number;       // 默认生存时间（毫秒）
  compressionEnabled: boolean; // 是否启用压缩
  persistentCache: boolean;    // 是否启用持久化缓存
  cleanupInterval: number;    // 清理间隔（毫秒）
}

/**
 * 缓存统计接口
 */
export interface CacheStats {
  totalEntries: number;
  totalMemoryUsage: number;
  hitCount: number;
  missCount: number;
  hitRate: number;
  oldestEntry: number;
  newestEntry: number;
  evictions: number;
}

/**
 * 智能缓存管理器类
 */
export class ChartCacheManager {
  private static instance: ChartCacheManager;
  private cache: Map<string, CacheEntry>;
  public config: CacheConfig;
  private memoryUsage: number;
  private hitCount: number = 0;
  private missCount: number = 0;
  private evictionCount: number = 0;
  private cleanupTimer: number | null = null;

  private constructor() {
    this.cache = new Map<string, CacheEntry>();
    this.memoryUsage = 0;
    this.config = {
      maxSize: 100,
      maxMemorySize: 50 * 1024 * 1024, // 50MB
      defaultTtl: 30 * 60 * 1000, // 30分钟
      compressionEnabled: true,
      persistentCache: true,
      cleanupInterval: 5 * 60 * 1000 // 5分钟
    };
    this.initializeCleanupTimer();
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): ChartCacheManager {
    if (!ChartCacheManager.instance) {
      ChartCacheManager.instance = new ChartCacheManager();
    }
    return ChartCacheManager.instance;
  }

  /**
   * 初始化缓存
   */
  public async initialize(): Promise<void> {
    if (this.config.persistentCache) {
      await this.loadFromStorage();
    }
    console.info('[ChartCacheManager] 缓存初始化完成');
  }

  /**
   * 生成缓存键
   */
  public generateCacheKey(
    data: any,
    chartType?: string,
    options?: any
  ): string {
    try {
      // 提取数据特征用于生成唯一键
      const dataFeatures = this.extractDataFeatures(data);
      const optionsHash = options ? this.hashObject(options) : '';

      // 组合特征生成缓存键
      const keyComponents = [
        dataFeatures.hash,
        chartType || 'auto',
        optionsHash,
        this.getVersion()
      ];

      return this.hashString(keyComponents.join('|'));
    } catch (error) {
      console.error('[ChartCacheManager] 生成缓存键失败:', error);
      return this.generateFallbackKey(data, chartType);
    }
  }

  /**
   * 获取缓存条目
   */
  public get(key: string): any | null {
    const entry = this.cache.get(key);

    if (!entry) {
      this.missCount++;
      return null;
    }

    // 检查是否过期
    if (Date.now() > entry.expiryTime) {
      this.cache.delete(key);
      this.memoryUsage -= entry.dataSize;
      this.missCount++;
      return null;
    }

    // 更新命中统计
    entry.hitCount++;
    this.hitCount++;

    console.debug(`[ChartCacheManager] 缓存命中: ${key}`);
    return this.decompressData(entry.data);
  }

  /**
   * 设置缓存条目
   */
  public set(
    key: string,
    data: any,
    ttl: number = this.config.defaultTtl,
    metadata?: any
  ): void {
    try {
      // 检查是否需要清理空间
      this.ensureSpace();

      const compressedData = this.compressData(data);
      const dataSize = this.calculateDataSize(compressedData);

      // 检查数据大小限制
      if (dataSize > this.config.maxMemorySize / 10) {
        console.warn(`[ChartCacheManager] 数据过大，跳过缓存: ${dataSize} bytes`);
        return;
      }

      const now = Date.now();
      const entry: CacheEntry = {
        key,
        data: compressedData,
        timestamp: now,
        expiryTime: now + ttl,
        hitCount: 0,
        dataSize,
        hash: this.hashObject(data),
        metadata: {
          ...metadata,
          dataSize,
          version: this.getVersion()
        }
      };

      this.cache.set(key, entry);
      this.memoryUsage += dataSize;

      // 持久化到存储
      if (this.config.persistentCache) {
        this.saveToStorage();
      }

      console.debug(`[ChartCacheManager] 缓存设置: ${key} (${dataSize} bytes)`);
    } catch (error) {
      console.error('[ChartCacheManager] 设置缓存失败:', error);
    }
  }

  /**
   * 检查缓存是否存在
   */
  public has(key: string): boolean {
    const entry = this.cache.get(key);
    return entry !== undefined && Date.now() <= entry.expiryTime;
  }

  /**
   * 删除缓存条目
   */
  public delete(key: string): boolean {
    const entry = this.cache.get(key);
    if (entry) {
      this.cache.delete(key);
      this.memoryUsage -= entry.dataSize;
      if (this.config.persistentCache) {
        this.saveToStorage();
      }
      return true;
    }
    return false;
  }

  /**
   * 清空缓存
   */
  public clear(): void {
    this.cache.clear();
    this.memoryUsage = 0;
    this.hitCount = 0;
    this.missCount = 0;

    if (this.config.persistentCache) {
      this.saveToStorage();
    }

    console.info('[ChartCacheManager] 缓存已清空');
  }

  /**
   * 获取缓存统计
   */
  public getStats(): CacheStats {
    const entries = Array.from(this.cache.values());
    const timestamps = entries.map(e => e.timestamp);

    return {
      totalEntries: this.cache.size,
      totalMemoryUsage: this.memoryUsage,
      hitCount: this.hitCount,
      missCount: this.missCount,
      hitRate: this.hitCount + this.missCount > 0 ?
        (this.hitCount / (this.hitCount + this.missCount)) * 100 : 0,
      oldestEntry: timestamps.length > 0 ? Math.min(...timestamps) : 0,
      newestEntry: timestamps.length > 0 ? Math.max(...timestamps) : 0,
      evictions: this.evictionCount
    };
  }

  /**
   * 预热缓存
   */
  public async warmup(predefinedConfigs: Array<{key: string, data: any}>): Promise<void> {
    console.info(`[ChartCacheManager] 开始预热缓存，预定义配置数: ${predefinedConfigs.length}`);

    for (const config of predefinedConfigs) {
      this.set(config.key, config.data, this.config.defaultTtl * 2); // 更长的TTL
    }

    console.info('[ChartCacheManager] 缓存预热完成');
  }

  /**
   * 批量获取缓存
   */
  public getBatch(keys: string[]): Map<string, any> {
    const results = new Map<string, any>();

    for (const key of keys) {
      const data = this.get(key);
      if (data !== null) {
        results.set(key, data);
      }
    }

    return results;
  }

  /**
   * 批量设置缓存
   */
  public setBatch(entries: Array<{key: string, data: any, ttl?: number}>): void {
    for (const entry of entries) {
      this.set(entry.key, entry.data, entry.ttl);
    }
  }

  /**
   * 清理过期缓存
   */
  public cleanup(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];

    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiryTime) {
        keysToDelete.push(key);
      }
    }

    for (const key of keysToDelete) {
      this.delete(key);
    }

    if (keysToDelete.length > 0) {
      console.info(`[ChartCacheManager] 清理了 ${keysToDelete.length} 个过期条目`);
    }
  }

  /**
   * 确保有足够的空间
   */
  private ensureSpace(): void {
    // 清理过期条目
    this.cleanup();

    // 如果仍需空间，使用LRU算法
    while (this.cache.size >= this.config.maxSize ||
           this.memoryUsage >= this.config.maxMemorySize) {
      this.evictLRU();
    }
  }

  /**
   * LRU算法驱逐条目
   */
  private evictLRU(): void {
    let oldestKey: string | null = null;
    let oldestTime = Date.now();

    for (const [key, entry] of this.cache.entries()) {
      if (entry.timestamp < oldestTime) {
        oldestTime = entry.timestamp;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.delete(oldestKey);
      this.evictionCount++;
    }
  }

  /**
   * 提取数据特征
   */
  private extractDataFeatures(data: any): any {
    try {
      if (!data || typeof data !== 'object') {
        return { type: 'empty', hash: '' };
      }

      const features: any = {
        type: 'unknown',
        rowCount: 0,
        columnCount: 0,
        numericColumns: 0,
        categoryColumns: 0,
        hash: ''
      };

      // 分析数据结构
      if (data.headers && Array.isArray(data.headers)) {
        features.columnCount = data.headers.length;
        features.type = 'structured';

        if (data.rows && Array.isArray(data.rows)) {
          features.rowCount = data.rows.length;

          // 简单的数据特征哈希
          const sample = data.rows.slice(0, 3).map(row =>
            row.map(cell => String(cell).slice(0, 10)).join('|')
          ).join(';;');
          features.hash = this.hashString(sample);
        }
      } else if (Array.isArray(data)) {
        features.type = 'array';
        features.rowCount = data.length;
        features.hash = this.hashString(JSON.stringify(data.slice(0, 5)));
      }

      return features;
    } catch (error) {
      console.error('[ChartCacheManager] 提取数据特征失败:', error);
      return { type: 'error', hash: '' };
    }
  }

  /**
   * 压缩数据
   */
  private compressData(data: any): any {
    if (!this.config.compressionEnabled) {
      return data;
    }

    try {
      // 简单的字符串化压缩（实际项目中可使用更高效的压缩算法）
      const jsonString = JSON.stringify(data);

      // 检查是否值得压缩
      if (jsonString.length < 100) {
        return data; // 小数据不压缩
      }

      // 简单压缩：移除不必要的空格
      const compressed = jsonString
        .replace(/\s+/g, ' ')
        .trim();

      return compressed;
    } catch (error) {
      console.error('[ChartCacheManager] 数据压缩失败:', error);
      return data;
    }
  }

  /**
   * 解压缩数据
   */
  private decompressData(data: any): any {
    if (!this.config.compressionEnabled || typeof data === 'object') {
      return data;
    }

    try {
      return JSON.parse(data);
    } catch (error) {
      console.error('[ChartCacheManager] 数据解压缩失败:', error);
      return data;
    }
  }

  /**
   * 计算数据大小
   */
  private calculateDataSize(data: any): number {
    return JSON.stringify(data).length * 2; // Approximate size in bytes (UTF-16)
  }

  /**
   * 字符串哈希
   */
  private hashString(str: string): string {
    let hash = 0;
    if (str.length === 0) return hash.toString();

    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }

    return Math.abs(hash).toString(36);
  }

  /**
   * 对象哈希
   */
  private hashObject(obj: any): string {
    try {
      return this.hashString(JSON.stringify(obj));
    } catch (error) {
      console.error('[ChartCacheManager] 对象哈希失败:', error);
      return 'hash_error';
    }
  }

  /**
   * 生成备用缓存键
   */
  private generateFallbackKey(data: any, chartType?: string): string {
    const type = chartType || 'unknown';
    const timestamp = Date.now();
    const random = Math.random().toString(36).substr(2, 9);

    return `fallback_${type}_${timestamp}_${random}`;
  }

  /**
   * 获取版本号
   */
  private getVersion(): string {
    return '1.0.0';
  }

  /**
   * 初始化清理定时器
   */
  private initializeCleanupTimer(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
    }

    this.cleanupTimer = setInterval(() => {
      this.cleanup();
    }, this.config.cleanupInterval);
  }

  /**
   * 保存到持久化存储
   */
  private async saveToStorage(): Promise<void> {
    try {
      const storage = getStorageInstance();

      // 只保存缓存键和元数据，不保存实际数据
      const cacheMetadata: Record<string, any> = {};

      for (const [key, entry] of this.cache.entries()) {
        cacheMetadata[key] = {
          timestamp: entry.timestamp,
          expiryTime: entry.expiryTime,
          hitCount: entry.hitCount,
          dataSize: entry.dataSize,
          metadata: entry.metadata
        };
      }

      await storage.saveString('chart_cache_metadata', JSON.stringify(cacheMetadata));
      await storage.saveString('chart_cache_stats', JSON.stringify(this.getStats()));
    } catch (error) {
      console.error('[ChartCacheManager] 保存到存储失败:', error);
    }
  }

  /**
   * 从持久化存储加载
   */
  private async loadFromStorage(): Promise<void> {
    try {
      const storage = getStorageInstance();

      const metadataStr = await storage.getString('chart_cache_metadata');
      const statsStr = await storage.getString('chart_cache_stats');

      if (metadataStr) {
        const metadata = JSON.parse(metadataStr);
        // 注意：这里只加载元数据，实际数据需要重新计算
        console.log(`[ChartCacheManager] 从存储加载了 ${Object.keys(metadata).length} 个缓存元数据`);
      }

      if (statsStr) {
        const stats = JSON.parse(statsStr);
        this.hitCount = stats.hitCount || 0;
        this.missCount = stats.missCount || 0;
        this.evictionCount = stats.evictions || 0;
      }
    } catch (error) {
      console.error('[ChartCacheManager] 从存储加载失败:', error);
    }
  }

  /**
   * 销毁缓存管理器
   */
  public destroy(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }

    this.clear();
    console.info('[ChartCacheManager] 缓存管理器已销毁');
  }
}