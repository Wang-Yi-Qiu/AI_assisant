# API 密钥长期使用方案

## 📋 问题分析

### 当前架构的问题

1. **成本问题**：
   - Edge Functions 使用服务端环境变量 `DASHSCOPE_API_KEY`（开发者的密钥）
   - 所有用户共享同一个 API Key，所有费用由开发者承担
   - 用户量大时，API 调用成本会非常高

2. **限制问题**：
   - 单个 API Key 可能有调用频率限制（QPS）
   - 大量用户同时使用时可能触发限流
   - 无法区分不同用户的使用情况

3. **安全风险**：
   - 如果服务端 API Key 泄露，影响所有用户
   - 无法对单个用户进行使用量控制

## 🎯 解决方案

### 方案一：用户自带 API Key（推荐）⭐

**优点**：
- ✅ 零成本：用户使用自己的 API Key，开发者不承担费用
- ✅ 无限制：每个用户使用自己的配额，不会相互影响
- ✅ 更安全：API Key 分散存储，降低泄露风险
- ✅ 已实现：客户端已有 `secureKeyManager`，只需修改 Edge Functions

**缺点**：
- ⚠️ 用户需要自己申请 API Key（但这是合理的）
- ⚠️ 需要修改 Edge Functions 支持接收用户 API Key

**实现步骤**：

1. **修改 Edge Functions**：支持从请求头接收用户 API Key
2. **修改客户端**：在调用 Edge Functions 时传递用户 API Key
3. **降级策略**：如果用户没有提供 API Key，使用服务端默认 Key（有限制）

### 方案二：配额管理 + 服务端 API Key

**优点**：
- ✅ 用户体验好：无需用户自己申请 API Key
- ✅ 可控：可以限制每个用户的使用量

**缺点**：
- ❌ 成本高：所有费用由开发者承担
- ❌ 需要实现配额管理系统
- ❌ 需要用户认证和数据库记录

**实现步骤**：

1. 在 Supabase 创建 `user_quotas` 表
2. 每次调用前检查用户配额
3. 调用后扣除配额
4. 实现配额充值/续费机制

### 方案三：混合模式（最佳实践）⭐⭐⭐

**策略**：
- 新用户：提供免费试用额度（使用服务端 API Key）
- 正式用户：引导用户输入自己的 API Key
- 高级功能：必须使用自己的 API Key

**优点**：
- ✅ 降低门槛：新用户可以立即体验
- ✅ 控制成本：正式用户使用自己的 Key
- ✅ 灵活：可以根据功能选择不同的 Key

## 🛠️ 推荐实现：方案一（用户自带 API Key）

### 1. 修改 Edge Functions

修改 `supabase/functions/generate_chart_qwen/index.ts`：

```typescript
// 优先使用用户提供的 API Key，如果没有则使用服务端默认 Key
function getApiKey(req: Request): string | undefined {
  // 从请求头获取用户 API Key
  const userApiKey = req.headers.get('X-User-Api-Key');
  if (userApiKey && userApiKey.trim().length > 0) {
    return userApiKey.trim();
  }
  
  // 降级到服务端默认 Key（用于免费试用）
  return getEnv("DASHSCOPE_API_KEY");
}

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
  // ... 其余代码
}

export default Deno.serve(async (req) => {
  // ...
  const apiKey = getApiKey(req);
  if (!apiKey) {
    return new Response(
      JSON.stringify({ code: "API_KEY_MISSING", message: "请提供 API Key" }),
      { status: 401 }
    );
  }
  
  const content = await callQwenWithRetry([
    { role: "system", content: systemPrompt },
    { role: "user", content: `请根据以下数据返回 ECharts 配置的 JSON：\n${userMsg}` },
  ], apiKey, ctrl.signal, 2);
  // ...
});
```

### 2. 修改客户端调用

修改 `entry/src/main/ets/utils/aiService.ets`：

```typescript
export async function generateChart(userData: UserData, token?: CancellationToken): Promise<ChartConfig> {
  // ... 现有代码 ...
  
  // 获取用户 API Key
  const userApiKey = await secureKeyManager.getApiKey();
  
  // 构建请求头
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'apikey': getSupabaseAnonKey(),
    'Authorization': `Bearer ${authService.getSessionToken() || getSupabaseAnonKey()}`
  };
  
  // 如果用户提供了 API Key，添加到请求头
  if (userApiKey) {
    headers['X-User-Api-Key'] = userApiKey;
  }
  
  const response = await httpClient.supabasePost(
    '/functions/v1/generate_chart_qwen', 
    JSON.stringify(cleanedData),
    headers  // 传递自定义请求头
  );
  
  // ... 其余代码 ...
}
```

### 3. 修改 HTTP 客户端

修改 `entry/src/main/ets/utils/httpClient.ets`，支持自定义请求头：

```typescript
async supabasePost(
  path: string, 
  body: string, 
  customHeaders?: Record<string, string>
): Promise<http.HttpResponse> {
  const url = `${getSupabaseUrl()}${path}`;
  const anonKey = getSupabaseAnonKey();
  const sessionToken = authService.getSessionToken();
  
  const headers: Record<string, string> = {
    'apikey': anonKey,
    'Authorization': `Bearer ${sessionToken || anonKey}`,
    'Content-Type': 'application/json',
    ...customHeaders  // 合并自定义请求头
  };
  
  // ... 发送请求 ...
}
```

### 4. 用户引导界面

在应用首次启动或设置页面，引导用户输入 API Key：

```typescript
// 在 HomePage 或设置页面添加
if (!await secureKeyManager.hasApiKey()) {
  // 显示提示：引导用户输入 API Key
  // 可以提供一个"设置 API Key"按钮
}
```

## 📊 成本对比

### 当前方案（服务端 API Key）
- 1000 用户，每人每天 10 次调用
- 每天：10,000 次调用
- 每月：300,000 次调用
- 成本：约 300-500 元/月（取决于模型和调用量）

### 方案一（用户自带 API Key）
- 开发者成本：0 元
- 用户成本：用户自己承担（通常有免费额度）

## 🔒 安全建议

1. **API Key 传输**：
   - 使用 HTTPS 传输（Supabase 已支持）
   - 不在日志中记录 API Key
   - 请求头中的 Key 不会出现在 URL 中

2. **存储安全**：
   - 客户端使用 `secureKeyManager` 加密存储
   - Edge Functions 不持久化用户 API Key
   - 每次请求临时使用，用完即弃

3. **降级策略**：
   - 服务端默认 Key 仅用于免费试用
   - 设置使用限制（如每天 10 次）
   - 超出限制后提示用户输入自己的 Key

## 🚀 实施建议

### 阶段一：立即实施（方案一）
1. 修改 Edge Functions 支持用户 API Key
2. 修改客户端传递用户 API Key
3. 添加用户引导界面

### 阶段二：优化体验
1. 实现 API Key 验证功能
2. 添加使用量统计
3. 提供 API Key 管理界面

### 阶段三：高级功能（可选）
1. 实现配额管理系统
2. 支持多种付费模式
3. 提供企业版功能

## 📝 总结

**推荐方案**：方案一（用户自带 API Key）

**理由**：
- ✅ 零成本，可持续
- ✅ 实现简单，改动小
- ✅ 用户体验好（已有 secureKeyManager）
- ✅ 安全性高

**下一步**：
1. 修改 Edge Functions 支持用户 API Key
2. 修改客户端传递 API Key
3. 添加用户引导和设置界面

---

**最后更新**：2024年

