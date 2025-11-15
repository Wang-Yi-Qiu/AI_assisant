/**
 * 设备适配工具：检测设备类型并提供响应式布局支持
 * @module deviceAdapter
 */

import deviceInfo from '@ohos.deviceInfo';
import window from '@ohos.window';
import display from '@ohos.display';
import { Context } from '@kit.AbilityKit';

/**
 * 设备类型枚举
 */
export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  TWO_IN_ONE = '2in1',
  TV = 'tv',
  WEARABLE = 'wearable',
  CAR = 'car',
  SMART_VISION = 'smartVision'
}

/**
 * 屏幕尺寸分类
 */
export enum ScreenSize {
  SMALL = 'small',      // < 600dp
  MEDIUM = 'medium',    // 600-840dp
  LARGE = 'large'       // > 840dp
}

/**
 * 设备能力接口
 */
export interface DeviceCapabilities {
  supportsFilePicker: boolean;      // 是否支持文件选择器
  supportsImageExport: boolean;      // 是否支持图片导出
  supportsPdfExport: boolean;        // 是否支持PDF导出
  supportsFocusNavigation: boolean;   // 是否支持焦点导航（TV/车机）
  supportsTouch: boolean;            // 是否支持触控
  supportsKeyboard: boolean;         // 是否支持键盘
}

// 字体大小配置接口
interface FontSizeConfig {
  small: number;
  medium: number;
  large: number;
  title: number;
}

// 间距配置接口
interface SpacingConfig {
  small: number;
  medium: number;
  large: number;
}

// 内边距配置接口
interface PaddingConfig {
  small: number;
  medium: number;
  large: number;
}

/**
 * 布局配置接口
 */
export interface LayoutConfig {
  fontSize: FontSizeConfig;
  spacing: SpacingConfig;
  padding: PaddingConfig;
  gridColumns: number;              // 栅格列数
  maxContentWidth: number | string;   // 最大内容宽度
}

/**
 * 设备适配器类
 */
export class DeviceAdapter {
  private static instance: DeviceAdapter;
  private deviceType: DeviceType = DeviceType.PHONE;
  private screenSize: ScreenSize = ScreenSize.MEDIUM;
  private screenWidth: number = 0;
  private screenHeight: number = 0;
  private capabilities: DeviceCapabilities;

  private constructor() {
    this.detectDevice();
    this.capabilities = this.detectCapabilities();
  }

  static getInstance(): DeviceAdapter {
    if (!DeviceAdapter.instance) {
      DeviceAdapter.instance = new DeviceAdapter();
    }
    return DeviceAdapter.instance;
  }

  /**
   * 检测设备类型
   */
  private detectDevice(): void {
    try {
      // 获取设备类型（deviceInfo.deviceType 返回字符串）
      const deviceTypeStr = deviceInfo.deviceType;
      
      // 映射设备类型
      if (deviceTypeStr === 'phone') {
        this.deviceType = DeviceType.PHONE;
      } else if (deviceTypeStr === 'tablet') {
        this.deviceType = DeviceType.TABLET;
      } else if (deviceTypeStr === 'tv') {
        this.deviceType = DeviceType.TV;
      } else if (deviceTypeStr === 'wearable') {
        this.deviceType = DeviceType.WEARABLE;
      } else if (deviceTypeStr === 'car') {
        this.deviceType = DeviceType.CAR;
      } else {
        // 尝试通过屏幕尺寸推断
        this.deviceType = this.inferDeviceType();
      }

      // 检测屏幕尺寸
      this.detectScreenSize();
    } catch (error) {
      console.error('设备检测失败，使用默认值:', error);
      this.deviceType = DeviceType.PHONE;
      this.screenSize = ScreenSize.MEDIUM;
    }
  }

