// Deno Edge Function: generate_insight
// AI洞察生成服务，支持图表数据洞察和专注数据洞察

// deno-lint-ignore-file no-explicit-any
import { Ajv } from "https://esm.sh/ajv";

// 输入Schema：请求体结构
const insightRequestSchema: any = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://example.com/schemas/insightRequest.schema.json",
  title: "InsightRequest",
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

// 输出Schema：洞察响应格式
const insightResponseSchema: any = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://example.com/schemas/insightSchema.json",
  title: "AIInsight",
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
      type: "object",
      properties: {
        model: { type: "string" },
        generatedAt: { type: "string" },
        dataHash: { type: "string" }
      }
    }
  },
  required: ["insightText"],
  additionalProperties: false
};

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(insightRequestSchema);
const validateOut = ajv.compile(insightResponseSchema);

function getEnv(name: string): string | undefined {
  try { return Deno.env.get(name) ?? undefined; } catch { return undefined; }
}

const API_BASE_DEFAULT = "https://dashscope.aliyuncs.com/compatible-mode/v1";
function getApiBase(): string {
  const base = getEnv("DASHSCOPE_API_BASE");
  return (base?.replace(/\/$/, "") || API_BASE_DEFAULT);
}
function getApiKey(): string | undefined {
  return getEnv("DASHSCOPE_API_KEY");
}
function getModel(): string {
  return getEnv("QWEN_MODEL") || "qwen-plus";
}

// 图表洞察的system prompt
const chartInsightPrompt = `你是数据分析专家。基于用户提供的图表数据，生成结构化的数据洞察分析。分析必须包含以下三个部分：
1. **趋势分析**：分析数据的变化趋势（上升、下降、波动等），识别主要趋势模式
2. **关键点**：识别数据中的关键信息，包括最大值、最小值、异常值、峰值、低谷等
3. **建议**：基于数据分析提供操作建议，如"建议关注X月的异常下降"、"建议分析Y数据的快速增长原因"等

请以JSON格式返回，包含以下字段：
- insightText: 完整的洞察文本（必须包含趋势分析、关键点、建议三部分）
- confidence: 置信度（0-1之间的数字）
- suggestions: 结构化的建议列表（可选）

确保返回的JSON格式严格符合要求，不要包含任何非JSON文本。`;

// 专注洞察的system prompt
const focusInsightPrompt = `你是专注力分析专家。基于用户提供的专注时间数据，生成结构化的专注力分析报告。分析必须包含以下内容：
1. **专注趋势**：分析专注时间的变化趋势（上升、下降、波动等）
2. **最佳时段**：识别用户专注力最高的时间段
3. **改进建议**：基于数据分析提供专注力提升建议

请以JSON格式返回，包含以下字段：
- insightText: 完整的分析报告文本（必须包含专注趋势、最佳时段、改进建议）
- confidence: 置信度（0-1之间的数字）
- suggestions: 结构化的建议列表（可选）

确保返回的JSON格式严格符合要求，不要包含任何非JSON文本。`;

async function callQwen(messages: Array<{ role: string; content: string }>, signal?: AbortSignal) {
  const API_KEY = getApiKey();
  const API_BASE = getApiBase();
  const MODEL = getModel();
  if (!API_KEY) throw new Error("DASHSCOPE_API_KEY missing");
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ 
      model: MODEL, 
      temperature: 0, 
      response_format: { type: "json_object" }, 
      messages 
    }),
    signal,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DashScope error: ${res.status} ${text}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) throw new Error("Empty Qwen response");
  return content;
}

// 降级提示（当AI服务不可用时返回）
function getFallbackInsight(type: "chart" | "focus"): any {
  if (type === "chart") {
    return {
      insightText: "AI洞察暂时不可用，请稍后重试。图表数据已正常显示，您可以继续使用其他功能。",
      confidence: 0.5,
      suggestions: [],
      metadata: {
        model: "fallback",
        generatedAt: new Date().toISOString()
      }
    };
  } else {
    return {
      insightText: "AI洞察暂时不可用，请稍后重试。专注数据已正常显示，您可以继续使用其他功能。",
      confidence: 0.5,
      suggestions: [],
      metadata: {
        model: "fallback",
        generatedAt: new Date().toISOString()
      }
    };
  }
}

