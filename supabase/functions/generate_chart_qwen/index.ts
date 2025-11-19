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

function getEnv(name: string): string | undefined {
  try { return Deno.env.get(name) ?? undefined; } catch { return undefined; }
}

const API_BASE_DEFAULT = "https://dashscope.aliyuncs.com/compatible-mode/v1";
function getApiBase(): string {
  const base = getEnv("DASHSCOPE_API_BASE");
  return (base?.replace(/\/$/, "") || API_BASE_DEFAULT);
}
/**
 * 获取 API Key：优先使用用户提供的 Key，如果没有则使用服务端默认 Key
 * @param req 请求对象，用于获取请求头中的用户 API Key
 * @returns API Key 字符串，如果都不存在则返回 undefined
 */
function getApiKey(req?: Request): string | undefined {
  // 优先从请求头获取用户提供的 API Key
  if (req) {
    const userApiKey = req.headers.get("X-User-Api-Key");
    if (userApiKey && userApiKey.trim().length > 0) {
      console.log("使用用户提供的 API Key");
      return userApiKey.trim();
    }
  }
  
  // 降级到服务端默认 Key（用于免费试用或未设置 Key 的用户）
  const serverKey = getEnv("DASHSCOPE_API_KEY");
  if (serverKey) {
    console.log("使用服务端默认 API Key");
  }
  return serverKey;
}
function getModel(): string {
  return getEnv("QWEN_MODEL") || "qwen-plus";
}

const systemPrompt = `你是数据可视化专家。依据用户提供的数据生成严格符合 ECharts Option 的 JSON；不要输出任何非 JSON 文本。按以下要求：
1) 自动选择合适图表类型（如 bar/line/pie/scatter），
2) 生成最小必要字段（title、legend、tooltip、xAxis/yAxis、series），
3) 文本请使用简体中文，
4) 若输入信息不足，合理假设并给出可渲染的配置。`;

