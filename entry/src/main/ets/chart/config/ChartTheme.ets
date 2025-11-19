/**
 * 图表主题配置类
 * 提供统一的外观和样式管理
 */

export class ChartTheme {
  public readonly name: string;
  public readonly backgroundColor: string;
  public readonly textColor: string;
  public readonly axisColor: string;
  public readonly splitLineColor: string;
  public readonly tooltipBackground: string;
  public readonly borderColor: string;
  public readonly colorPalette: string[];
  public readonly gradientColors: string[][];
  public readonly fontSize: {
    title: number;
    subtitle: number;
    legend: number;
    axis: number;
    tooltip: number;
    label: number;
  };

  constructor(themeName: 'light' | 'dark' | 'blue' = 'dark') {
    this.name = themeName;

    switch (themeName) {
      case 'light':
        this.setupLightTheme();
        break;
      case 'blue':
        this.setupBlueTheme();
        break;
      case 'dark':
      default:
        this.setupDarkTheme();
        break;
    }
  }

  private setupDarkTheme(): void {
    this.backgroundColor = '#1C1C1C';
    this.textColor = '#FFFFFF';
    this.axisColor = '#666666';
    this.splitLineColor = '#333333';
    this.tooltipBackground = 'rgba(0, 0, 0, 0.8)';
    this.borderColor = '#555555';
    this.colorPalette = [
      '#007DFF', // 主蓝色
      '#00C853', // 绿色
      '#FFD600', // 黄色
      '#FF5252', // 红色
      '#B388FF', // 紫色
      '#FF6E40', // 橙色
      '#00E676', // 浅绿
      '#18FFFF', // 青色
      '#FF4081', // 粉色
      '#7C4DFF'  // 深紫
    ];
    this.gradientColors = [
      ['#007DFF', '#005CBF'],
      ['#00C853', '#009624'],
      ['#FFD600', '#FFA000'],
      ['#FF5252', '#D32F2F'],
      ['#B388FF', '#7C4DFF']
    ];
    this.fontSize = {
      title: 18,
      subtitle: 14,
      legend: 12,
      axis: 11,
      tooltip: 12,
      label: 12
    };
  }

  private setupLightTheme(): void {
    this.backgroundColor = '#FFFFFF';
    this.textColor = '#333333';
    this.axisColor = '#CCCCCC';
    this.splitLineColor = '#E0E0E0';
    this.tooltipBackground = 'rgba(255, 255, 255, 0.9)';
    this.borderColor = '#DDDDDD';
    this.colorPalette = [
      '#1890FF', // 蓝色
      '#52C41A', // 绿色
      '#FAAD14', // 黄色
      '#F5222D', // 红色
      '#722ED1', // 紫色
      '#FA8C16', // 橙色
      '#13C2C2', // 青色
      '#EB2F96', // 粉色
      '#5C7CFA', // 浅蓝
      '#51CF66'  // 浅绿
    ];
    this.gradientColors = [
      ['#1890FF', '#096DD9'],
      ['#52C41A', '#389E0D'],
      ['#FAAD14', '#D48806'],
      ['#F5222D', '#CF1322'],
      ['#722ED1', '#531DAB']
    ];
    this.fontSize = {
      title: 18,
      subtitle: 14,
      legend: 12,
      axis: 11,
      tooltip: 12,
      label: 12
    };
  }

  private setupBlueTheme(): void {
    this.backgroundColor = '#0A1931';
    this.textColor = '#E0E0E0';
    this.axisColor = '#4A5568';
    this.splitLineColor = '#2D3748';
    this.tooltipBackground = 'rgba(10, 25, 49, 0.9)';
    this.borderColor = '#4A5568';
    this.colorPalette = [
      '#2196F3', // 亮蓝色
      '#4CAF50', // 绿色
      '#FF9800', // 橙色
      '#F44336', // 红色
      '#9C27B0', // 紫色
      '#00BCD4', // 青色
      '#8BC34A', // 浅绿
      '#FFEB3B', // 黄色
      '#FF5722', // 深橙
      '#607D8B'  // 蓝灰
    ];
    this.gradientColors = [
      ['#2196F3', '#1976D2'],
      ['#4CAF50', '#388E3C'],
      ['#FF9800', '#F57C00'],
      ['#F44336', '#D32F2F'],
      ['#9C27B0', '#7B1FA2']
    ];
    this.fontSize = {
      title: 18,
      subtitle: 14,
      legend: 12,
      axis: 11,
      tooltip: 12,
      label: 12
    };
  }

  /**
   * 获取主题的渐变色
   */
  public getGradientColor(index: number): string[] {
    return this.gradientColors[index % this.gradientColors.length];
  }

  /**
   * 获取主题的颜色
   */
  public getColor(index: number): string {
    return this.colorPalette[index % this.colorPalette.length];
  }

  /**
   * 获取所有的颜色
   */
  public getAllColors(): string[] {
    return [...this.colorPalette];
  }

  /**
   * 创建自定义主题
   */
  public static createCustomTheme(options: {
    backgroundColor?: string;
    textColor?: string;
    colorPalette?: string[];
    fontSize?: Partial<ChartTheme['fontSize']>;
  }): ChartTheme {
    const customTheme = new ChartTheme('dark');

    if (options.backgroundColor) customTheme.backgroundColor = options.backgroundColor;
    if (options.textColor) customTheme.textColor = options.textColor;
    if (options.colorPalette) customTheme.colorPalette = options.colorPalette;
    if (options.fontSize) Object.assign(customTheme.fontSize, options.fontSize);

    return customTheme;
  }
}