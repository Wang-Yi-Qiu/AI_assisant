/**
 * Edge Function 生成图表测试
 * @module generate_chart_qwen.test
 */

import { assertEquals, assertExists } from 'https://deno.land/std@0.208.0/assert/mod.ts';

// 模拟环境变量
const mockEnv = {
  DASHSCOPE_API_KEY: 'test-api-key',
  QWEN_MODEL: 'qwen-plus',
  DASHSCOPE_API_BASE: 'https://dashscope.aliyuncs.com/compatible-mode/v1'
};

// 模拟 fetch API
let mockFetchCalls: Array<{ url: string; options: RequestInit }> = [];

globalThis.fetch = async (url: string, options: RequestInit = {}) => {
  mockFetchCalls.push({ url, options });

  // 模拟成功的 Qwen API 响应
  if (url.includes('dashscope')) {
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            title: { text: '测试图表' },
            series: [{ type: 'bar', data: [1, 2, 3] }]
          })
        }
      }]
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  return new Response('OK', { status: 200 });
};

// 设置环境变量
for (const [key, value] of Object.entries(mockEnv)) {
  Deno.env.set(key, value);
}

// 导入 Edge Function
import handler from '../generate_chart_qwen/index.ts';

Deno.test('generate_chart_qwen - valid input', async () => {
  const mockInput = {
    "月份": ["1月", "2月", "3月"],
    "销售额": [120, 200, 150]
  };

  const request = new Request('http://localhost:9000', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(mockInput)
  });

  const response = await handler(request);

  assertEquals(response.status, 200);

  const result = await response.json();
  assertExists(result.series);
  assertEquals(Array.isArray(result.series), true);
  assertEquals(result.series.length > 0, true);
});

Deno.test('generate_chart_qwen - invalid input', async () => {
  const invalidInput = null;

  const request = new Request('http://localhost:9000', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(invalidInput)
  });

  const response = await handler(request);

  assertEquals(response.status, 400);

  const result = await response.json();
  assertExists(result.code);
  assertEquals(result.code, 'INVALID_INPUT');
});

Deno.test('generate_chart_qwen - API call parameters', async () => {
  const mockInput = {
    "data": [{"x": 1, "y": 2}, {"x": 2, "y": 4}]
  };

  const request = new Request('http://localhost:9000', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(mockInput)
  });

  await handler(request);

  assertEquals(mockFetchCalls.length, 1);

  const [call] = mockFetchCalls;
  assertEquals(call.url, 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');

  const body = JSON.parse(call.options.body as string);
  assertEquals(body.model, 'qwen-plus');
  assertEquals(body.temperature, 0);
  assertEquals(body.response_format, { type: 'json_object' });
  assertEquals(Array.isArray(body.messages), true);
  assertEquals(body.messages.length, 2);
});

Deno.test('generate_chart_qwen - timeout handling', async () => {
  // 模拟超时响应
  globalThis.fetch = async () => {
    await new Promise(resolve => setTimeout(resolve, 5000)); // 5秒延迟
    return new Response('OK', { status: 200 });
  };

  const mockInput = { "test": "data" };

  const request = new Request('http://localhost:9000', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(mockInput)
  });

  const startTime = Date.now();
  const response = await handler(request);
  const endTime = Date.now();

  // 应该在3秒内超时
  assertEquals(endTime - startTime < 4000, true);
  assertEquals(response.status, 504);

  const result = await response.json();
  assertEquals(result.code, 'QWEN_ERROR');
});

// 清理环境
Deno.testCleanup(() => {
  for (const key of Object.keys(mockEnv)) {
    Deno.env.delete(key);
  }
  mockFetchCalls = [];
});