# Quickstart — AI 可视化最小闭环（Qwen 模型）

## 前置
- 准备演示账户；应用已安装到设备；已配置环境变量于服务端（不要在前端暴露密钥）。

## 步骤
1. 登录应用（Supabase Auth）。
2. 在首页选择 CSV/JSON 或粘贴文本 → 点击“生成图表”。
3. 观察图表渲染完成（期望 3 秒内）。
4. 点击“导出 PNG”，在系统文件/相册中查看导出结果。
5. 前往“历史”查看刚刚生成的图表记录并点开复现。

## 鉴权与配置（新增）
- 前端以 `Authorization: Bearer <anon key>` 与 `apikey: <anon key>` 调用 Edge；URL 来自 `getSupabaseUrl()` + `/functions/v1/generate_chart_qwen`。
- AppScope/构建变量已注入 `SUPABASE_URL`、`SUPABASE_ANON_KEY`；不要在代码中硬编码密钥。

## 期望结果
- 闭环在 3 分钟内完成；生成成功率高；历史页可见记录并可复现。

## 故障排查
- 提示“输入无效”：检查文件类型与大小、文本格式。
- 提示“生成超时”或“降级”：稍后重试或更换数据规模；结果可能使用回退模板。
 - 401 未授权：检查 anon key 是否注入，并确认请求头包含 `Authorization` 与 `apikey`。
 - 404 函数未找到：检查函数是否已部署，路径是否为 `/functions/v1/generate_chart_qwen` 或约定别名。
 - 504 超时：稍后重试；可在 Edge 日志确认是否触发模型/网络超时。

## 度量方法（性能与观测）
- 客户端埋点：`utils/metrics.ets` 提供 `startTimer/endTimer` 与 `newRequestId`；
  - 在 `aiService.generateChart` 内输出结构化日志：`{"action":"chart_generation_client","duration":...,"requestId":"...","ok":true}`。
- 指标采集：
  - 记录“生成路径 P95”（从点击生成到收到配置）与“历史页加载 P95”（从进入页面到列表渲染）。
  - 在 PR 中粘贴一次演示日志样例与 P95 粗略统计。
