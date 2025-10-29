// Deno Edge Function: generate_chart_qwen
// Minimal implementation with input/output schema validation and Qwen-compatible call

// deno-lint-ignore-file no-explicit-any
import { Ajv } from "https://esm.sh/ajv";

// NOTE: In a real deployment, move schemas into the function package. Here we inline minimal guards.
const userDataSchema: any = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://example.com/schemas/userData.schema.json",
  title: "UserData",
  description: "用户上传的数据，可为结构化 JSON 或 CSV 解析后的对象",
  type: ["object", "array", "string"],
};

const chartConfigSchema: any = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://example.com/schemas/chartConfig.schema.json",
  title: "EChartsConfig",
  type: "object",
  properties: {
    title: {
      type: "object",
      properties: { text: { type: "string" } },
      required: ["text"],
    },
    series: {
      type: "array",
      items: {
        type: "object",
        properties: { type: { type: "string" } },
        required: ["type"],
      },
      minItems: 1,
    },
  },
  required: ["series"],
};

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(userDataSchema);
const validateOut = ajv.compile(chartConfigSchema);

const API_BASE = Deno.env.get("DASHSCOPE_API_BASE")?.replace(/\/$/, "") ||
  "https://dashscope.aliyuncs.com/compatible-mode/v1";
const API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const MODEL = Deno.env.get("QWEN_MODEL") || "qwen-plus";

const systemPrompt = `你是数据可视化专家。依据用户提供的数据生成严格符合 ECharts 的 JSON；不要输出任何非 JSON 文本。`;

async function callQwen(messages: Array<{ role: string; content: string }>, signal?: AbortSignal) {
  if (!API_KEY) throw new Error("DASHSCOPE_API_KEY missing");
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: MODEL, temperature: 0, response_format: { type: "json_object" }, messages }),
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

export default Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();
  const startTime = Date.now();
  console.log(JSON.stringify({ requestId, timestamp: new Date().toISOString(), action: 'chart_generation_start' }));
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort("timeout"), 3000);
  try {
    const body = await req.json();
    if (!validateIn(body)) {
      return new Response(
        JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }),
        { status: 400 },
      );
    }
    const userMsg = typeof body === "string" ? body : JSON.stringify(body);
    const content = await callQwen([
      { role: "system", content: systemPrompt },
      { role: "user", content: `请根据以下数据返回 ECharts 配置的 JSON：\n${userMsg}` },
    ], ctrl.signal);

    let json: unknown;
    try {
      json = JSON.parse(content);
    } catch {
      return new Response(JSON.stringify({ code: "INVALID_JSON_OUTPUT" }), { status: 502 });
    }
    if (!validateOut(json)) {
      const fallback = {
        title: { text: "AI 推荐图表" },
        tooltip: {},
        xAxis: { type: "category" },
        yAxis: { type: "value" },
        series: [{ type: "line", data: [] }],
      };
      return new Response(JSON.stringify(fallback), { headers: { "Content-Type": "application/json" } });
    }
    const duration = Date.now() - startTime;
    console.log(JSON.stringify({ requestId, duration, action: 'chart_generation_success' }));
    return new Response(JSON.stringify(json), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    const status = String(e?.message || e).includes("timeout") ? 504 : 500;
    const duration = Date.now() - startTime;
    console.error(JSON.stringify({ requestId, duration, error: String(e?.message || e), code: "QWEN_ERROR", action: 'chart_generation_error' }));
    return new Response(JSON.stringify({ code: "QWEN_ERROR", message: String(e?.message || e) }), { status });
  } finally {
    clearTimeout(timeout);
  }
});


