/**
 * AI服务测试
 * @module aiService.test
 */

import { parseCSV, parseJSON, parseUserInput } from '../../main/ets/pages/HomePage';
import { ChartConfig } from '../../main/ets/utils/aiService';
import { describe, it, expect } from '@ohos/hypium';

export default function aiServiceTest() {
  describe('AI Service Tests', () => {
    describe('CSV Parsing', () => {
      it('should parse valid CSV data', () => {
        const csvData = '月份,销售额\n1月,120\n2月,200\n3月,150';
        const result = parseCSV(csvData);

        expect(result.headers).toEqual(['月份', '销售额']);
        expect(result.data).toEqual([
          { '月份': '1月', '销售额': '120' },
          { '月份': '2月', '销售额': '200' },
          { '月份': '3月', '销售额': '150' }
        ]);
      });

      it('should handle empty CSV data', () => {
        const csvData = '';
        const result = parseCSV(csvData);

        expect(result.headers).toEqual([]);
        expect(result.data).toEqual([]);
      });

      it('should handle CSV with different line endings', () => {
        const csvData = '月份,销售额\r\n1月,120\r\n2月,200';
        const result = parseCSV(csvData);

        expect(result.headers).toEqual(['月份', '销售额']);
        expect(result.data).toEqual([
          { '月份': '1月', '销售额': '120' },
          { '月份': '2月', '销售额': '200' }
        ]);
      });
    });

    describe('JSON Parsing', () => {
      it('should parse valid JSON data', () => {
        const jsonData = '{"月份":["1月","2月"],"销售额":[120,200]}';
        const result = parseJSON(jsonData);

        expect(result).toEqual({
          '月份': ['1月', '2月'],
          '销售额': [120, 200]
        });
      });

      it('should handle empty JSON data', () => {
        const jsonData = '{}';
        const result = parseJSON(jsonData);

        expect(result).toEqual({});
      });

      it('should throw error for invalid JSON', () => {
        const jsonData = '{invalid json}';

        try {
          parseJSON(jsonData);
          expect().fail('应该抛出JSON解析错误');
        } catch (error) {
          expect(error instanceof Error).toBeTrue();
          expect(error.message).toContain('JSON解析失败');
        }
      });
    });

    describe('User Input Parsing', () => {
      it('should detect CSV format automatically', () => {
        const csvInput = '月份,销售额\n1月,120\n2月,200';
        const result = parseUserInput(csvInput);

        expect(result.headers).toEqual(['月份', '销售额']);
        expect(result.data).toHaveLength(2);
      });

      it('should detect JSON format automatically', () => {
        const jsonInput = '{"月份":["1月","2月"],"销售额":[120,200]}';
        const result = parseUserInput(jsonInput);

        expect(result).toEqual({
          '月份': ['1月', '2月'],
          '销售额': [120, 200]
        });
      });

      it('should handle plain text input', () => {
        const textInput = '1月 120\n2月 200\n3月 150';
        const result = parseUserInput(textInput);

        expect(result).toBe(textInput);
      });
    });

    describe('Chart Config Validation', () => {
      it('should validate valid chart config', () => {
        const validConfig: ChartConfig = {
          title: { text: '测试图表' },
          series: [
            { type: 'bar' },
            { type: 'line' }
          ]
        };

        expect(validConfig.title?.text).toBe('测试图表');
        expect(validConfig.series).toHaveLength(2);
        expect(validConfig.series[0].type).toBe('bar');
        expect(validConfig.series[1].type).toBe('line');
      });

      it('should reject chart config without series', () => {
        const invalidConfig = {
          title: { text: '测试图表' }
          // 缺少 series
        } as ChartConfig;

        expect(invalidConfig.series).toBeUndefined();
      });

      it('should handle chart config with empty series', () => {
        const configWithEmptySeries: ChartConfig = {
          title: { text: '测试图表' },
          series: []
        };

        expect(configWithEmptyConfig.series).toHaveLength(0);
      });
    });
  });
}