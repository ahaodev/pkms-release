# PKMS Release Tool 使用说明

PKMS Release 是一个用于自动化发布流程的 Docker 工具，可以生成变更日志并上传发布文件到发布系统。

## 快速开始

### 1. 构建 Docker 镜像

```bash
docker build -t pkms-release:latest .
```

### 2. 基本使用

```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token -e RELEASE_URL=your-url \
  pkms-release:latest /workspace/app.apk v1.0.0
```

## 详细说明

### 命令格式

```bash
./scripts/pkms-release.sh <file_path> <version> [artifact_name] [os] [arch]
```

**必需参数:**
- `file_path`: 要发布的文件路径
- `version`: 版本号 (如: v1.0.0)

**可选参数:**
- `artifact_name`: 文件名称 (默认: 文件名)
- `os`: 目标系统 (默认: android)
- `arch`: 目标架构 (默认: universal)

### 环境变量

**必需变量:**
- `ACCESS_TOKEN`: 发布系统访问令牌
- `RELEASE_URL`: 发布系统 API 地址

**Drone CI 变量 (可选):**
- `DRONE_TAG`: 当前标签
- `DRONE_COMMIT`: 当前提交哈希
- `DRONE_BRANCH`: 当前分支

**GitHub Actions 变量 (可选，自动注入):**
- `GITHUB_REF`: GitHub Actions 的完整 ref（如 `refs/tags/v1.0.0`）
- `GITHUB_REF_NAME`: 标签或分支名称（如 `v1.0.0`）
- `GITHUB_SHA`: 提交 SHA

## 使用示例

### Docker 方式

#### 基本发布
```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=PKMS-9xuKyfbBvAJAwv42 \
  -e RELEASE_URL=https://your-release-system.com/client-access/release \
  pkms-release:latest ./app.apk v1.2.0
```

#### 指定详细信息
```bash
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token -e RELEASE_URL=your-url \
  pkms-release:latest ./build/MyApp.apk v2.1.0 "MyApplication" "android" "arm64"
```

#### 在 Drone CI 中使用
```yaml
steps:
  - name: release
    image: pkms-release:latest
    environment:
      ACCESS_TOKEN:
        from_secret: release_token
      RELEASE_URL:
        from_secret: release_url
    commands:
      - /workspace/build/app.apk ${DRONE_TAG}
```

#### 在 GitHub Actions 中使用

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
          artifact_name: 'MyApp'
          os: 'android'
          arch: 'universal'
          access_token: ${{ secrets.ACCESS_TOKEN }}
          release_url: ${{ secrets.RELEASE_URL }}
```

使用 Docker 容器方式：

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

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
        run: pkms-release ./app.apk ${{ github.ref_name }} MyApp android universal
```

> **提示：** 在 GitHub Actions 中需要在仓库的 **Settings → Secrets and variables → Actions** 中添加 `ACCESS_TOKEN` 和 `RELEASE_URL` 两个 Secret。

### 直接脚本方式

```bash
# 设置权限
chmod +x scripts/pkms-release.sh

# 设置环境变量
export ACCESS_TOKEN="your-token"
export RELEASE_URL="https://your-release-system.com/client-access/release"

# 运行脚本
./scripts/pkms-release.sh ./app.apk v1.0.0
```

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

- 支持多部分表单上传
- 包含完整的元数据信息
- 内置重试机制和错误处理
- 适配 Docker 环境

## 故障排除

### 常见问题

**1. 文件路径错误**
```
Error: File 'xxx' not found
```
确保文件路径正确且文件存在。

**2. 网络连接失败**
```
Upload failed - Network/Connection error
```
检查网络连接和 RELEASE_URL 是否正确。

**3. 权限错误**
```
HTTP 401/403 错误
```
检查 ACCESS_TOKEN 是否正确配置。

**4. Git 仓库问题**
```
Warning: Not in a git repository
```
脚本会使用默认变更日志，不影响上传功能。

### 调试模式

如需详细调试信息，可以修改脚本开头添加：
```bash
set -x  # 显示执行过程
```

## 配置文件

可在项目根目录创建 `.env` 文件：
```bash
ACCESS_TOKEN=your-default-token
RELEASE_URL=https://your-release-system.com/client-access/release
```

然后使用：
```bash
source .env && ./scripts/pkms-release.sh ./app.apk v1.0.0
```

## 支持和反馈

如遇问题，请检查：
1. Docker 镜像是否正确构建
2. 环境变量是否正确设置  
3. 文件路径和权限是否正确
4. 网络连接是否正常

更多技术细节请参考 `CLAUDE.md` 文件。