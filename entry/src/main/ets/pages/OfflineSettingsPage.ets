import router from '@ohos.router';
import { OfflineModeManager, OfflineMode } from '../utils/offlineModeManager';
import { OfflineDataManager, OfflineDataType } from '../utils/offlineDataManager';
import { OfflineAIService } from '../utils/offlineAIService';

/**
 * 离线模式设置页面
 * 提供离线优先功能的配置和管理界面
 */
@Entry
@Component
struct OfflineSettingsPage {
  @State offlineMode: OfflineMode = OfflineMode.AUTO_OFFLINE;
  @State autoSync: boolean = true;
  @State syncInterval: number = 30;
  @State enableOfflineAI: boolean = true;
  @State preferLocalCharts: boolean = true;
  @State dataCompressionEnabled: boolean = true;
  @State maxOfflineData: number = 1000;
  @State isOnline: boolean = true;
  @State syncStats: any = {};
  @State storageStats: any = {};
  @State aiStats: any = {};

  private offlineModeManager = OfflineModeManager.getInstance();
  private dataManager = OfflineDataManager.getInstance();
  private aiService = OfflineAIService.getInstance();

  aboutToAppear() {
    this.loadSettings();
    this.loadStats();
  }

  /**
   * 加载设置
   */
  private async loadSettings(): Promise<void> {
    try {
      const config = this.offlineModeManager.getConfig();
      this.offlineMode = config.mode;
      this.autoSync = config.autoSync;
      this.syncInterval = config.syncInterval;
      this.enableOfflineAI = config.enableOfflineAI;
      this.preferLocalCharts = config.preferLocalCharts;
      this.dataCompressionEnabled = config.dataCompressionEnabled;
      this.maxOfflineData = config.maxOfflineData;
      this.isOnline = this.offlineModeManager.isNetworkOnline();

      console.info('[OfflineSettingsPage] Settings loaded:', JSON.stringify(config));
    } catch (error) {
      console.error('[OfflineSettingsPage] Failed to load settings:', error);
    }
  }

  /**
   * 加载统计信息
   */
  private async loadStats(): Promise<void> {
    try {
      this.syncStats = this.offlineModeManager.getSyncStats();
      this.storageStats = this.dataManager.getStorageStats();
      this.aiStats = this.aiService.getOfflineAIStats();

      console.info('[OfflineSettingsPage] Stats loaded');
    } catch (error) {
      console.error('[OfflineSettingsPage] Failed to load stats:', error);
    }
  }

  /**
   * 保存设置
   */
  private async saveSettings(): Promise<void> {
    try {
      await this.offlineModeManager.updateConfig({
        mode: this.offlineMode,
        autoSync: this.autoSync,
        syncInterval: this.syncInterval,
        enableOfflineAI: this.enableOfflineAI,
        preferLocalCharts: this.preferLocalCharts,
        dataCompressionEnabled: this.dataCompressionEnabled,
        maxOfflineData: this.maxOfflineData
      });

      console.info('[OfflineSettingsPage] Settings saved');
    } catch (error) {
      console.error('[OfflineSettingsPage] Failed to save settings:', error);
    }
  }

  /**
   * 强制同步
   */
  private async forceSync(): Promise<void> {
    try {
      await this.offlineModeManager.forceSync();
      this.loadStats();
      console.info('[OfflineSettingsPage] Force sync completed');
    } catch (error) {
      console.error('[OfflineSettingsPage] Force sync failed:', error);
    }
  }

  /**
   * 清理过期数据
   */
  private async cleanupExpiredData(): Promise<void> {
    try {
      const removedCount = await this.dataManager.cleanupExpiredData();
      this.loadStats();
      console.info(`[OfflineSettingsPage] Cleaned up ${removedCount} expired items`);
    } catch (error) {
      console.error('[OfflineSettingsPage] Cleanup failed:', error);
    }
  }

