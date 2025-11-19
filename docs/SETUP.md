# HarmonyOS 开发环境配置指南

## 快速开始

### 1. 环境准备

确保已安装以下工具：
- **DevEco Studio 5.0+** - [官方下载地址](https://developer.harmonyos.com/cn/develop/deveco-studio)
- **HarmonyOS SDK 12.0+** - 通过 DevEco Studio SDK Manager 安装

### 2. 本地配置

项目根目录下的 `local.properties` 文件不会被Git跟踪，需要手动创建：

#### macOS 用户
```properties
devecosdk.home=/Applications/DevEco-Studio.app/Contents/sdk
devecosdk.apiLevel=12
devecosdk.buildTools=12.0.0.10
devecosdk.ndk=12.1.0.5622933
```

#### Windows 用户
```properties
devecosdk.home=C:\\Users\\{YourUsername}\\AppData\\Local\\Huawei\\Sdk
devecosdk.apiLevel=12
devecosdk.buildTools=12.0.0.10
devecosdk.ndk=12.1.0.5622933
```

#### Linux 用户
```properties
devecosdk.home=/home/{YourUsername}/Huawei/Sdk
devecosdk.apiLevel=12
devecosdk.buildTools=12.0.0.10
devecosdk.ndk=12.1.0.5622933
```

### 3. 验证配置

运行以下命令验证配置：
```bash
cd /path/to/AI_Assistant
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap
```

### 4. 常见问题解决

#### 问题1：SDK路径错误
```
ERROR: Invalid value of 'DEVECO_SDK_HOME'
```

**解决方案：**
1. 检查 DevEco Studio 中配置的 SDK 路径
2. 更新 `local.properties` 中的 `devecosdk.home` 路径
3. 重新启动 DevEco Studio

#### 问题2：权限问题
```
Permission denied accessing SDK files
```

**解决方案：**
```bash
# macOS/Linux
chmod -R 755 /path/to/sdk

# Windows (以管理员身份运行 DevEco Studio)
```

#### 问题3：API Level 不匹配
```
API Level 12 is not available
```

**解决方案：**
1. 打开 DevEco Studio
2. 进入 `Tools > SDK Manager`
3. 安装 HarmonyOS SDK 12.0
4. 更新 `devecosdk.apiLevel=12`

## 项目结构说明

```
AI_Assistant/
├── entry/src/main/ets/          # 主要源代码
│   ├── pages/                   # 页面组件
│   ├── utils/                   # 工具类
│   └── resources/               # 资源文件
├── supabase/                    # 后端服务
├── docs/                        # 项目文档
├── local.properties             # 本地配置（不要提交）
└── .gitignore                   # Git忽略规则
```

## 开发工作流

### 1. 日常开发
```bash
# 编译应用
hvigorw assembleHap

# 运行测试
hvigorw test

# 清理构建缓存
hvigorw clean
```

### 2. 代码规范
- 使用 TypeScript 严格模式
- 遵循 HarmonyOS ArkTS 编码规范
- 所有新功能必须包含单元测试

### 3. 提交前检查
- [ ] 代码编译通过
- [ ] 单元测试通过
- [ ] 代码格式化完成
- [ ] 文档更新完成

## 团队协作

### 1. 分支策略
- `main`: 主分支，保持稳定
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 紧急修复分支

### 2. 提交规范
```
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 代码重构
test: 测试相关
chore: 构建过程或辅助工具的变动
```

## CI/CD 配置

项目支持以下 CI/CD 平台：
- **GitHub Actions** (推荐)
- **Gitee Go**
- **Jenkins** (企业版)

详细配置请参考 `.github/workflows/` 目录下的配置文件。