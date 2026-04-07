# PMS Releaser Tool

PMS Releaser 是一款面向 CI/CD 流水线的自动化发布工具，能够从 Git 提交记录自动生成变更日志，并将构建产物上传到指定发布系统。支持脚本、GitHub Actions、Drone CI 和 Docker 四种使用方式。

---

## 功能特性

### 自动变更日志生成

基于 [约定式提交（Conventional Commits）](https://www.conventionalcommits.org/) 规范，自动分析 Git 提交历史并分类输出：

| 提交前缀 | 分类 |
|---|---|
| `feat` / `feature` | ✨ 新功能 |
| `fix` / `bugfix` | 🐛 错误修复 |
| `docs` / `doc` | 📚 文档更新 |
| `style` / `format` | 💄 样式调整 |
| `refactor` | ♻️ 代码重构 |
| `perf` / `performance` | ⚡ 性能优化 |
| `test` | 🧪 测试相关 |
| `build` / `ci` / `cd` | 🔧 构建系统 & CI/CD |
| `chore` | 🔨 维护工作 |
| 其他 | 📝 其他变更 |

> 💡 Checkout 时请使用 `fetch-depth: 0` 以获取完整的提交历史，确保 changelog 准确完整。

### 发布上传

- 多部分表单（multipart）上传，携带完整元数据
- 自动重试（最多 3 次，间隔 5 秒）
- 服务端响应校验：自动检测 HTML 误返（防止 SPA 路由干扰）
- 原生支持 GitHub Actions 与 Drone CI 环境变量

---

## 快速上手

以下是最常见的 GitHub Actions 使用方式，推送 tag 时自动触发发布：

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
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: ahaodev/pms-releaser@main
        with:
          file_path: './app.apk'
          version: ${{ github.ref_name }}
          project_name: ${{ vars.PROJECT_NAME }}
          package_name: ${{ vars.PACKAGE_NAME }}
          access_token: ${{ secrets.ACCESS_TOKEN }}
          release_url: ${{ secrets.RELEASE_URL }}
```

> 在仓库的 **Settings → Secrets and variables → Actions** 中配置：
> - **Secrets**：`ACCESS_TOKEN`、`RELEASE_URL`
> - **Variables**：`PROJECT_NAME`、`PACKAGE_NAME`

---

## 命令参数

```bash
pms-releaser <file_path> <version> <project_name> <package_name> [artifact_name] [os] [arch]
```

### 必需参数

| 参数 | 说明 |
|---|---|
| `file_path` | 待发布文件路径 |
| `version` | 版本号，如 `v1.0.0` |
| `project_name` | 发布系统中的项目名称 |
| `package_name` | 项目下的包名称 |

### 可选参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `artifact_name` | 文件名 | 在发布系统中显示的制品名称 |
| `os` | `android` | 目标操作系统/平台 |
| `arch` | `universal` | 目标架构 |

### 环境变量

| 变量 | 必需 | 说明 |
|---|---|---|
| `ACCESS_TOKEN` | ✅ | 发布系统访问令牌 |
| `RELEASE_URL` | ✅ | 发布系统 API 地址 |
| `DRONE_TAG` | — | Drone CI 当前 tag |
| `DRONE_COMMIT` | — | Drone CI 当前 commit hash |
| `DRONE_BRANCH` | — | Drone CI 当前分支 |
| `GITHUB_REF` | — | GitHub Actions ref |
| `GITHUB_REF_NAME` | — | GitHub Actions tag 或分支名 |
| `GITHUB_SHA` | — | GitHub Actions commit SHA |

---

## 使用方式

### 1. 直接运行脚本

```bash
chmod +x scripts/pms-releaser.sh

export ACCESS_TOKEN="your-token"
export RELEASE_URL="https://your-release-system.com/access/release"

./scripts/pms-releaser.sh ./app.apk v1.0.0 my-project my-package
```

使用 `.env` 文件管理本地配置（推荐）：

```bash
# .env（请确保已加入 .gitignore，避免 token 泄漏）
export RELEASE_URL=https://your-release-system.com/access/release
export ACCESS_TOKEN=your-token
export PROJECT_NAME=my-project
export PACKAGE_NAME=my-package
```

```bash
source .env && ./scripts/pms-releaser.sh ./app.apk v1.0.0 $PROJECT_NAME $PACKAGE_NAME
```

### 2. GitHub Actions

**方式一：使用内置 Action（推荐）**

```yaml
- uses: ahaodev/pms-releaser@main  # 生产环境建议固定到具体 tag，如 @v1.0.0
  with:
    file_path: './app.apk'
    version: ${{ github.ref_name }}
    project_name: ${{ vars.PROJECT_NAME }}
    package_name: ${{ vars.PACKAGE_NAME }}
    artifact_name: 'MyApp'
    os: 'android'
    arch: 'universal'
    access_token: ${{ secrets.ACCESS_TOKEN }}
    release_url: ${{ secrets.RELEASE_URL }}
```

**方式二：使用 Docker 容器**

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    container:
      image: hao88/pms-releaser:latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Publish release
        env:
          ACCESS_TOKEN: ${{ secrets.ACCESS_TOKEN }}
          RELEASE_URL: ${{ secrets.RELEASE_URL }}
        run: |
          pms-releaser ./app.apk ${{ github.ref_name }} \
            ${{ vars.PROJECT_NAME }} ${{ vars.PACKAGE_NAME }} \
            MyApp android universal
```

> 在仓库的 **Settings → Secrets and variables → Actions** 中配置：
> - **Secrets**：`ACCESS_TOKEN`、`RELEASE_URL`
> - **Variables**：`PROJECT_NAME`、`PACKAGE_NAME`

### 3. Drone CI

```yaml
kind: pipeline
type: docker
name: release

trigger:
  event:
    - tag

steps:
  - name: release
    image: hao88/pms-releaser:latest
    environment:
      ACCESS_TOKEN:
        from_secret: ACCESS_TOKEN
      RELEASE_URL:
        from_secret: RELEASE_URL
    commands:
      - pms-releaser /drone/src/app.apk ${DRONE_TAG} my-project my-package
```

### 4. Docker

```bash
# 基本发布
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token \
  -e RELEASE_URL=https://your-release-system.com/access/release \
  hao88/pms-releaser:latest \
  /workspace/app.apk v1.0.0 my-project my-package

# 指定 artifact 名称、平台和架构
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=your-token \
  -e RELEASE_URL=https://your-release-system.com/access/release \
  hao88/pms-releaser:latest \
  ./build/MyApp.apk v2.1.0 my-project my-package "MyApplication" "android" "arm64"
```

