import { getStorageInstance } from './preferencesStorage';
import hilog from '@ohos.hilog';

/**
 * 离线模式枚举
 */
export enum OfflineMode {
  OFFLINE_ONLY = 'offline_only',        // 纯离线模式
  WIFI_ONLY = 'wifi_only',              // 仅WiFi模式
  AUTO_OFFLINE = 'auto_offline',        // 自动离线模式
  ONLINE_PREFERRED = 'online_preferred' // 在线优先模式
}

/**
 * 同步状态枚举
 */
export enum SyncStatus {
  SYNCING = 'syncing',                  // 同步中
  SYNCED = 'synced',                    // 已同步
  PENDING = 'pending',                  // 待同步
  FAILED = 'failed',                    // 同步失败
  OFFLINE = 'offline'                   // 离线状态
}

/**
 * 离线配置接口
 */
export interface OfflineConfig {
  mode: OfflineMode;                    // 离线模式
  autoSync: boolean;                    // 自动同步
  syncInterval: number;                  // 同步间隔（分钟）
  maxOfflineData: number;               // 最大离线数据条数
  enableOfflineAI: boolean;             // 启用离线AI
  preferLocalCharts: boolean;           // 优先使用本地图表
  dataCompressionEnabled: boolean;      // 数据压缩
}

/**
 * 同步队列项接口
 */
export interface SyncQueueItem {
  id: string;                           // 唯一标识
  type: 'chart' | 'pomodoro' | 'settings'; // 数据类型
  data: any;                            // 数据内容
  timestamp: number;                    // 时间戳
  retryCount: number;                   // 重试次数
  status: SyncStatus;                   // 同步状态
}

/**
 * 离线模式管理器
 * 实现离线优先的数据同步和缓存策略
 */
export class OfflineModeManager {
  private static instance: OfflineModeManager | null = null;
  private static readonly TAG = 'OfflineModeManager';
  private static readonly DOMAIN = 0xFF02;

  private config: OfflineConfig = {
    mode: OfflineMode.AUTO_OFFLINE,
    autoSync: true,
    syncInterval: 30,
    maxOfflineData: 1000,
    enableOfflineAI: true,
    preferLocalCharts: true,
    dataCompressionEnabled: true
  };

  private syncQueue: SyncQueueItem[] = [];
  private isOnline: boolean = true;
  private syncTimer: number = -1;
  private storage = getStorageInstance();

  private constructor() {
    this.initializeOfflineMode();
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): OfflineModeManager {
    if (!OfflineModeManager.instance) {
      OfflineModeManager.instance = new OfflineModeManager();
    }
    return OfflineModeManager.instance;
  }

