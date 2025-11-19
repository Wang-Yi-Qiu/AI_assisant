import { getStorageInstance } from './preferencesStorage';
import { OfflineModeManager, OfflineMode, SyncStatus } from './offlineModeManager';
import hilog from '@ohos.hilog';

/**
 * 离线数据类型
 */
export enum OfflineDataType {
  CHART_CONFIG = 'chart_config',
  CHART_DATA = 'chart_data',
  POMODoro_SESSION = 'pomodoro_session',
  USER_SETTINGS = 'user_settings',
  AI_RESPONSE = 'ai_response',
  TEMPLATES = 'templates'
}

/**
 * 离线数据项接口
 */
export interface OfflineDataItem {
  id: string;                           // 唯一标识
  type: OfflineDataType;                // 数据类型
  title: string;                        // 标题
  content: any;                         // 内容
  createdAt: number;                    // 创建时间
  updatedAt: number;                    // 更新时间
  size: number;                         // 数据大小（字节）
  syncStatus: SyncStatus;               // 同步状态
  tags?: string[];                      // 标签
  metadata?: Record<string, any>;       // 元数据
}

/**
 * 离线数据查询条件
 */
export interface OfflineDataQuery {
  type?: OfflineDataType;               // 数据类型
  tags?: string[];                      // 标签过滤
  startTime?: number;                   // 开始时间
  endTime?: number;                     // 结束时间
  limit?: number;                       // 限制数量
  sortBy?: 'createdAt' | 'updatedAt' | 'title'; // 排序字段
  sortOrder?: 'asc' | 'desc';           // 排序顺序
}

/**
 * 离线数据管理器
 * 提供本地数据存储、检索和离线优先访问能力
 */
export class OfflineDataManager {
  private static instance: OfflineDataManager | null = null;
  private static readonly TAG = 'OfflineDataManager';
  private static readonly DOMAIN = 0xFF03;

  private storage = getStorageInstance();
  private offlineMode = OfflineModeManager.getInstance();
  private dataCache: Map<string, OfflineDataItem> = new Map();
  private cacheSize: number = 0;         // 缓存大小（字节）
  private maxCacheSize: number = 50 * 1024 * 1024; // 50MB

  private constructor() {
    this.initializeDataCache();
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): OfflineDataManager {
    if (!OfflineDataManager.instance) {
      OfflineDataManager.instance = new OfflineDataManager();
    }
    return OfflineDataManager.instance;
  }