async function callQwen(messages: Array<{ role: string; content: string }>, apiKey: string, signal?: AbortSignal) {
  const API_BASE = getApiBase();
  const MODEL = getModel();
  if (!apiKey) throw new Error("API Key missing");
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
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

/**
 * 获取或创建用户配额
 */
async function getUserQuota(userId: string): Promise<{ total: number; used: number; remaining: number } | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  
  if (!supabaseUrl || !supabaseServiceKey) {
    console.warn("Supabase 配置缺失，无法检查配额");
    return null;
  }

  try {
    // 查询用户配额
    const response = await fetch(`${supabaseUrl}/rest/v1/user_quotas?user_id=eq.${encodeURIComponent(userId)}&select=*`, {
      method: "GET",
      headers: {
        "apikey": supabaseServiceKey,
        "Authorization": `Bearer ${supabaseServiceKey}`,
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      console.warn(`查询配额失败: ${response.status}`);
      return null;
    }

    const quotas = await response.json();
    
    if (quotas && quotas.length > 0) {
      const quota = quotas[0];
      return {
        total: quota.total_quota || 10,
        used: quota.used_quota || 0,
        remaining: (quota.total_quota || 10) - (quota.used_quota || 0)
      };
    } else {
      // 如果没有配额记录，创建一条（默认10次）
      const createResponse = await fetch(`${supabaseUrl}/rest/v1/user_quotas`, {
        method: "POST",
        headers: {
          "apikey": supabaseServiceKey,
          "Authorization": `Bearer ${supabaseServiceKey}`,
          "Content-Type": "application/json",
          "Prefer": "return=representation"
        },
        body: JSON.stringify({
          user_id: userId,
          total_quota: 10,
          used_quota: 0
        })
      });

      if (createResponse.ok) {
        const newQuota = await createResponse.json();
        return {
          total: newQuota[0]?.total_quota || 10,
          used: newQuota[0]?.used_quota || 0,
          remaining: 10
        };
      }
    }
  } catch (error) {
    console.error("配额查询异常:", error);
  }

  return null;
}

/**
 * 扣除用户配额
 */
async function consumeQuota(userId: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  
  if (!supabaseUrl || !supabaseServiceKey) {
    return false;
  }

  try {
    // 先查询当前配额
    const quota = await getUserQuota(userId);
    if (!quota || quota.remaining <= 0) {
      return false;
    }

    // 更新配额（增加已使用次数）
    const response = await fetch(`${supabaseUrl}/rest/v1/user_quotas?user_id=eq.${encodeURIComponent(userId)}`, {
      method: "PATCH",
      headers: {
        "apikey": supabaseServiceKey,
        "Authorization": `Bearer ${supabaseServiceKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        used_quota: quota.used + 1
      })
    });

    return response.ok;
  } catch (error) {
    console.error("扣除配额异常:", error);
    return false;
  }
}

export default Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();
  const startTime = Date.now();
  
  // 获取用户ID（从请求头或使用匿名ID）
  const userId = req.headers.get("X-User-Id") || `anonymous-${crypto.randomUUID()}`;
  
  // 获取 API Key（优先用户 Key，降级到服务端 Key）
  const apiKey = getApiKey(req);
  const hasKey = Boolean(apiKey);
  const isUserKey = Boolean(req.headers.get("X-User-Api-Key"));
  
  console.log(JSON.stringify({ 
    requestId, 
    timestamp: new Date().toISOString(), 
    action: 'chart_generation_start', 
    hasDashscopeKey: hasKey,
    isUserKey: isUserKey,
    userId: userId
  }));
  
  // 如果没有用户 API Key，检查配额
  if (!isUserKey) {
    const quota = await getUserQuota(userId);
    
    if (!quota || quota.remaining <= 0) {
      return new Response(
        JSON.stringify({ 
          code: "QUOTA_EXCEEDED", 
          message: `免费配额已用完（已使用 ${quota?.used || 0}/${quota?.total || 10} 次）。请设置您自己的 DashScope API Key 以继续使用。`,
          quota: quota
        }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }
    
    console.log(JSON.stringify({
      requestId,
      action: 'quota_check',
      remaining: quota.remaining,
      used: quota.used,
      total: quota.total
    }));
  }
  
  // 如果没有 API Key（既没有用户 Key 也没有服务端 Key），返回错误
  if (!apiKey) {
    return new Response(
      JSON.stringify({ 
        code: "API_KEY_MISSING", 
        message: "请提供 API Key。您可以在应用设置中输入自己的 DashScope API Key，或联系开发者获取帮助。" 
      }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort("timeout"), 15000);
  try {
    const body = await req.json();
    if (!validateIn(body)) {
      return new Response(
        JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }),
        { status: 400 },
      );
    }
    const userMsg = typeof body === "string" ? body : JSON.stringify(body);
    // 轻量重试，缓解偶发网络/后端抖动（仅对非4xx错误重试）
    async function callQwenWithRetry(messages: Array<{ role: string; content: string }>, key: string, signal?: AbortSignal, maxRetries = 2): Promise<string> {
      let attempt = 0;
      // eslint-disable-next-line no-constant-condition
      while (true) {
        try {
          return await callQwen(messages, key, signal);
        } catch (e) {
          const msg = String(e?.message || e);
          const isClientError = /^DashScope error: 4\d{2}/.test(msg);
          if (attempt >= maxRetries || isClientError) throw e;
          const backoffMs = 500 * (attempt + 1);
          await new Promise((r) => setTimeout(r, backoffMs));
          attempt++;
        }
      }
    }

    const content = await callQwenWithRetry([
      { role: "system", content: systemPrompt },
      { role: "user", content: `请根据以下数据返回 ECharts 配置的 JSON：\n${userMsg}` },
    ], apiKey, ctrl.signal, 2);

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
    // 如果使用的是服务端 Key（不是用户 Key），扣除配额
    if (!isUserKey) {
      const consumed = await consumeQuota(userId);
      if (consumed) {
        console.log(JSON.stringify({ requestId, action: 'quota_consumed', userId }));
      } else {
        console.warn(JSON.stringify({ requestId, action: 'quota_consume_failed', userId }));
      }
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