  /**
   * 初始化离线模式
   */
  private async initializeOfflineMode(): Promise<void> {
    try {
      await this.storage.initialize();
      await this.loadConfig();
      await this.loadSyncQueue();
      this.setupNetworkMonitoring();
      this.startAutoSync();

      hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Offline mode initialized: ${this.config.mode}`);
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to initialize offline mode: ${error}`);
    }
  }

  /**
   * 加载配置
   */
  private async loadConfig(): Promise<void> {
    try {
      const savedConfig = await this.storage.getObject('offline_config', this.config);
      this.config = { ...this.config, ...savedConfig };
      hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Offline config loaded: ${JSON.stringify(this.config)}`);
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to load offline config: ${error}`);
    }
  }

  /**
   * 保存配置
   */
  private async saveConfig(): Promise<void> {
    try {
      await this.storage.saveObject('offline_config', this.config);
      hilog.debug(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        'Offline config saved');
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to save offline config: ${error}`);
    }
  }

  /**
   * 加载同步队列
   */
  private async loadSyncQueue(): Promise<void> {
    try {
      this.syncQueue = await this.storage.getObject('sync_queue', []);
      hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Sync queue loaded: ${this.syncQueue.length} items`);
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to load sync queue: ${error}`);
      this.syncQueue = [];
    }
  }

  /**
   * 保存同步队列
   */
  private async saveSyncQueue(): Promise<void> {
    try {
      await this.storage.saveObject('sync_queue', this.syncQueue);
      hilog.debug(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        'Sync queue saved');
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to save sync queue: ${error}`);
    }
  }

  /**
   * 设置网络监控
   */
  private setupNetworkMonitoring(): void {
    // 这里应该设置网络状态监听
    // 由于HarmonyOS网络API限制，这里简化实现
    try {
      hilog.debug(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        'Network monitoring setup completed');
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to setup network monitoring: ${error}`);
    }
  }

  /**
   * 开始自动同步
   */
  private startAutoSync(): void {
    if (!this.config.autoSync || this.config.mode === OfflineMode.OFFLINE_ONLY) {
      return;
    }

    this.stopAutoSync();

    this.syncTimer = setInterval(async () => {
      if (this.isOnline && this.syncQueue.length > 0) {
        await this.processSyncQueue();
      }
    }, this.config.syncInterval * 60 * 1000);

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      'Auto sync started');
  }

  /**
   * 停止自动同步
   */
  private stopAutoSync(): void {
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
      hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        'Auto sync stopped');
    }
  }

  /**
   * 处理同步队列
   */
  private async processSyncQueue(): Promise<void> {
    if (this.syncQueue.length === 0) {
      return;
    }

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      `Processing sync queue: ${this.syncQueue.length} items`);

    const itemsToSync = this.syncQueue.filter(item => item.status === SyncStatus.PENDING);

    for (const item of itemsToSync) {
      try {
        await this.syncItem(item);
        item.status = SyncStatus.SYNCED;
        hilog.debug(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
          `Item synced: ${item.id}`);
      } catch (error) {
        item.status = SyncStatus.FAILED;
        item.retryCount++;
        hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
          `Failed to sync item ${item.id}: ${error}`);

        if (item.retryCount >= 3) {
          // 重试次数过多，移除队列
          this.syncQueue = this.syncQueue.filter(i => i.id !== item.id);
          hilog.warn(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
            `Item removed after max retries: ${item.id}`);
        }
      }
    }

    await this.saveSyncQueue();
  }

  /**
   * 同步单个项目
   */
  private async syncItem(item: SyncQueueItem): Promise<void> {
    // 这里实现具体的同步逻辑
    hilog.debug(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      `Syncing item: ${item.type} - ${item.id}`);

    // 模拟同步延迟
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  /**
   * 添加到同步队列
   */
  public async addToSyncQueue(type: 'chart' | 'pomodoro' | 'settings', data: any): Promise<string> {
    const item: SyncQueueItem = {
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
      type,
      data: this.config.dataCompressionEnabled ? this.compressData(data) : data,
      timestamp: Date.now(),
      retryCount: 0,
      status: this.isOnline ? SyncStatus.SYNCING : SyncStatus.PENDING
    };

    this.syncQueue.push(item);

    // 清理超出限制的旧数据
    if (this.syncQueue.length > this.config.maxOfflineData) {
      const sortedQueue = this.syncQueue.sort((a, b) => a.timestamp - b.timestamp);
      const excessCount = this.syncQueue.length - this.config.maxOfflineData;
      this.syncQueue = sortedQueue.slice(excessCount);
    }

    await this.saveSyncQueue();

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      `Added to sync queue: ${item.id} (${type})`);

    // 如果在线且配置为立即同步
    if (this.isOnline && this.config.autoSync) {
      setTimeout(() => this.processSyncQueue(), 100);
    }

    return item.id;
  }

  /**
   * 压缩数据
   */
  private compressData(data: any): any {
    try {
      return JSON.stringify(data);
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to compress data: ${error}`);
      return data;
    }
  }

  /**
   * 解压缩数据
   */
  private decompressData(data: any): any {
    try {
      if (typeof data === 'string') {
        return JSON.parse(data);
      }
      return data;
    } catch (error) {
      hilog.error(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Failed to decompress data: ${error}`);
      return data;
    }
  }

  /**
   * 获取当前离线配置
   */
  public getConfig(): OfflineConfig {
    return { ...this.config };
  }

  /**
   * 更新离线配置
   */
  public async updateConfig(newConfig: Partial<OfflineConfig>): Promise<void> {
    this.config = { ...this.config, ...newConfig };
    await this.saveConfig();

    // 重新启动自动同步
    this.startAutoSync();

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      `Offline config updated: ${JSON.stringify(this.config)}`);
  }

  /**
   * 获取当前网络状态
   */
  public isNetworkOnline(): boolean {
    return this.isOnline;
  }

  /**
   * 设置网络状态（由网络监控调用）
   */
  public setNetworkStatus(isOnline: boolean): void {
    if (this.isOnline !== isOnline) {
      this.isOnline = isOnline;
      hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
        `Network status changed: ${isOnline ? 'Online' : 'Offline'}`);

      if (isOnline && this.config.autoSync) {
        // 网络恢复时立即处理同步队列
        setTimeout(() => this.processSyncQueue(), 1000);
      }
    }
  }

  /**
   * 强制同步
   */
  public async forceSync(): Promise<void> {
    if (!this.isOnline) {
      throw new Error('Cannot sync while offline');
    }

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      'Force sync started');

    await this.processSyncQueue();

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      'Force sync completed');
  }

  /**
   * 获取同步状态统计
   */
  public getSyncStats(): {
    totalItems: number;
    pendingItems: number;
    syncedItems: number;
    failedItems: number;
    isOnline: boolean;
    lastSyncTime: number;
  } {
    const pendingItems = this.syncQueue.filter(item => item.status === SyncStatus.PENDING).length;
    const syncedItems = this.syncQueue.filter(item => item.status === SyncStatus.SYNCED).length;
    const failedItems = this.syncQueue.filter(item => item.status === SyncStatus.FAILED).length;
    const lastSyncTime = this.syncQueue.length > 0
      ? Math.max(...this.syncQueue.map(item => item.timestamp))
      : 0;

    return {
      totalItems: this.syncQueue.length,
      pendingItems,
      syncedItems,
      failedItems,
      isOnline: this.isOnline,
      lastSyncTime
    };
  }

  /**
   * 清理同步队列
   */
  public async clearSyncQueue(): Promise<void> {
    this.syncQueue = [];
    await this.saveSyncQueue();
    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      'Sync queue cleared');
  }

  /**
   * 销毁离线模式管理器
   */
  public destroy(): void {
    this.stopAutoSync();
    this.syncQueue = [];

    if (OfflineModeManager.instance === this) {
      OfflineModeManager.instance = null;
    }

    hilog.info(OfflineModeManager.DOMAIN, OfflineModeManager.TAG,
      'Offline mode manager destroyed');
  }
}