  /**
   * 初始化数据缓存
   */
  private async initializeDataCache(): Promise<void> {
    try {
      await this.storage.initialize();
      await this.loadCache();
      hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Offline data cache initialized: ${this.dataCache.size} items`);
    } catch (error) {
      hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Failed to initialize data cache: ${error}`);
    }
  }

  /**
   * 加载缓存
   */
  private async loadCache(): Promise<void> {
    try {
      const cachedData = await this.storage.getObject('offline_data_cache', {});

      for (const [id, item] of Object.entries(cachedData as Record<string, OfflineDataItem>)) {
        this.dataCache.set(id, item);
        this.cacheSize += item.size;
      }

      hilog.debug(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Cache loaded: ${this.dataCache.size} items, ${this.cacheSize} bytes`);
    } catch (error) {
      hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Failed to load cache: ${error}`);
    }
  }

  /**
   * 保存缓存
   */
  private async saveCache(): Promise<void> {
    try {
      const cacheObject: Record<string, OfflineDataItem> = {};

      for (const [id, item] of this.dataCache.entries()) {
        cacheObject[id] = item;
      }

      await this.storage.saveObject('offline_data_cache', cacheObject);
      hilog.debug(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Cache saved: ${this.dataCache.size} items`);
    } catch (error) {
      hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Failed to save cache: ${error}`);
    }
  }

  /**
   * 计算数据大小
   */
  private calculateDataSize(data: any): number {
    try {
      return new Blob([JSON.stringify(data)]).size;
    } catch (error) {
      hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Failed to calculate data size: ${error}`);
      return 1024; // 默认1KB
    }
  }

  /**
   * 清理缓存空间
   */
  private async ensureCacheSpace(requiredSize: number): Promise<void> {
    if (this.cacheSize + requiredSize <= this.maxCacheSize) {
      return;
    }

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Cache cleanup required. Current: ${this.cacheSize}, Required: ${requiredSize}`);

    // 按更新时间排序，删除最旧的数据
    const sortedItems = Array.from(this.dataCache.values())
      .sort((a, b) => a.updatedAt - b.updatedAt);

    let freedSize = 0;
    const itemsToRemove: string[] = [];

    for (const item of sortedItems) {
      if (this.cacheSize - freedSize + requiredSize <= this.maxCacheSize) {
        break;
      }

      itemsToRemove.push(item.id);
      freedSize += item.size;
    }

    for (const id of itemsToRemove) {
      const item = this.dataCache.get(id);
      if (item) {
        this.cacheSize -= item.size;
        this.dataCache.delete(id);
      }
    }

    await this.saveCache();

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Cache cleanup completed. Removed ${itemsToRemove.length} items, freed ${freedSize} bytes`);
  }

  /**
   * 存储离线数据
   */
  public async storeOfflineData(
    type: OfflineDataType,
    title: string,
    content: any,
    tags?: string[],
    metadata?: Record<string, any>
  ): Promise<string> {
    const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
    const now = Date.now();
    const size = this.calculateDataSize(content);

    const item: OfflineDataItem = {
      id,
      type,
      title,
      content,
      createdAt: now,
      updatedAt: now,
      size,
      syncStatus: SyncStatus.PENDING,
      tags,
      metadata
    };

    // 确保有足够的缓存空间
    await this.ensureCacheSpace(size);

    // 更新缓存
    const existingItem = this.dataCache.get(id);
    if (existingItem) {
      this.cacheSize -= existingItem.size;
    }

    this.dataCache.set(id, item);
    this.cacheSize += size;

    await this.saveCache();

    // 添加到同步队列
    try {
      await this.offlineMode.addToSyncQueue(type === OfflineDataType.POMODORo_SESSION ? 'pomodoro' : 'settings', item);
    } catch (error) {
      hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Failed to add to sync queue: ${error}`);
    }

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Offline data stored: ${id} (${type})`);

    return id;
  }

  /**
   * 获取离线数据
   */
  public getOfflineData(id: string): OfflineDataItem | null {
    const item = this.dataCache.get(id);
    if (item) {
      hilog.debug(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Offline data retrieved: ${id}`);
      return item;
    }

    hilog.debug(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Offline data not found: ${id}`);
    return null;
  }

  /**
   * 查询离线数据
   */
  public queryOfflineData(query: OfflineDataQuery): OfflineDataItem[] {
    let results = Array.from(this.dataCache.values());

    // 类型过滤
    if (query.type) {
      results = results.filter(item => item.type === query.type);
    }

    // 标签过滤
    if (query.tags && query.tags.length > 0) {
      results = results.filter(item =>
        item.tags && query.tags!.some(tag => item.tags!.includes(tag))
      );
    }

    // 时间范围过滤
    if (query.startTime) {
      results = results.filter(item => item.createdAt >= query.startTime!);
    }

    if (query.endTime) {
      results = results.filter(item => item.createdAt <= query.endTime!);
    }

    // 排序
    const sortBy = query.sortBy || 'updatedAt';
    const sortOrder = query.sortOrder || 'desc';

    results.sort((a, b) => {
      const aValue = a[sortBy];
      const bValue = b[sortBy];

      if (sortOrder === 'asc') {
        return aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
      } else {
        return aValue > bValue ? -1 : aValue < bValue ? 1 : 0;
      }
    });

    // 限制数量
    if (query.limit && query.limit > 0) {
      results = results.slice(0, query.limit);
    }

    hilog.debug(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Offline data query returned ${results.length} items`);

    return results;
  }

  /**
   * 更新离线数据
   */
  public async updateOfflineData(
    id: string,
    updates: Partial<Pick<OfflineDataItem, 'title' | 'content' | 'tags' | 'metadata'>>
  ): Promise<boolean> {
    const item = this.dataCache.get(id);
    if (!item) {
      hilog.warn(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Cannot update non-existent item: ${id}`);
      return false;
    }

    const oldSize = item.size;
    const oldContent = item.content;

    // 更新字段
    if (updates.title !== undefined) {
      item.title = updates.title;
    }
    if (updates.content !== undefined) {
      item.content = updates.content;
    }
    if (updates.tags !== undefined) {
      item.tags = updates.tags;
    }
    if (updates.metadata !== undefined) {
      item.metadata = { ...item.metadata, ...updates.metadata };
    }

    item.updatedAt = Date.now();
    item.size = this.calculateDataSize(item.content);
    item.syncStatus = SyncStatus.PENDING;

    // 重新计算缓存大小
    this.cacheSize = this.cacheSize - oldSize + item.size;

    await this.saveCache();

    // 添加到同步队列（内容变化时）
    if (updates.content !== undefined && updates.content !== oldContent) {
      try {
        await this.offlineMode.addToSyncQueue(
          item.type === OfflineDataType.POMODoro_SESSION ? 'pomodoro' : 'settings',
          item
        );
      } catch (error) {
        hilog.error(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
          `Failed to add updated item to sync queue: ${error}`);
      }
    }

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Offline data updated: ${id}`);

    return true;
  }

  /**
   * 删除离线数据
   */
  public async deleteOfflineData(id: string): Promise<boolean> {
    const item = this.dataCache.get(id);
    if (!item) {
      hilog.warn(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Cannot delete non-existent item: ${id}`);
      return false;
    }

    this.cacheSize -= item.size;
    this.dataCache.delete(id);

    await this.saveCache();

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Offline data deleted: ${id}`);

    return true;
  }

  /**
   * 获取统计信息
   */
  public getStorageStats(): {
    totalItems: number;
    totalSize: number;
    typeStats: Record<OfflineDataType, number>;
    oldestItem: number;
    newestItem: number;
  } {
    const items = Array.from(this.dataCache.values());
    const typeStats: Record<OfflineDataType, number> = {} as Record<OfflineDataType, number>;

    // 初始化所有类型的计数
    Object.values(OfflineDataType).forEach(type => {
      typeStats[type] = 0;
    });

    let oldestItem = Date.now();
    let newestItem = 0;

    for (const item of items) {
      typeStats[item.type]++;
      oldestItem = Math.min(oldestItem, item.createdAt);
      newestItem = Math.max(newestItem, item.createdAt);
    }

    return {
      totalItems: items.length,
      totalSize: this.cacheSize,
      typeStats,
      oldestItem: items.length > 0 ? oldestItem : 0,
      newestItem
    };
  }

  /**
   * 清理过期数据
   */
  public async cleanupExpiredData(maxAge: number = 30 * 24 * 60 * 60 * 1000): Promise<number> {
    const cutoffTime = Date.now() - maxAge;
    const itemsToRemove: string[] = [];

    for (const [id, item] of this.dataCache.entries()) {
      if (item.createdAt < cutoffTime && item.type !== OfflineDataType.USER_SETTINGS) {
        itemsToRemove.push(id);
      }
    }

    let removedSize = 0;
    for (const id of itemsToRemove) {
      const item = this.dataCache.get(id);
      if (item) {
        removedSize += item.size;
        this.cacheSize -= item.size;
        this.dataCache.delete(id);
      }
    }

    if (itemsToRemove.length > 0) {
      await this.saveCache();
      hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
        `Cleaned up ${itemsToRemove.length} expired items, freed ${removedSize} bytes`);
    }

    return itemsToRemove.length;
  }

  /**
   * 清空所有离线数据
   */
  public async clearAllData(): Promise<void> {
    this.dataCache.clear();
    this.cacheSize = 0;

    await this.storage.deleteValue('offline_data_cache');

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      'All offline data cleared');
  }

  /**
   * 导出离线数据
   */
  public exportData(): Record<string, OfflineDataItem> {
    const exportData: Record<string, OfflineDataItem> = {};

    for (const [id, item] of this.dataCache.entries()) {
      exportData[id] = { ...item };
    }

    return exportData;
  }

  /**
   * 导入离线数据
   */
  public async importData(data: Record<string, OfflineDataItem>): Promise<void> {
    let importedCount = 0;
    let importedSize = 0;

    for (const [id, item] of Object.entries(data)) {
      const size = this.calculateDataSize(item);

      // 检查是否已存在
      if (this.dataCache.has(id)) {
        const existingItem = this.dataCache.get(id)!;
        this.cacheSize -= existingItem.size;
      }

      this.dataCache.set(id, { ...item, syncStatus: SyncStatus.PENDING });
      this.cacheSize += size;
      importedCount++;
      importedSize += size;
    }

    await this.saveCache();

    hilog.info(OfflineDataManager.DOMAIN, OfflineDataManager.TAG,
      `Imported ${importedCount} items (${importedSize} bytes)`);
  }
}