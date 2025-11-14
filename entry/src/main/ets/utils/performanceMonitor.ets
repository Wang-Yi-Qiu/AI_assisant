/**
 * HarmonyOS性能监控工具
 * @module performanceMonitor
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

interface MemoryUsage {
  total: number;
  used: number;
  percentage: number;
}

export interface PerformanceMetrics {
  memoryUsage: MemoryUsage;
  cpuUsage: number;
  frameRate: number;
  networkLatency: number;
  renderTime: number;
}

export class PerformanceMonitor {
  private static instance: PerformanceMonitor;
  private isMonitoring: boolean = false;
  private metrics: PerformanceMetrics[] = [];
  private maxMetricsCount = 100;
  private frameCount = 0;
  private lastFrameTime = 0;

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  /**
   * 开始性能监控
   */
  startMonitoring(): void {
    if (this.isMonitoring) {
      return;
    }

    this.isMonitoring = true;
    this.collectMetrics();

    hilog.info(0x0000, 'PerformanceMonitor', '性能监控已启动');
  }

  /**
   * 停止性能监控
   */
  stopMonitoring(): void {
    this.isMonitoring = false;
    hilog.info(0x0000, 'PerformanceMonitor', '性能监控已停止');
  }

  /**
   * 收集性能指标
   */
  private collectMetrics(): void {
    if (!this.isMonitoring) {
      return;
    }

    const metrics = this.getCurrentMetrics();
    this.addMetrics(metrics);

    // 每5秒收集一次
    setTimeout(() => {
      this.collectMetrics();
    }, 5000);
  }

  /**
   * 获取当前性能指标
   */
  private getCurrentMetrics(): PerformanceMetrics {
    const metrics: PerformanceMetrics = {
      memoryUsage: this.getMemoryUsage(),
      cpuUsage: this.getCpuUsage(),
      frameRate: this.getFrameRate(),
      networkLatency: this.getNetworkLatency(),
      renderTime: this.getRenderTime()
    };

    return metrics;
  }

  /**
   * 获取内存使用情况
   */
  private getMemoryUsage(): MemoryUsage {
    // 这里应该使用HarmonyOS的内存API
    // 目前使用模拟数据
    const total = 1024 * 1024 * 1024; // 1GB
    const used = Math.random() * total * 0.7; // 最多70%使用率

    const memoryUsage: MemoryUsage = {
      total,
      used,
      percentage: (used / total) * 100
    };

    return memoryUsage;
  }

  /**
   * 获取CPU使用率
   */
  private getCpuUsage(): number {
    // 这里应该使用HarmonyOS的CPU监控API
    return Math.random() * 30 + 10; // 10-40%之间
  }

  /**
   * 获取帧率
   */
  getFrameRate(): number {
    const now = Date.now();
    if (this.lastFrameTime > 0) {
      this.frameCount++;
      const deltaTime = now - this.lastFrameTime;
      if (deltaTime >= 1000) {
        const fps = (this.frameCount * 1000) / deltaTime;
        this.frameCount = 0;
        this.lastFrameTime = now;
        return Math.round(fps);
      }
    } else {
      this.lastFrameTime = now;
    }
    return 60; // 默认60fps
  }

  /**
   * 获取网络延迟
   */
  private getNetworkLatency(): number {
    // 这里应该实际测量网络延迟
    return Math.random() * 100 + 50; // 50-150ms
  }

  /**
   * 获取渲染时间
   */
  private getRenderTime(): number {
    // 这里应该测量实际的渲染时间
    return Math.random() * 16 + 8; // 8-24ms (对应60fps)
  }

  /**
   * 添加性能指标
   */
  private addMetrics(metrics: PerformanceMetrics): void {
    this.metrics.push(metrics);

    // 限制保存的指标数量
    if (this.metrics.length > this.maxMetricsCount) {
      this.metrics.shift();
    }

    // 检查性能警告
    this.checkPerformanceWarnings(metrics);
  }

  /**
   * 检查性能警告
   */
  private checkPerformanceWarnings(metrics: PerformanceMetrics): void {
    // 内存使用率过高警告
    if (metrics.memoryUsage.percentage > 80) {
      hilog.warn(0x0000, 'PerformanceMonitor',
        `内存使用率过高: ${metrics.memoryUsage.percentage.toFixed(1)}%`);
    }

    // CPU使用率过高警告
    if (metrics.cpuUsage > 70) {
      hilog.warn(0x0000, 'PerformanceMonitor',
        `CPU使用率过高: ${metrics.cpuUsage.toFixed(1)}%`);
    }

    // 帧率过低警告
    if (metrics.frameRate < 30) {
      hilog.warn(0x0000, 'PerformanceMonitor',
        `帧率过低: ${metrics.frameRate}fps`);
    }

    // 网络延迟过高警告
    if (metrics.networkLatency > 1000) {
      hilog.warn(0x0000, 'PerformanceMonitor',
        `网络延迟过高: ${metrics.networkLatency.toFixed(0)}ms`);
    }

    // 渲染时间过长警告
    if (metrics.renderTime > 33) { // 超过30fps对应的渲染时间
      hilog.warn(0x0000, 'PerformanceMonitor',
        `渲染时间过长: ${metrics.renderTime.toFixed(1)}ms`);
    }
  }

  /**
   * 获取平均性能指标
   */
  getAverageMetrics(): PerformanceMetrics | null {
    if (this.metrics.length === 0) {
      return null;
    }

    let memoryUsedTotal = 0;
    let memoryPercentageTotal = 0;
    let cpuUsageTotal = 0;
    let frameRateTotal = 0;
    let networkLatencyTotal = 0;
    let renderTimeTotal = 0;
    let memoryTotal = this.metrics[0].memoryUsage.total;

    // 使用循环替代reduce
    for (let i = 0; i < this.metrics.length; i++) {
      const metrics = this.metrics[i];
      memoryUsedTotal += metrics.memoryUsage.used;
      memoryPercentageTotal += metrics.memoryUsage.percentage;
      cpuUsageTotal += metrics.cpuUsage;
      frameRateTotal += metrics.frameRate;
      networkLatencyTotal += metrics.networkLatency;
      renderTimeTotal += metrics.renderTime;
    }

    const count = this.metrics.length;
    const avgMetrics: PerformanceMetrics = {
      memoryUsage: {
        total: memoryTotal,
        used: memoryUsedTotal / count,
        percentage: memoryPercentageTotal / count
      },
      cpuUsage: cpuUsageTotal / count,
      frameRate: frameRateTotal / count,
      networkLatency: networkLatencyTotal / count,
      renderTime: renderTimeTotal / count
    };

    return avgMetrics;
  }

  /**
   * 获取最新的性能指标
   */
  getLatestMetrics(): PerformanceMetrics | null {
    return this.metrics.length > 0 ?
      this.metrics[this.metrics.length - 1] : null;
  }

  /**
   * 清除历史指标
   */
  clearMetrics(): void {
    this.metrics = [];
  }

  /**
   * 导出性能报告
   */
  exportReport(): string {
    const latest = this.getLatestMetrics();
    const average = this.getAverageMetrics();

    return `
=== HarmonyOS AI助手 性能报告 ===
生成时间: ${new Date().toISOString()}

最新指标:
- 内存使用: ${latest?.memoryUsage.percentage.toFixed(1)}%
- CPU使用: ${latest?.cpuUsage.toFixed(1)}%
- 帧率: ${latest?.frameRate.toFixed(0)}fps
- 网络延迟: ${latest?.networkLatency.toFixed(0)}ms
- 渲染时间: ${latest?.renderTime.toFixed(1)}ms

平均指标:
- 内存使用: ${average?.memoryUsage.percentage.toFixed(1)}%
- CPU使用: ${average?.cpuUsage.toFixed(1)}%
- 帧率: ${average?.frameRate.toFixed(0)}fps
- 网络延迟: ${average?.networkLatency.toFixed(0)}ms
- 渲染时间: ${average?.renderTime.toFixed(1)}ms

监控状态: ${this.isMonitoring ? '监控中' : '已停止'}
采样数量: ${this.metrics.length}
    `.trim();
  }
}

// 导出单例实例
export const performanceMonitor = PerformanceMonitor.getInstance();