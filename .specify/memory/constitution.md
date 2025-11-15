<!--
Sync Impact Report:
Version: 0.0.0 → 1.0.0
- Initial constitution creation
- Principles derived from pr.md and spec documents
- Templates: ⚠ pending (templates directory not yet created)
- Follow-up: None
-->

# Project Constitution

**Project**: 鸿蒙 AI 智能数据可视化助手（Supabase云端支持版）  
**Version**: 1.0.0  
**Ratified**: 2025-01-28  
**Last Amended**: 2025-01-28

## Purpose

This constitution establishes the non-negotiable principles and governance rules for the HarmonyOS AI Data Visualization Assistant project. All development decisions, code reviews, and architectural choices MUST align with these principles.

## Principles

### Principle 1: 规范先行 (Specification First)

**Rule**: All API contracts, data schemas, and interface definitions MUST be defined in OpenAPI and JSON Schema formats before implementation begins. These specifications MUST pass validation through `spec-kit validate` as a gate before code merge.

**Rationale**: Specification-first development ensures consistency between frontend, backend, and Edge Functions, reduces integration errors, and enables automated contract testing. It provides a single source of truth for all stakeholders.

**Enforcement**: 
- OpenAPI specifications MUST exist in `specs/*/contracts/openapi.yaml`
- JSON Schema files MUST exist in `specs/*/contracts/schemas/`
- CI/CD pipeline MUST run `spec-kit validate` and block merges on failure
- Edge Function implementations MUST validate inputs/outputs against schemas using Ajv

### Principle 2: 云端优先 (Cloud-First)

**Rule**: The application MUST exclusively use Supabase capabilities (Auth, Storage, Database, Edge Functions) for backend services. No self-hosted backend services are permitted without explicit approval.

**Rationale**: Supabase provides a complete, secure, and scalable backend-as-a-service platform that eliminates the need for custom server infrastructure, reduces operational overhead, and ensures consistent security practices.

**Enforcement**:
- All data storage MUST use Supabase Database or Storage
- All authentication MUST use Supabase Auth
- All serverless functions MUST be implemented as Supabase Edge Functions
- Any exception requires documented approval and justification

### Principle 3: 安全合规 (Security & Compliance)

**Rule**: 
- Secrets and API keys MUST NEVER be hardcoded in source code
- Row-Level Security (RLS) policies MUST be enabled on all database tables
- All user inputs and AI model outputs MUST be validated against JSON Schema
- Storage bucket policies MUST restrict access to file owners only

**Rationale**: Security is non-negotiable. Hardcoded secrets create vulnerabilities. RLS ensures data isolation. Schema validation prevents injection attacks and malformed data. Proper access controls protect user privacy.

**Enforcement**:
- Code reviews MUST reject any hardcoded secrets
- Database migrations MUST include RLS policy definitions
- Edge Functions MUST validate inputs using Ajv before processing
- Storage buckets MUST have owner-only read/write policies
- Frontend MUST only hold public anon keys; service keys remain server-side only

### Principle 4: 可观测性与质量 (Observability & Quality)

**Rule**: 
- All logs MUST be structured with requestId, user ID, and operation context
- Error handling MUST use unified error codes and user-friendly messages
- Critical paths MUST have minimum test coverage (unit tests for utilities, contract tests for Edge Functions)
- Performance metrics MUST be collected (P95 latency, success rate, token usage)

**Rationale**: Observability enables rapid debugging and performance optimization. Unified error handling improves user experience. Test coverage prevents regressions. Metrics guide optimization efforts.

**Enforcement**:
- Logging MUST include structured fields (requestId, duration, status)
- ErrorHandler utility MUST be used for all error handling
- Edge Functions MUST have contract tests validating OpenAPI/Schema compliance
- Performance monitoring MUST track key SLOs (P95 ≤ 3s for chart generation)

### Principle 5: 性能与降级 (Performance & Degradation)

**Rule**: 
- All AI service calls MUST have strict timeout controls (default 3s for Edge Functions)
- Fallback templates MUST be provided when AI generation fails or times out
- Large files MUST be processed in chunks with size limits (10MB default)
- Chart rendering MUST support caching of recent configurations

**Rationale**: Timeouts prevent indefinite hangs. Fallback templates ensure the application remains functional even when AI services are unavailable. Chunked processing prevents memory issues. Caching improves user experience.

**Enforcement**:
- Edge Functions MUST implement AbortController with timeout
- Chart generation MUST have fallback ECharts configuration templates
- File uploads MUST validate size before processing
- Recent chart configurations SHOULD be cached locally

### Principle 6: 多设备适配 (Multi-Device Adaptation)

**Rule**: The application MUST support multiple device types (phone, tablet, 2in1, TV, wearable, car, smartVision) with responsive layouts, appropriate input methods, and graceful degradation for unsupported features.

**Rationale**: HarmonyOS targets diverse device categories. Responsive design ensures usability across screen sizes. Graceful degradation maintains core functionality even when device-specific features are unavailable.

**Enforcement**:
- DeviceAdapter utility MUST detect device type and provide layout configurations
- Layouts MUST adapt to screen size, orientation, and window changes
- File upload MUST be hidden/disabled on devices without file picker support
- Export capabilities MUST degrade appropriately (JSON fallback for PNG/PDF on limited devices)
- Focus navigation MUST be supported for TV/car devices
- Wearable interfaces MUST minimize interaction steps (≤2 steps for key tasks)

## Governance

### Amendment Procedure

1. Proposed amendments MUST be documented in a pull request with rationale
2. Amendments affecting principles require review and approval from project maintainers
3. Version MUST be incremented according to semantic versioning:
   - **MAJOR**: Backward incompatible changes to principles or governance
   - **MINOR**: Addition of new principles or significant expansion of existing ones
   - **PATCH**: Clarifications, wording improvements, typo fixes
4. After approval, the constitution MUST be updated and all dependent templates/specs reviewed for consistency

### Compliance Review

- All pull requests MUST be checked against constitution principles
- Code reviews MUST explicitly verify compliance with relevant principles
- CI/CD pipeline SHOULD include automated checks where possible
- Quarterly review of constitution effectiveness and relevance

### Version History

- **1.0.0** (2025-01-28): Initial constitution established based on project requirements and specifications

## Related Documents

- Project Plan: `pr.md`
- Feature Specifications: `specs/001-ai-chart-mvp/spec.md`
- Implementation Plan: `specs/001-ai-chart-mvp/plan.md`
- API Contracts: `specs/001-ai-chart-mvp/contracts/openapi.yaml`
- Data Schemas: `specs/001-ai-chart-mvp/contracts/schemas/`
