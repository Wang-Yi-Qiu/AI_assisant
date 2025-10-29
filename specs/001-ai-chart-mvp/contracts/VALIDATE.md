# Schema Validation Guide

## Purpose

Ensure contracts and schemas are validated before deployment and during CI.

## Manual Validation (Placeholder)

Until `spec-kit validate` is integrated, manually verify:

1. **OpenAPI**: Use https://editor.swagger.io/ or `swagger-codegen validate`
2. **JSON Schema**: Use https://www.jsonschemavalidator.net/ or Ajv (used in Edge Function)

## CI Integration (TODO)

Add to CI pipeline:

```bash
# Validate OpenAPI
npx @apidevtools/swagger-cli validate specs/001-ai-chart-mvp/contracts/openapi.yaml

# Validate JSON Schemas (using Ajv in Deno context)
deno check supabase/functions/generate_chart_qwen.ts
```

## Contract Testing

Edge Function already validates input/output schemas at runtime (see `generate_chart_qwen.ts`).

