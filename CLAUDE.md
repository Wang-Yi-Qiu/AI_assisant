# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a HarmonyOS (鸿蒙) AI-powered data visualization assistant that uses Supabase as a cloud backend. The app allows users to input/upload data, generate charts using AI (通义千问 Qwen), and export results in multiple formats.

**Core Technologies:**
- Frontend: HarmonyOS ArkTS + ECharts (WebView)
- Backend: Supabase (Auth/Storage/Database/Edge Functions)
- AI Model: 通义千问 (Qwen) via DashScope OpenAI-compatible API
- Build System: DevEco Studio + Hvigor

## Development Commands

### Frontend (HarmonyOS)
```bash
# Build and run using DevEco Studio
# No CLI commands available - use DevEco Studio IDE
```

### Edge Functions (Supabase)
```bash
# Deploy Edge Function
supabase functions deploy generate_chart_qwen

# Set environment variables for Edge Functions
supabase secrets set DASHSCOPE_API_KEY=your_key
supabase secrets set QWEN_MODEL=qwen-plus
supabase secrets set DASHSCOPE_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1

# Test Edge Function locally (if needed)
supabase functions serve generate_chart_qwen --no-verify-jwt
```

### Project Structure and Key Files

```
├── entry/src/main/ets/
│   ├── pages/
│   │   ├── Index.ets           # Main entry page
│   │   ├── HomePage.ets        # Data input and upload
│   │   ├── ChartPage.ets       # Chart rendering and export
│   │   └── HistoryPage.ets     # Historical records
│   ├── utils/
│   │   ├── config.ets          # Runtime configuration
│   │   ├── supabaseClient.ets  # Supabase client wrapper
│   │   ├── aiService.ets       # AI service wrapper
│   │   ├── metrics.ets         # Performance metrics
│   │   └── fileAccess.ets      # File access utilities
│   ├── entryability/EntryAbility.ets  # App entry point
│   └── resources/rawfile/supabase.json # Local config (git-ignored)
├── supabase/
│   ├── functions/generate_chart_qwen/  # Edge Function
│   │   ├── index.ts           # Main function code
│   │   └── deno.json          # Deno configuration
│   └── types/database.types.ts # Generated TypeScript types
└── specs/001-ai-chart-mvp/    # Specifications and contracts
```

## Architecture Notes

### Frontend-Backend Communication
- Frontend uses Supabase SDK with anon key for authentication
- AI generation calls go through Supabase Edge Functions to keep API keys secure
- Edge Function validates input/output using JSON Schema (Ajv)
- All data is stored in Supabase PostgreSQL with Row Level Security (RLS)

### Configuration Management
- **Environment variables**: Stored in `.env` file (git-ignored)
- **Runtime config**: Loaded from `entry/src/main/resources/rawfile/supabase.json`
- **Supabase secrets**: Set via Dashboard or CLI (`supabase secrets set`)
- **Security**: Only anon keys in frontend, API keys only in Edge Functions

### Data Flow
1. User inputs/uploads data via `HomePage.ets`
2. Data sent to Supabase Edge Function `generate_chart_qwen`
3. Edge Function calls Qwen AI model with system prompt
4. AI generates ECharts configuration, validated against schema
5. Result stored in Supabase `charts` table with user association
6. Frontend retrieves and renders chart in WebView via `ChartPage.ets`

## Key Implementation Details

### AI Service (`utils/aiService.ets`)
- Handles API calls to Supabase Edge Functions
- Implements retry logic and error handling
- Tracks performance metrics (requestId, duration, success rate)
- Returns structured responses with proper error codes

### Supabase Client (`utils/supabaseClient.ets`)
- Initialized with runtime configuration from `config.ets`
- Handles authentication state and user sessions
- Provides typed database operations using generated types

### Edge Function (`supabase/functions/generate_chart_qwen/`)
- Validates input using JSON Schema (`userData.schema.json`)
- Calls Qwen AI model via DashScope OpenAI-compatible API
- Validates output against ECharts schema (`chartConfig.schema.json`)
- Implements timeout (3s) and fallback templates
- Structured logging with requestId and performance tracking

### File Access (`utils/fileAccess.ets`)
- Handles PNG/PDF/JSON export functionality
- Integrates with HarmonyOS file system APIs
- Placeholder for actual file saving implementation

## Development Guidelines

### Code Style
- Follow HarmonyOS ArkTS conventions
- Use TypeScript for type safety where supported
- Implement proper error handling with user-friendly Chinese messages
- Maintain modular structure with clear separation of concerns

### Security Practices
- Never expose API keys in frontend code
- Use Supabase RLS policies for data access control
- Validate all inputs/outputs using JSON Schema
- Implement rate limiting in Edge Functions

### Testing Strategy
- Unit tests for core utilities (metrics, fileAccess)
- Contract tests for Edge Function schema validation
- Integration tests for Supabase client operations
- E2E tests for complete user workflows

## Environment Setup

### Required Environment Variables
```bash
# Supabase Configuration (frontend)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# Edge Functions (backend - set in Supabase Dashboard)
DASHSCOPE_API_KEY=your_dashscope_key
QWEN_MODEL=qwen-plus
DASHSCOPE_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
EDGE_REQUEST_TIMEOUT_MS=3000
```

### Local Development
1. Configure `entry/src/main/resources/rawfile/supabase.json` with local Supabase URL and anon key
2. Set Edge Function environment variables via Supabase Dashboard or CLI
3. Use DevEco Studio for frontend development and debugging
4. Test Edge Functions using `supabase functions serve` for local testing

### Verification
Use the provided verification script to check Edge Function connectivity:
```bash
bash ./commands/verify_edge.sh
```

## Common Tasks

### Adding New Chart Types
1. Update `chartConfig.schema.json` with new chart structure
2. Modify AI system prompt in Edge Function to include new chart types
3. Update frontend rendering logic in `ChartPage.ets`
4. Add corresponding test cases

### Updating AI Model Configuration
1. Modify environment variables in Supabase Dashboard
2. Update Edge Function prompt and model parameters
3. Test with various data inputs and validate outputs
4. Update documentation in `pr.md`

### Adding New Export Formats
1. Extend `utils/fileAccess.ets` with new export methods
2. Update UI in `ChartPage.ets` to include new export options
3. Add corresponding file type handling in HarmonyOS file system integration

## Important Notes

- This project follows **spec-first development** using the spec-kit framework
- All API contracts are defined in `specs/001-ai-chart-mvp/contracts/`
- Use `/speckit.analyze` to check documentation consistency
- Database schema changes require updating RLS policies
- WebView integration for ECharts is currently a placeholder requiring native HarmonyOS APIs

## Troubleshooting

### Common Issues
- **401 Unauthorized**: Check anon key configuration in `supabase.json`
- **404 Not Found**: Verify Edge Function deployment status
- **504 Timeout**: Increase timeout or check AI model availability
- **Build errors**: Ensure `deviceTypes` is limited to `phone` in `module.json5`

### Debug Commands
```bash
# Check Edge Function logs
supabase functions logs generate_chart_qwen

# Verify database schema
supabase db describe charts

# Test Edge Function directly
curl -X POST https://your-project.supabase.co/functions/v1/generate_chart_qwen \
  -H "Authorization: Bearer your_anon_key" \
  -H "Content-Type: application/json" \
  -d '{"data": [{"x": 1, "y": 2}]}'
```
###After completing the modification project, there is no need to create related files. I will modify them when I need you to. Also, save them with git when making modifications.