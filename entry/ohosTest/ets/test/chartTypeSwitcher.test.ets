/**
 * 图表类型切换工具单元测试
 * @module chartTypeSwitcher.test
 */

import { describe, it, expect } from '@ohos/hypium';
import { 
  getSupportedChartTypes, 
  getChartTypeName, 
  isCompatibleWithChartType, 
  switchChartType,
  autoSelectChartType,
  ChartType 
} from '../../src/main/ets/utils/chartTypeSwitcher';
import { ChartConfig } from '../../src/main/ets/utils/aiService';

export default function ChartTypeSwitcherTests() {
  describe('ChartTypeSwitcher Tests', () => {
    it('should return supported chart types', () => {
      const types = getSupportedChartTypes();
      expect(types).toBeDefined();
      expect(Array.isArray(types)).toBeTruthy();
      expect(types.length).assertEqual(4); // line, bar, pie, scatter
      expect(types).toContain('line');
      expect(types).toContain('bar');
      expect(types).toContain('pie');
      expect(types).toContain('scatter');
    });

    it('should return chart type names', () => {
      expect(getChartTypeName('line')).assertEqual('折线图');
      expect(getChartTypeName('bar')).assertEqual('柱状图');
      expect(getChartTypeName('pie')).assertEqual('饼图');
      expect(getChartTypeName('scatter')).assertEqual('散点图');
    });

    it('should check compatibility for line chart', () => {
      const config: ChartConfig = {
        series: [{
          type: 'line',
          data: [1, 2, 3, 4, 5]
        }]
      };
      expect(isCompatibleWithChartType(config, 'line')).toBeTruthy();
    });

    it('should check compatibility for bar chart', () => {
      const config: ChartConfig = {
        series: [{
          type: 'bar',
          data: [1, 2, 3]
        }]
      };
      expect(isCompatibleWithChartType(config, 'bar')).toBeTruthy();
    });

    it('should check compatibility for pie chart', () => {
      const config: ChartConfig = {
        series: [{
          type: 'pie',
          data: [1, 2, 3]
        }]
      };
      expect(isCompatibleWithChartType(config, 'pie')).toBeTruthy();
    });

    it('should reject incompatible types', () => {
      const config: ChartConfig = {
        series: [{
          type: 'line',
          data: [1] // 只有1个数据点，不适合折线图
        }]
      };
      expect(isCompatibleWithChartType(config, 'line')).toBeFalsy();
    });

    it('should switch chart type', () => {
      const config: ChartConfig = {
        series: [{
          type: 'line',
          data: [1, 2, 3, 4, 5]
        }]
      };
      const newConfig = switchChartType(config, 'bar');
      expect(newConfig.series[0].type).assertEqual('bar');
      expect(newConfig.series[0].data).assertEqual(config.series[0].data); // 数据保持不变
    });

    it('should auto select compatible type', () => {
      const config: ChartConfig = {
        series: [{
          type: 'line',
          data: [1, 2, 3, 4, 5]
        }]
      };
      const autoType = autoSelectChartType(config);
      expect(autoType).toBeDefined();
      expect(['line', 'bar', 'pie', 'scatter']).toContain(autoType);
    });
  });
}