  /**
   * 清空所有离线数据
   */
  private async clearAllData(): Promise<void> {
    try {
      await this.dataManager.clearAllData();
      await this.offlineModeManager.clearSyncQueue();
      this.loadStats();
      console.info('[OfflineSettingsPage] All offline data cleared');
    } catch (error) {
      console.error('[OfflineSettingsPage] Clear data failed:', error);
    }
  }

  /**
   * 格式化文件大小
   */
  private formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  build() {
    Column() {
      // 页面标题
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .onClick(() => router.back())

        Text('离线模式设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
      }
      .width('100%')
      .padding({ top: 20, bottom: 20 })

      Scroll() {
        Column() {
          // 网络状态卡片
          Card() {
            Column() {
              Row() {
                Text('网络状态')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)

                Text(this.isOnline ? '在线' : '离线')
                  .fontSize(14)
                  .fontColor(this.isOnline ? '#4CAF50' : '#F44336')
                  .backgroundColor(this.isOnline ? '#E8F5E8' : '#FFEBEE')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .borderRadius(4)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Divider().margin({ top: 16, bottom: 16 })

              // 同步统计
              Row() {
                Column() {
                  Text(this.syncStats.pendingItems.toString())
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text('待同步')
                    .fontSize(12)
                    .fontColor('#666666')
                }

                Column() {
                  Text(this.syncStats.syncedItems.toString())
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text('已同步')
                    .fontSize(12)
                    .fontColor('#666666')
                }

                Column() {
                  Text(this.syncStats.failedItems.toString())
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text('失败')
                    .fontSize(12)
                    .fontColor('#666666')
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)

              if (this.isOnline && this.syncStats.pendingItems > 0) {
                Button('立即同步')
                  .width('100%')
                  .height(36)
                  .fontSize(14)
                  .margin({ top: 16 })
                  .onClick(() => this.forceSync())
              }
            }
            .padding(16)
          }
          .margin({ bottom: 16 })

          // 离线模式配置
          Card() {
            Column() {
              Text('离线模式')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .margin({ bottom: 16 })

              // 离线模式选择
              Column() {
                Text('模式选择')
                  .fontSize(14)
                  .margin({ bottom: 8 })

                Radio({ value: OfflineMode.OFFLINE_ONLY, group: 'offlineMode' })
                  .checked(this.offlineMode === OfflineMode.OFFLINE_ONLY)
                  .onChange(() => {
                    this.offlineMode = OfflineMode.OFFLINE_ONLY;
                  })
                Text('纯离线模式')
                  .fontSize(12)
                  .fontColor('#666666')

                Radio({ value: OfflineMode.WIFI_ONLY, group: 'offlineMode' })
                  .checked(this.offlineMode === OfflineMode.WIFI_ONLY)
                  .onChange(() => {
                    this.offlineMode = OfflineMode.WIFI_ONLY;
                  })
                Text('仅WiFi模式')
                  .fontSize(12)
                  .fontColor('#666666')

                Radio({ value: OfflineMode.AUTO_OFFLINE, group: 'offlineMode' })
                  .checked(this.offlineMode === OfflineMode.AUTO_OFFLINE)
                  .onChange(() => {
                    this.offlineMode = OfflineMode.AUTO_OFFLINE;
                  })
                Text('自动离线模式')
                  .fontSize(12)
                  .fontColor('#666666')

                Radio({ value: OfflineMode.ONLINE_PREFERRED, group: 'offlineMode' })
                  .checked(this.offlineMode === OfflineMode.ONLINE_PREFERRED)
                  .onChange(() => {
                    this.offlineMode = OfflineMode.ONLINE_PREFERRED;
                  })
                Text('在线优先模式')
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)

              Divider().margin({ top: 16, bottom: 16 })

              // 功能开关
              Row() {
                Text('自动同步')
                Toggle({ type: ToggleType.Switch, isOn: this.autoSync })
                  .onChange((isOn: boolean) => {
                    this.autoSync = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 12 })

              Row() {
                Text('启用离线AI')
                Toggle({ type: ToggleType.Switch, isOn: this.enableOfflineAI })
                  .onChange((isOn: boolean) => {
                    this.enableOfflineAI = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 12 })

              Row() {
                Text('优先本地图表')
                Toggle({ type: ToggleType.Switch, isOn: this.preferLocalCharts })
                  .onChange((isOn: boolean) => {
                    this.preferLocalCharts = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 12 })

              Row() {
                Text('数据压缩')
                Toggle({ type: ToggleType.Switch, isOn: this.dataCompressionEnabled })
                  .onChange((isOn: boolean) => {
                    this.dataCompressionEnabled = isOn;
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .padding(16)
          }
          .margin({ bottom: 16 })

          // 数据管理
          Card() {
            Column() {
              Text('数据管理')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .margin({ bottom: 16 })

              // 存储统计
              Row() {
                Column() {
                  Text(this.storageStats.totalItems.toString())
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text('总项目')
                    .fontSize(12)
                    .fontColor('#666666')
                }

                Column() {
                  Text(this.formatFileSize(this.storageStats.totalSize))
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  Text('存储大小')
                    .fontSize(12)
                    .fontColor('#666666')
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)
              .margin({ bottom: 16 })

              // 数据类型统计
              Text('数据类型分布')
                .fontSize(14)
                .margin({ bottom: 8 })

              Column() {
                Object.entries(this.storageStats.typeStats || {}).forEach(([type, count]) => {
                  if (count > 0) {
                    Row() {
                      Text(this.getTypeDisplayName(type))
                        .fontSize(12)
                      Text(count.toString())
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                    }
                    .width('100%')
                    .justifyContent(FlexAlign.SpaceBetween)
                    .margin({ bottom: 4 })
                  }
                })
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 操作按钮
              Row() {
                Button('清理过期数据')
                  .flexGrow(1)
                  .height(36)
                  .fontSize(12)
                  .margin({ right: 8 })
                  .onClick(() => this.cleanupExpiredData())

                Button('清空数据')
                  .flexGrow(1)
                  .height(36)
                  .fontSize(12)
                  .backgroundColor('#F44336')
                  .onClick(() => this.clearAllData())
              }
              .width('100%')
            }
            .padding(16)
          }
          .margin({ bottom: 16 })

          // AI功能状态
          Card() {
            Column() {
              Text('离线AI功能')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .margin({ bottom: 16 })

              Row() {
                Text('可用策略')
                  .fontSize(12)
                  .fontColor('#666666')
                Text(this.aiStats.availableStrategies?.toString() || '0')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 8 })

              Row() {
                Text('今日推荐')
                  .fontSize(12)
                  .fontColor('#666666')
                Text(this.aiStats.recentRecommendations?.toString() || '0')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .padding(16)
          }

          // 保存按钮
          Button('保存设置')
            .width('100%')
            .height(48)
            .fontSize(16)
            .margin({ top: 24, bottom: 40 })
            .onClick(() => {
              this.saveSettings();
              router.back();
            })
        }
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  /**
   * 获取数据类型显示名称
   */
  private getTypeDisplayName(type: string): string {
    const typeMap: Record<string, string> = {
      [OfflineDataType.CHART_CONFIG]: '图表配置',
      [OfflineDataType.CHART_DATA]: '图表数据',
      [OfflineDataType.POMODoro_SESSION]: '番茄记录',
      [OfflineDataType.USER_SETTINGS]: '用户设置',
      [OfflineDataType.AI_RESPONSE]: 'AI响应',
      [OfflineDataType.TEMPLATES]: '模板'
    };
    return typeMap[type] || type;
  }
}

/**
 * 卡片组件
 */
@Component
struct Card {
  content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 2
    })
  }
}