export default Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();
  const startTime = Date.now();
  const hasKey = Boolean(getApiKey());
  console.log(JSON.stringify({ requestId, timestamp: new Date().toISOString(), action: 'insight_generation_start', hasDashscopeKey: hasKey }));
  
  const ctrl = new AbortController();
  // 5秒超时
  const timeout = setTimeout(() => ctrl.abort("timeout"), 5000);
  
  try {
    const body = await req.json();
    
    // 输入Schema校验
    if (!validateIn(body)) {
      return new Response(
        JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const { type, data } = body;
    
    // 根据类型选择不同的prompt
    let systemPrompt: string;
    let userContent: string;
    
    if (type === "chart") {
      systemPrompt = chartInsightPrompt;
      // 构建图表数据的用户消息
      const chartData = data.chartConfig || data.rawData || data;
      userContent = `请分析以下图表数据：\n${JSON.stringify(chartData, null, 2)}`;
    } else if (type === "focus") {
      systemPrompt = focusInsightPrompt;
      // 构建专注数据的用户消息
      const focusData = data.focusData || data;
      userContent = `请分析以下专注时间数据：\n用户ID: ${data.userId}\n周期: ${data.period}\n时间范围: ${data.periodStart} 至 ${data.periodEnd}\n数据: ${JSON.stringify(focusData, null, 2)}`;
    } else {
      return new Response(
        JSON.stringify({ code: "INVALID_TYPE", message: "Invalid insight type" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 调用Qwen模型
    const messages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: userContent }
    ];

    const qwenResponse = await callQwen(messages, ctrl.signal);
    clearTimeout(timeout);

    // 解析Qwen响应（应该是JSON格式）
    let insightData: any;
    try {
      insightData = JSON.parse(qwenResponse);
    } catch (e) {
      // 如果解析失败，尝试提取JSON部分
      const jsonMatch = qwenResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        insightData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error("Failed to parse Qwen response as JSON");
      }
    }

    // 验证输出Schema
    if (!validateOut(insightData)) {
      console.error("Output validation failed:", validateOut.errors);
      // 如果验证失败，使用降级提示
      const fallback = getFallbackInsight(type);
      return new Response(
        JSON.stringify(fallback),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 确保必要字段存在
    if (!insightData.insightText || insightData.insightText.trim().length === 0) {
      const fallback = getFallbackInsight(type);
      return new Response(
        JSON.stringify(fallback),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 设置默认值
    if (insightData.confidence === undefined || insightData.confidence === null) {
      insightData.confidence = 0.8;
    }
    if (!insightData.suggestions) {
      insightData.suggestions = [];
    }
    if (!insightData.metadata) {
      insightData.metadata = {};
    }
    insightData.metadata.model = getModel();
    insightData.metadata.generatedAt = new Date().toISOString();

    const duration = Date.now() - startTime;
    console.log(JSON.stringify({ requestId, timestamp: new Date().toISOString(), action: 'insight_generation_success', duration, type }));

    return new Response(
      JSON.stringify(insightData),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error: any) {
    clearTimeout(timeout);
    
    const duration = Date.now() - startTime;
    const errorMessage = error?.message || String(error);
    
    console.error(JSON.stringify({ requestId, timestamp: new Date().toISOString(), action: 'insight_generation_error', duration, error: errorMessage }));

    // 超时或服务错误时返回降级提示
    if (errorMessage.includes("timeout") || errorMessage.includes("abort")) {
      const fallback = getFallbackInsight(body?.type || "chart");
      return new Response(
        JSON.stringify(fallback),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // 其他错误返回错误响应
    return new Response(
      JSON.stringify({ 
        code: "INSIGHT_GENERATION_FAILED", 
        message: "AI洞察生成失败，请稍后重试",
        error: errorMessage 
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

