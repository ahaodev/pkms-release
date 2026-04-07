# PKMS Release Tool 使用说明

PKMS Release 是一个用于自动化发布流程的工具，可以生成变更日志并上传发布文件到发布系统。

## 功能特性

### 自动变更日志生成

脚本会自动分析 Git 提交记录，按照约定式提交格式生成分类变更日志：

- `feat*` → ✨ 新功能
- `fix*` → 🐛 错误修复
- `docs*` → 📚 文档更新
- `style*` → 💄 样式调整
- `refactor*` → ♻️ 代码重构
- `perf*` → ⚡ 性能优化
- `test*` → 🧪 测试相关
- `build*|ci*|cd*` → 🔧 构建系统和 CI/CD
- `chore*` → 🔨 维护工作
- 其他 → 📝 其他变更

### 发布上传

- 支持多部分表单上传，包含完整元数据
- 内置重试机制（3 次）和错误处理
- 自动检测服务器返回 HTML（防止 SPA 误判）
- 同时支持 Drone CI 和 GitHub Actions 环境变量

## 命令格式

```bash
pkms-release <file_path> <version> <project_name> <package_name> [artifact_name] [os] [arch]
```

**必需参数:**
- `file_path`: 要发布的文件路径
- `version`: 版本号 (如: v1.0.0)
- `project_name`: 发布系统中的项目名称
- `package_name`: 项目下的包名称

**可选参数:**
- `artifact_name`: 文件名称 (默认: 文件名)
- `os`: 目标系统 (默认: android)
- `arch`: 目标架构 (默认: universal)

**环境变量:**
- `ACCESS_TOKEN`: 发布系统访问令牌 *(必需)*
- `RELEASE_URL`: 发布系统 API 地址 *(必需)*

## 直接脚本方式

```bash
chmod +x scripts/pkms-release.sh

export ACCESS_TOKEN="your-token"
export RELEASE_URL="https://your-release-system.com/access/release"

./scripts/pkms-release.sh ./app.apk v1.0.0 my-project my-package
```

使用 `.env` 文件管理本地配置（推荐）：

```bash
# .env
export RELEASE_URL=https://your-release-system.com/access/release
export ACCESS_TOKEN=your-token
export PROJECT_NAME=my-project
export PACKAGE_NAME=my-package
```

```bash
source .env && ./scripts/pkms-release.sh ./app.apk v1.0.0 $PROJECT_NAME $PACKAGE_NAME
```

> ⚠️ 确保 `.env` 已加入 `.gitignore`，避免 token 泄漏。

## GitHub Actions

使用内置的 Action（推荐）：

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Publish release
        uses: ahaodev/pkms-release@main  # pin to a specific tag in production, e.g. @v1.0.0
        with:
          file_path: './app.apk'
          version: ${{ github.ref_name }}
          project_name: ${{ vars.PROJECT_NAME }}   # set in repo/org variables
          package_name: ${{ vars.PACKAGE_NAME }}   # set in repo/org variables
          artifact_name: 'MyApp'
          os: 'android'
          arch: 'universal'
          access_token: ${{ secrets.ACCESS_TOKEN }}
          release_url: ${{ secrets.RELEASE_URL }}
```

使用 Docker 容器方式：

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    container:
      image: hao88/pkms-release:latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Publish release
        env:
          ACCESS_TOKEN: ${{ secrets.ACCESS_TOKEN }}
          RELEASE_URL: ${{ secrets.RELEASE_URL }}
        run: pkms-release ./app.apk ${{ github.ref_name }} ${{ vars.PROJECT_NAME }} ${{ vars.PACKAGE_NAME }} MyApp android universal
```

> **提示：** 在仓库的 **Settings → Secrets and variables → Actions** 中添加 `ACCESS_TOKEN`、`RELEASE_URL` Secret 以及 `PROJECT_NAME`、`PACKAGE_NAME` Variable。

## Drone CI

```yaml
kind: pipeline
type: docker
name: release

trigger:
  event:
    - tag

steps:
  - name: release
    image: hao88/pkms-release:latest
    environment:
      ACCESS_TOKEN:
        from_secret: ACCESS_TOKEN
      RELEASE_URL:
        from_secret: RELEASE_URL
    commands:
      - pkms-release /drone/src/app.apk ${DRONE_TAG} my-project my-package
```

## Docker

```bash
# 构建镜像
docker build -t pkms-release:latest .

# 基本发布
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token -e RELEASE_URL=your-url \
  pkms-release:latest /workspace/app.apk v1.0.0 my-project my-package

# 指定详细信息
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token -e RELEASE_URL=your-url \
  pkms-release:latest ./build/MyApp.apk v2.1.0 my-project my-package "MyApplication" "android" "arm64"
```

## 故障排除

**文件路径错误**
```
Error: File 'xxx' not found
```
确保文件路径正确且文件存在。

**网络连接失败**
```
Upload failed - Network/Connection error
```
检查网络连接和 RELEASE_URL 是否正确。

**权限错误 (401/403)**

检查 ACCESS_TOKEN 是否正确，以及对应 project/package 是否有写入权限。

**服务器返回 HTML**
```
Upload failed - server returned HTML instead of JSON
```
RELEASE_URL 指向了前端页面，请确认 API 路径正确（如 `/access/release`）。

**不在 Git 仓库中**
```
Warning: Not in a git repository
```
脚本会使用默认变更日志，不影响上传功能。需要完整 changelog 时，checkout 时请使用 `fetch-depth: 0`。

**调试模式**
```bash
set -x  # 在脚本开头添加，显示执行过程
```

