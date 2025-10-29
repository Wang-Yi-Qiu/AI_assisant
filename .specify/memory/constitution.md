<!--
Sync Impact Report
- Version change: (new) → 1.0.0
- Modified principles: N/A (initial adoption)
- Added sections: Core Principles; 发布与内容审查要求; 开发工作流与评审流程; Governance
- Removed sections: None
- Templates requiring updates:
  - .specify/templates/plan-template.md ✅ 无需修改（“Constitution Check”门禁与本宪章对齐）
  - .specify/templates/spec-template.md ✅ 无需修改（用户故事/验收对齐宪章的测试与合约要求）
  - .specify/templates/tasks-template.md ✅ 无需修改（分阶段与独立可测规则保持一致）
  - .specify/templates/commands/* ⚠ 不存在该目录（无需处理）
- Follow-up TODOs: 无
-->

# 鸿蒙 AI 智能数据可视化助手（Supabase云端支持版） Constitution

## Core Principles

### 规范先行与契约驱动开发（spec-kit 集成，NON-NEGOTIABLE）
必须以规范为源：OpenAPI 定义接口，JSON Schema/Zod 定义数据契约，Edge Function 入/出参均进行运行时校验；在 CI 中强制执行 `spec-kit validate` 与合约测试，规范未通过禁止合入与发版。

### 云端优先与最小后端（Supabase 为核心能力）
统一依赖 Supabase 提供 Auth、Storage、Database 与 Edge Functions；前端（HarmonyOS/ArkTS）保持“轻”并通过 HTTPS 调用边缘函数；不自建冗余后端，除非出现合规或性能红线并经评审备案。

### 安全与合规为强制要求（密钥、RLS、最小化数据）
密钥零硬编码，分环境注入；启用行级安全（RLS）和 Storage 访问策略；输入输出均按 Schema 校验并限制体积；记录审计日志并实施速率限制与滥用防护；遵循最小必要数据传输与脱敏原则。

### 可观测性与质量门禁（SLO/错误码/合约与单测）
前后端统一结构化日志、指标与错误码；关键 SLO：成功率≥99%，P95≤3s（生成路径）；变更必须通过合约测试与必要的单元/集成测试；出现违例需在 PR 内给出豁免理由与回滚预案。

### 性能优化与离线/降级策略（用户体验优先）
大文件分片与断点续传、WebView 预加载与本地化资源、图表与缩略图缓存；请求设置超时与快速降级（回退模板/命中缓存/区域模型切换）；必要时提供离线浏览最近记录的能力。

### 模型策略与区域合规（默认通义千问 Qwen）
默认采用通义千问（Qwen）并通过 OpenAI 兼容接口调用，`response_format: json_object`、`temperature: 0`；
通过环境变量配置 `DASHSCOPE_API_KEY`、`DASHSCOPE_API_BASE`、`QWEN_MODEL`，密钥不得在前端暴露；
设置严格超时（建议 3s）与统一错误码（如 `QWEN_ERROR`），失败时执行校验与安全降级（回退模板/缓存命中/区域切换）；
遵循数据最小化与本地合规要求，禁止上传超出最小必要的数据；敏感字段需脱敏或汇总。

## 发布与内容审查要求（HarmonyOS 官网发布约束）

发布物不得泄露任何敏感信息（密钥、内部域名、调试端点）；`pr.md` 与规范文档保持同步，包含功能、架构、安全与隐私说明；应用资源（图标/图片/字体/第三方库）具备可追溯许可；中文文案一致、没有占位/英文残留；提供可复现说明（环境变量清单、示例配置、最小演示数据）；通过内部审查清单（功能可用性、安全合规、性能与稳定性、可观测性）后方可提交官网发布。

## 开发工作流与评审流程（Quality Gates）

每个 PR 必须通过以下门禁：
- 规范校验：`spec-kit validate` 与合约测试通过，接口/Schema 变更标注版本影响；
- 安全检查：密钥扫描、RLS/Storage 策略审阅、输入输出 Schema 校验；
- 质量检查：编译与静态检查、关键路径测试（登录→上传→生成→渲染→导出→保存）；
- 版本管理：依据语义化版本确定 bump，并在变更日志中记录；
- 发布核对：`pr.md`、README 与环境变量示例更新完备；必要时附回滚与降级方案。

## Governance

本宪章优先级高于其他实践文档；任何治理变更需在 PR 中说明动机、影响评估、迁移/回滚方案并经审批。

版本策略采用语义化版本：
- MAJOR：治理/原则的破坏性变更或移除；
- MINOR：新增原则或显著扩展指导；
- PATCH：措辞澄清与非语义优化。

合规审查节奏：
- 每次发版前执行合规与门禁复核；
- 每季度进行一次原则适配性回顾，必要时提出修订提案。

例外与豁免：
- 需在 PR 中明确范围与时限，提供替代控制与回滚路径，并由负责人批准备案。

负责人：规范与合规由项目所有者共同维护；日常执行由 CI 门禁与评审共同保障。

**Version**: 1.1.0 | **Ratified**: 2025-10-29 | **Last Amended**: 2025-10-29
