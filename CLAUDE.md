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
## Latest HarmonyOS Development Updates (2024-2025)

### Version Updates
- **HarmonyOS 5.0**: Latest stable release with enhanced AI capabilities
- **API Level 12**: New APIs for AI integration and performance optimization
- **DevEco Studio 5.0**: Updated IDE with better debugging and profiling tools

### New AI Development Features
- **HiAI Foundation**: Enhanced on-device AI inference capabilities
- **LLM Integration**: Built-in support for large language model integration
- **Neural Network APIs**: Improved neural network processing and optimization
- **Cross-device AI**: Seamless AI capabilities across HarmonyOS devices

### Breaking Changes & Deprecated APIs
- **WebView Component**: Updated security model for WebView content loading
- **File Access**: New permission model for file system access
- **Network APIs**: Enhanced security requirements for HTTP requests
- **UI Components**: Deprecated some legacy UI component APIs

### New Security Requirements
- **Runtime Permissions**: Enhanced permission model for AI features
- **Data Privacy**: Stricter requirements for user data handling
- **API Key Security**: Mandatory secure storage for third-party API keys
- **Network Security**: HTTPS enforcement for all API communications

### Performance Optimization Guidelines
- **Memory Management**: Improved garbage collection for AI workloads
- **Battery Optimization**: AI-specific power management features
- **Thermal Management**: Intelligent throttling for intensive AI operations
- **Background Processing**: Enhanced background task management for AI inference

### AI Development Best Practices

#### Core Considerations
1. **Model Selection**: Choose appropriate model sizes based on device capabilities
2. **Latency Management**: Implement progressive loading and caching strategies
3. **Resource Optimization**: Monitor CPU, memory, and battery usage
4. **Error Handling**: Graceful fallbacks for AI service failures
5. **User Experience**: Provide feedback during AI processing

#### Code Quality Standards
- **Type Safety**: Strict TypeScript configuration for AI service modules
- **Async Programming**: Proper async/await patterns for AI API calls
- **Error Boundaries**: Comprehensive error handling with user-friendly messages
- **Performance Monitoring**: Built-in metrics collection for AI operations
- **Testing Strategy**: Unit tests for AI logic, integration tests for API calls

#### Security & Privacy
- **API Key Management**: Never expose API keys in client-side code
- **Data Validation**: Strict input validation before AI processing
- **Output Sanitization**: Validate and sanitize AI-generated content
- **User Consent**: Clear consent mechanisms for data processing
- **Audit Logging**: Comprehensive logging for AI operations

#### Platform-Specific Guidelines
- **ArkTS Optimization**: Leverage ArkTS-specific features for better performance
- **Component Lifecycle**: Proper management of AI component lifecycle
- **State Management**: Efficient state handling for AI operation status
- **Resource Cleanup**: Proper cleanup of AI resources and connections

### Common Pitfalls to Avoid
1. **Blocking UI Thread**: Never perform AI operations on main thread
2. **Memory Leaks**: Proper cleanup of AI models and resources
3. **Network Timeouts**: Implement appropriate timeout handling
4. **Error Suppression**: Never silently ignore AI service errors
5. **Over-fetching**: Minimize unnecessary AI API calls

### Recommended Development Workflow
1. **Prototype First**: Start with simple AI integration
2. **Iterative Testing**: Test AI features on actual devices
3. **Performance Profiling**: Use DevEco Studio profiling tools
4. **User Testing**: Gather feedback on AI feature usability
5. **Continuous Monitoring**: Monitor AI performance in production

### Debugging & Monitoring Tools
- **DevEco Studio Profiler**: CPU, memory, and network profiling
- **HiAI Debugger**: AI model debugging and optimization
- **Log Analysis**: Comprehensive logging for AI operations
- **Performance Metrics**: Built-in performance monitoring
- **Crash Analytics**: AI-specific crash reporting and analysis

###After completing the modification project, there is no need to create related files. I will modify them when I need you to. Also, save them with git when making modifications.
### Compiler location
- **export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
- **/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap
### After each project modification, compile it to confirm whether it can run.
- 每次修改之后见修改的内容合并到main分支上，并询问我是否传输到远程仓库