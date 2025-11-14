/**
 * 测试运行器
 * @module runner.test
 */

import { describe, beforeAll, afterAll } from '@ohos/hypium';
import httpClientTest from '../utils/httpClient.test.ets';
import authServiceTest from '../utils/authService.test.ets';
import aiServiceTest from '../utils/aiService.test.ets';
import configTest from '../utils/config.test.ets';

export default function testsuite() {
  describe('AI Assistant Test Suite', () => {
    beforeAll(() => {
      console.info('Test suite starting...');
    });

    afterAll(() => {
      console.info('Test suite completed.');
    });

    // 运行所有测试模块
    httpClientTest();
    authServiceTest();
    aiServiceTest();
    configTest();
  });
}