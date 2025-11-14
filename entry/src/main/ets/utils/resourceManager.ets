/**
 * HarmonyOS资源管理器
 * 管理字符串、图片、颜色等资源
 * @module resourceManager
 */

import { BusinessError } from '@kit.BasicServicesKit';

interface ResourceManagerContext {
  resourceManager: {
    getStringValue: (resourceId: string) => Promise<string>;
    getNumberById: (resourceId: string) => Promise<number>;
  };
}

interface AppConfig {
  version: string;
  buildNumber: string;
  isDebug: boolean;
}

interface DeviceInfo {
  model: string;
  brand: string;
  osVersion: string;
  screenDensity: number;
}

export class ResourceManager {
  private static instance: ResourceManager;
  private context: ResourceManagerContext | null = null;
  private resourceCache: Map<string, string | number> = new Map();

  static getInstance(): ResourceManager {
    if (!ResourceManager.instance) {
      ResourceManager.instance = new ResourceManager();
    }
    return ResourceManager.instance;
  }

  /**
   * 初始化资源管理器
   */
  async initialize(context: ResourceManagerContext): Promise<void> {
    this.context = context;
    try {
      // 预加载常用资源
      await this.preloadCommonResources();
    } catch (error) {
      console.error('资源管理器初始化失败:', error);
    }
  }

  /**
   * 预加载常用资源
   */
  private async preloadCommonResources(): Promise<void> {
    const commonResources = [
      'app_name',
      'loading_text',
      'error_network',
      'error_timeout',
      'button_confirm',
      'button_cancel'
    ];

    for (const resourceKey of commonResources) {
      try {
        await this.getString(resourceKey);
      } catch (error) {
        console.warn(`预加载资源失败: ${resourceKey}`, error);
      }
    }
  }

  /**
   * 获取字符串资源
   * @param resourceId 资源ID
   * @param params 参数（可选）
   */
  async getString(resourceId: string, ...params: string[]): Promise<string> {
    const cacheKey = `${resourceId}_${params.join('_')}`;

    if (this.resourceCache.has(cacheKey)) {
      return this.resourceCache.get(cacheKey) as string;
    }

    try {
      if (!this.context) {
        throw new Error('资源管理器未初始化');
      }

      const manager = this.context.resourceManager;
      const value = await manager.getStringValue(resourceId);

      // 格式化字符串
      let result = value;
      if (params.length > 0) {
        for (let i = 0; i < params.length; i++) {
          result = result.replace(`{${i}}`, params[i]);
        }
      }

      // 缓存结果
      this.resourceCache.set(cacheKey, result);
      return result;

    } catch (error) {
      console.error(`获取字符串资源失败: ${resourceId}`, error);
      // 返回资源ID作为后备
      return resourceId;
    }
  }

  /**
   * 获取颜色资源
   * @param colorId 颜色ID
   */
  async getColor(colorId: string): Promise<string> {
    if (this.resourceCache.has(colorId)) {
      return this.resourceCache.get(colorId) as string;
    }

    try {
      if (!this.context) {
        throw new Error('资源管理器未初始化');
      }

      const manager = this.context.resourceManager;
      const colorValue = await manager.getStringValue(colorId);

      // 验证颜色格式
      if (this.isValidColor(colorValue)) {
        this.resourceCache.set(colorId, colorValue);
        return colorValue;
      } else {
        console.warn(`无效的颜色值: ${colorId} = ${colorValue}`);
        return '#000000'; // 默认黑色
      }

    } catch (error) {
      console.error(`获取颜色资源失败: ${colorId}`, error);
      return '#000000'; // 默认黑色
    }
  }

  /**
   * 获取图片资源路径
   * @param imageId 图片ID
   */
  getImagePath(imageId: string): string {
    try {
      // 返回资源路径
      return `resource:///rawfile/${imageId}`;
    } catch (error) {
      console.error(`获取图片路径失败: ${imageId}`, error);
      return 'resource:///rawfile/default_image.png'; // 默认图片
    }
  }

  /**
   * 验证颜色格式
   */
  private isValidColor(color: string): boolean {
    const colorRegex = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$|^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$|^rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*[\d.]+\s*\)$|^[a-zA-Z]+$/;
    return colorRegex.test(color);
  }

  /**
   * 清除资源缓存
   */
  clearCache(): void {
    this.resourceCache.clear();
  }

  /**
   * 获取缓存大小
   */
  getCacheSize(): number {
    return this.resourceCache.size;
  }