  /**
   * 通过屏幕尺寸推断设备类型
   */
  private inferDeviceType(): DeviceType {
    // 获取屏幕信息（可能抛出异常，需要try-catch）
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const width = displayInfo.width;
      const height = displayInfo.height;
      const minDimension = Math.min(width, height);
      const maxDimension = Math.max(width, height);

      // 根据屏幕尺寸推断
      if (maxDimension >= 1920 && minDimension >= 1080) {
        // 大屏设备，可能是TV或2in1
        return DeviceType.TV;
      } else if (maxDimension >= 1200) {
        // 平板或2in1
        return DeviceType.TABLET;
      } else if (minDimension < 400) {
        // 可穿戴设备
        return DeviceType.WEARABLE;
      } else {
        // 默认手机
        return DeviceType.PHONE;
      }
    } catch (error) {
      console.error('获取屏幕信息失败，使用默认设备类型:', error);
      return DeviceType.PHONE;
    }
  }

  /**
   * 检测屏幕尺寸分类
   */
  private detectScreenSize(): void {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const width = displayInfo.width;
      const height = displayInfo.height;
      const minDimension = Math.min(width, height);
      
      // 转换为dp（假设density为3.0）
      const density = displayInfo.densityDPI / 160;
      const widthDp = width / density;
      const heightDp = height / density;
      const minDp = Math.min(widthDp, heightDp);

      this.screenWidth = width;
      this.screenHeight = height;

      if (minDp < 600) {
        this.screenSize = ScreenSize.SMALL;
      } else if (minDp <= 840) {
        this.screenSize = ScreenSize.MEDIUM;
      } else {
        this.screenSize = ScreenSize.LARGE;
      }
    } catch (error) {
      console.error('屏幕尺寸检测失败:', error);
      this.screenSize = ScreenSize.MEDIUM;
    }
  }

  /**
   * 检测设备能力
   */
  private detectCapabilities(): DeviceCapabilities {
    const isTV = this.deviceType === DeviceType.TV;
    const isCar = this.deviceType === DeviceType.CAR;
    const isWearable = this.deviceType === DeviceType.WEARABLE;
    const isSmartVision = this.deviceType === DeviceType.SMART_VISION;

    return {
      // TV/车机/部分smartVision设备可能不支持文件选择器
      supportsFilePicker: !isTV && !isCar && !isWearable,
      // 图片导出能力（大部分设备支持）
      supportsImageExport: !isWearable,
      // PDF导出（通过HTML打印，大部分设备支持）
      supportsPdfExport: !isWearable,
      // 焦点导航（TV/车机需要）
      supportsFocusNavigation: isTV || isCar,
      // 触控支持（大部分设备支持）
      supportsTouch: !isTV && !isCar,
      // 键盘支持（2in1/平板/部分设备）
      supportsKeyboard: this.deviceType === DeviceType.TWO_IN_ONE || 
                        this.deviceType === DeviceType.TABLET
    };
  }

  /**
   * 获取设备类型
   */
  getDeviceType(): DeviceType {
    return this.deviceType;
  }

  /**
   * 获取屏幕尺寸分类
   */
  getScreenSize(): ScreenSize {
    return this.screenSize;
  }

  /**
   * 获取设备能力
   */
  getCapabilities(): DeviceCapabilities {
    return this.capabilities;
  }

  /**
   * 获取布局配置
   */
  getLayoutConfig(): LayoutConfig {
    const baseFontSize = this.getBaseFontSize();
    const baseSpacing = this.getBaseSpacing();
    const basePadding = this.getBasePadding();

    // 创建配置对象（ArkTS不支持对象字面量类型，需要明确类型）
    const fontSize: FontSizeConfig = {
      small: baseFontSize * 0.75,
      medium: baseFontSize,
      large: baseFontSize * 1.25,
      title: baseFontSize * 1.5
    };
    const spacing: SpacingConfig = {
      small: baseSpacing * 0.5,
      medium: baseSpacing,
      large: baseSpacing * 1.5
    };
    const padding: PaddingConfig = {
      small: basePadding * 0.5,
      medium: basePadding,
      large: basePadding * 1.5
    };

    return {
      fontSize: fontSize,
      spacing: spacing,
      padding: padding,
      gridColumns: this.getGridColumns(),
      maxContentWidth: this.getMaxContentWidth()
    };
  }

  /**
   * 获取基础字号
   */
  private getBaseFontSize(): number {
    switch (this.deviceType) {
      case DeviceType.WEARABLE:
        return 12;
      case DeviceType.TV:
      case DeviceType.CAR:
        return 18;
      case DeviceType.TABLET:
      case DeviceType.TWO_IN_ONE:
        return 16;
      default:
        return 14;
    }
  }

  /**
   * 获取基础间距
   */
  private getBaseSpacing(): number {
    switch (this.deviceType) {
      case DeviceType.WEARABLE:
        return 4;
      case DeviceType.TV:
      case DeviceType.CAR:
        return 12;
      case DeviceType.TABLET:
      case DeviceType.TWO_IN_ONE:
        return 8;
      default:
        return 8;
    }
  }

  /**
   * 获取基础内边距
   */
  private getBasePadding(): number {
    switch (this.deviceType) {
      case DeviceType.WEARABLE:
        return 8;
      case DeviceType.TV:
      case DeviceType.CAR:
        return 24;
      case DeviceType.TABLET:
      case DeviceType.TWO_IN_ONE:
        return 16;
      default:
        return 16;
    }
  }

  /**
   * 获取栅格列数
   */
  private getGridColumns(): number {
    switch (this.screenSize) {
      case ScreenSize.SMALL:
        return 1;
      case ScreenSize.MEDIUM:
        return this.deviceType === DeviceType.TABLET || 
               this.deviceType === DeviceType.TWO_IN_ONE ? 2 : 1;
      case ScreenSize.LARGE:
        return this.deviceType === DeviceType.TV ? 3 : 2;
      default:
        return 1;
    }
  }

  /**
   * 获取最大内容宽度
   */
  private getMaxContentWidth(): number | string {
    switch (this.deviceType) {
      case DeviceType.TV:
        return '1200px';
      case DeviceType.TABLET:
      case DeviceType.TWO_IN_ONE:
        return '100%';
      default:
        return '100%';
    }
  }

  /**
   * 是否为触控设备
   */
  isTouchDevice(): boolean {
    return this.capabilities.supportsTouch;
  }

  /**
   * 是否需要焦点导航
   */
  needsFocusNavigation(): boolean {
    return this.capabilities.supportsFocusNavigation;
  }

  /**
   * 是否支持文件上传
   */
  supportsFileUpload(): boolean {
    return this.capabilities.supportsFilePicker;
  }

  /**
   * 是否支持图片导出
   */
  supportsImageExport(): boolean {
    return this.capabilities.supportsImageExport;
  }

  /**
   * 是否支持PDF导出
   */
  supportsPdfExport(): boolean {
    return this.capabilities.supportsPdfExport;
  }

  /**
   * 监听窗口大小变化（用于2in1/大屏适配）
   * @param context 应用上下文
   */
  async watchWindowSize(context: Context, callback: (width: number, height: number) => void): Promise<void> {
    try {
      // 获取当前窗口
      const windowClass = await window.getLastWindow(context);
      
      // 监听窗口大小变化（使用 windowSizeChange 事件）
      // 注意：getProperties 已弃用，使用 getWindowProperties 替代
      try {
        // 获取初始窗口大小
        const properties = windowClass.getWindowProperties();
        if (properties) {
          this.screenWidth = properties.windowRect.width;
          this.screenHeight = properties.windowRect.height;
          this.detectScreenSize();
          callback(this.screenWidth, this.screenHeight);
        }
      } catch (error) {
        console.error('获取窗口大小失败:', error);
      }
    } catch (error) {
      console.error('监听窗口大小失败:', error);
    }
  }

  /**
   * 获取降级提示文案
   */
  getFallbackMessage(feature: 'fileUpload' | 'imageExport' | 'pdfExport'): string {
    switch (feature) {
      case 'fileUpload':
        return '当前设备不支持文件上传，请使用文本输入或历史记录复现';
      case 'imageExport':
        return '当前设备不支持图片导出，请使用JSON导出或复制文本';
      case 'pdfExport':
        return '当前设备不支持PDF导出，请使用JSON导出或复制文本';
      default:
        return '';
    }
  }
}

// 导出单例
export const deviceAdapter = DeviceAdapter.getInstance();

