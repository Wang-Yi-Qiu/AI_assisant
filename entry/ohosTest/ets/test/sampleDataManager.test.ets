/**
 * 样本数据管理器单元测试
 * @module sampleDataManager.test
 */

import { describe, it, expect } from '@ohos/hypium';
import { getSampleDataList, SampleDataset } from '../../src/main/ets/utils/sampleDataManager';

export default function SampleDataManagerTests() {
  describe('SampleDataManager Tests', () => {
    it('should return sample data list', () => {
      const list = getSampleDataList();
      expect(list).toBeDefined();
      expect(Array.isArray(list)).toBeTruthy();
      expect(list.length).toBeGreaterThan(0);
    });

    it('should have valid sample data structure', () => {
      const list = getSampleDataList();
      list.forEach((item: SampleDataset) => {
        expect(item.id).toBeDefined();
        expect(item.name).toBeDefined();
        expect(item.description).toBeDefined();
        expect(item.filePath).toBeDefined();
        expect(item.category).toBeDefined();
      });
    });

    it('should have unique IDs', () => {
      const list = getSampleDataList();
      const ids = list.map((item: SampleDataset) => item.id);
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).assertEqual(ids.length);
    });
  });
}