/**
   * 获取应用配置
   */
  getAppConfig(): AppConfig {
    return {
      version: '1.0.0',
      buildNumber: '1',
      isDebug: false // 这里应该根据构建配置设置
    };
  }

  /**
   * 获取设备信息
   */
  getDeviceInfo(): DeviceInfo {
    return {
      model: 'HarmonyOS Device',
      brand: 'Huawei',
      osVersion: '4.0',
      screenDensity: 3.0
    };
  }
}

// 导出单例实例
export const resourceManager = ResourceManager.getInstance();

interface ResourceStrings {
  APP_NAME: string;
  LOADING: string;
  ERROR_NETWORK: string;
  ERROR_TIMEOUT: string;
  ERROR_FILE_TOO_LARGE: string;
  ERROR_INVALID_FORMAT: string;
  BUTTON_GENERATE: string;
  BUTTON_EXPORT: string;
  BUTTON_CANCEL: string;
  BUTTON_RETRY: string;
  TITLE_HOME: string;
  TITLE_CHART: string;
  TITLE_HISTORY: string;
  MESSAGE_CHART_GENERATED: string;
  MESSAGE_FILE_UPLOADED: string;
}

interface ResourceColors {
  PRIMARY: string;
  PRIMARY_LIGHT: string;
  PRIMARY_DARK: string;
  ACCENT: string;
  BACKGROUND: string;
  SURFACE: string;
  ERROR: string;
  WARNING: string;
  SUCCESS: string;
  TEXT_PRIMARY: string;
  TEXT_SECONDARY: string;
}

interface ResourceDimensions {
  PADDING_SMALL: string;
  PADDING_MEDIUM: string;
  PADDING_LARGE: string;
  MARGIN_SMALL: string;
  MARGIN_MEDIUM: string;
  MARGIN_LARGE: string;
  BORDER_RADIUS_SMALL: string;
  BORDER_RADIUS_MEDIUM: string;
  BORDER_RADIUS_LARGE: string;
}

interface Resources {
  STRINGS: ResourceStrings;
  COLORS: ResourceColors;
  DIMENSIONS: ResourceDimensions;
}

// 常用资源常量
export const RESOURCES: Resources = {
  STRINGS: {
    APP_NAME: 'app_name',
    LOADING: 'loading_text',
    ERROR_NETWORK: 'error_network',
    ERROR_TIMEOUT: 'error_timeout',
    ERROR_FILE_TOO_LARGE: 'error_file_too_large',
    ERROR_INVALID_FORMAT: 'error_invalid_format',
    BUTTON_GENERATE: 'button_generate',
    BUTTON_EXPORT: 'button_export',
    BUTTON_CANCEL: 'button_cancel',
    BUTTON_RETRY: 'button_retry',
    TITLE_HOME: 'title_home',
    TITLE_CHART: 'title_chart',
    TITLE_HISTORY: 'title_history',
    MESSAGE_CHART_GENERATED: 'message_chart_generated',
    MESSAGE_FILE_UPLOADED: 'message_file_uploaded'
  },
  COLORS: {
    PRIMARY: 'color_primary',
    PRIMARY_LIGHT: 'color_primary_light',
    PRIMARY_DARK: 'color_primary_dark',
    ACCENT: 'color_accent',
    BACKGROUND: 'color_background',
    SURFACE: 'color_surface',
    ERROR: 'color_error',
    WARNING: 'color_warning',
    SUCCESS: 'color_success',
    TEXT_PRIMARY: 'color_text_primary',
    TEXT_SECONDARY: 'color_text_secondary'
  },
  DIMENSIONS: {
    PADDING_SMALL: 'dimen_padding_small',
    PADDING_MEDIUM: 'dimen_padding_medium',
    PADDING_LARGE: 'dimen_padding_large',
    MARGIN_SMALL: 'dimen_margin_small',
    MARGIN_MEDIUM: 'dimen_margin_medium',
    MARGIN_LARGE: 'dimen_margin_large',
    BORDER_RADIUS_SMALL: 'dimen_border_radius_small',
    BORDER_RADIUS_MEDIUM: 'dimen_border_radius_medium',
    BORDER_RADIUS_LARGE: 'dimen_border_radius_large'
  }
};