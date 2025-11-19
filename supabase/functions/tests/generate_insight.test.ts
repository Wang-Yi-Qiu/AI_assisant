/**
 * generate_insight Edge Function 合约测试
 * 基于OpenAPI/Schema的请求-响应校验测试
 */

import { assertEquals, assertExists } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { Ajv } from "https://esm.sh/ajv@8.12.0";

// 输入Schema
const insightRequestSchema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  type: "object",
  properties: {
    type: {
      type: "string",
      enum: ["chart", "focus"]
    },
    data: {
      type: "object"
    }
  },
  required: ["type", "data"]
};

// 输出Schema
const insightResponseSchema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  type: "object",
  properties: {
    insightText: {
      type: "string",
      minLength: 1
    },
    confidence: {
      type: "number",
      minimum: 0,
      maximum: 1
    },
    suggestions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          type: { type: "string" },
          text: { type: "string" },
          priority: { type: "string", enum: ["high", "medium", "low"] }
        },
        required: ["type", "text"]
      }
    },
    metadata: {
      type: "object"
    }
  },
  required: ["insightText"],
  additionalProperties: false
};

const ajv = new Ajv({ allErrors: true });
const validateRequest = ajv.compile(insightRequestSchema);
const validateResponse = ajv.compile(insightResponseSchema);

Deno.test("generate_insight: Request schema validation", () => {
  // 有效的图表洞察请求
  const validChartRequest = {
    type: "chart",
    data: {
      chartConfig: {
        series: [{ type: "line", data: [1, 2, 3] }]
      }
    }
  };
  assertEquals(validateRequest(validChartRequest), true);

  // 有效的专注洞察请求
  const validFocusRequest = {
    type: "focus",
    data: {
      userId: "test-user-id",
      period: "week",
      periodStart: "2025-01-01",
      periodEnd: "2025-01-07",
      focusData: { totalMinutes: 120 }
    }
  };
  assertEquals(validateRequest(validFocusRequest), true);

  // 无效请求：缺少type
  const invalidRequest1 = {
    data: { chartConfig: {} }
  };
  assertEquals(validateRequest(invalidRequest1), false);

  // 无效请求：无效的type
  const invalidRequest2 = {
    type: "invalid",
    data: {}
  };
  assertEquals(validateRequest(invalidRequest2), false);
});

Deno.test("generate_insight: Response schema validation", () => {
  // 有效的响应
  const validResponse = {
    insightText: "这是AI生成的洞察文本",
    confidence: 0.8,
    suggestions: [
      {
        type: "action",
        text: "建议关注数据趋势",
        priority: "high"
      }
    ],
    metadata: {
      model: "qwen-plus",
      generatedAt: "2025-01-28T00:00:00Z"
    }
  };
  assertEquals(validateResponse(validResponse), true);

  // 最小有效响应（只有insightText）
  const minimalResponse = {
    insightText: "最小洞察文本"
  };
  assertEquals(validateResponse(minimalResponse), true);

  // 无效响应：缺少insightText
  const invalidResponse1 = {
    confidence: 0.8
  };
  assertEquals(validateResponse(invalidResponse1), false);

  // 无效响应：insightText为空
  const invalidResponse2 = {
    insightText: ""
  };
  assertEquals(validateResponse(invalidResponse2), false);

  // 无效响应：confidence超出范围
  const invalidResponse3 = {
    insightText: "有效文本",
    confidence: 1.5 // 超出0-1范围
  };
  assertEquals(validateResponse(invalidResponse3), false);
});

Deno.test("generate_insight: Contract compliance", () => {
  // 验证请求和响应Schema符合OpenAPI定义
  // 这些测试确保实现符合 contracts/openapi.yaml 中的定义
  
  // 图表洞察请求格式
  const chartRequest = {
    type: "chart",
    data: {
      chartConfig: {
        title: { text: "测试图表" },
        series: [{ type: "line", data: [1, 2, 3] }]
      }
    }
  };
  assertEquals(validateRequest(chartRequest), true);

  // 专注洞察请求格式
  const focusRequest = {
    type: "focus",
    data: {
      userId: "user-123",
      period: "month",
      periodStart: "2025-01-01",
      periodEnd: "2025-01-31",
      focusData: {
        totalMinutes: 500,
        dailyData: []
      }
    }
  };
  assertEquals(validateRequest(focusRequest), true);
});

