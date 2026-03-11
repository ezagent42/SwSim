---
name: OneSystem Integration
description: OneSystem 平台职能、架构、API 参考。其他项目对接 OneSystem 时使用。
---

# OneSystem Integration Skill

## 平台职能

OneSystem 是 **混合基础设施统一管理平台**，核心职责：

| 职能 | 说明 |
|------|------|
| **资源声明式管理** | 以 K8s 风格 YAML 声明物理机、虚拟机、容器、密钥等资源 |
| **多租户隔离** | Namespace + RBAC（viewer/editor/admin）实现资源隔离 |
| **密钥管理** | SOPS 加密存储，owner-only 解密策略 |
| **SSH 远程访问** | 密码/Teleport 证书双模式，SSHFS 反向隧道 |
| **EventBus 扩展** | 资源生命周期事件驱动外部系统同步（Teleport、Incus）|
| **统一 CLI** | `one` CLI 工具覆盖所有操作 |

---

## 资源模型（KRM 风格）

所有资源遵循 Kubernetes Resource Model，统一结构：

```yaml
apiVersion: v1
kind: <PascalCase Kind>    # 必须为注册表中的合法 Kind
metadata:
  name: <string>           # 资源名，同 kind+namespace 下唯一
  namespace: <string>      # 所属 namespace（默认 user-<username>）
  owner: <string>          # 自动设为创建者
  labels:                  # 可选标签
    env: prod
    role: worker
spec: { ... }              # 资源规格（因 Kind 而异）
status: { ... }            # 运行时状态（可选）
data: { ... }              # 仅 Secret 使用，SOPS 加密
```

### 资源唯一键

`kind + metadata.name + metadata.namespace` 三元组全局唯一。

### 注册的资源类型

| Kind (body) | Resource (URL) | CLI 别名 | 用途 |
|-------------|---------------|----------|------|
| `Secret` | `secrets` | `secret`, `sec` | SSH 密码、凭证，SOPS 加密存储 |
| `VM` | `vms` | `vm` | 虚拟机 |
| `Container` | `containers` | `container` | Docker 容器 |
| `Machine` | `machines` | `machine`, `mach` | 通用节点 |
| `BareMetalServer` | `baremetalservers` | `bms` | 物理服务器 |
| `Config` | `configs` | `config`, `cfg` | 配置项 |
| `IncusInstance` | `incusinstances` | `incusinstance` | Incus LXC/VM |
| `ECS` | `ecs` | — | 云主机（阿里云 ECS 等）|
| `User` | `users` | `user` | 用户 |

> **规则**: YAML body 中 `kind` 必须为 PascalCase（如 `Secret`），API URL 使用小写复数形式（如 `/secrets`）。

---

## API 参考

**Base URL**: `https://api.h2os.cloud/api/v1` (或自定义 `SERVER_HOST:SERVER_PORT`)

### 认证

所有 API（除 auth 和 health）需 Bearer Token：

```
Authorization: Bearer <access_token>
```

Token 通过 OneAuth OAuth2 流程获取。

---

### Auth 接口（公开）

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/v1/auth/login-native` | 原生登录（仅内部/开发） |
| `POST` | `/api/v1/auth/refresh` | 刷新 Token |
| `POST` | `/api/v1/auth/logout` | 登出 |
| `GET` | `/api/v1/auth/me` | 获取当前用户信息（需认证） |

---

### Resource CRUD 接口（需认证）

所有资源类型共享统一的 REST 接口，URL 中 `{resource}` 为小写资源名（如 `secrets`、`machines`）。

| Method | Path | 说明 | 请求体 |
|--------|------|------|--------|
| `POST` | `/api/v1/{resource}` | 创建资源 | 完整资源 YAML/JSON |
| `GET` | `/api/v1/{resource}` | 列出资源 | Query: `?page=&size=&fields=` |
| `GET` | `/api/v1/{resource}/{name}` | 获取单个资源 | Query: `?fields=metadata,spec` |
| `PUT` | `/api/v1/{resource}/{name}` | 更新资源 | 完整资源 YAML/JSON |
| `DELETE` | `/api/v1/{resource}/{name}` | 删除资源 | — |
| `POST` | `/api/v1/{resource}/{name}/move` | 跨 Namespace 转移 | `{"to_namespace":"x","from_namespace":"y"}` |
| `POST` | `/api/v1/resources/search` | OneQL 搜索 | `{"kind":"*","query":"label.env:prod"}` |

#### 创建资源示例

```bash
curl -X POST https://api.h2os.cloud/api/v1/secrets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "db-password", "namespace": "team-ops"},
    "data": {"password": "mySecretPass"}
  }'
```

#### 获取资源示例

```bash
# 获取单个
curl https://api.h2os.cloud/api/v1/secrets/db-password \
  -H "Authorization: Bearer $TOKEN"

# 列表（带分页）
curl "https://api.h2os.cloud/api/v1/machines?page=1&size=20" \
  -H "Authorization: Bearer $TOKEN"

# 字段过滤
curl "https://api.h2os.cloud/api/v1/secrets/db-password?fields=metadata,spec" \
  -H "Authorization: Bearer $TOKEN"
```

#### OneQL 搜索语法

```bash
curl -X POST https://api.h2os.cloud/api/v1/resources/search \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "kind": "BareMetalServer",
    "query": "namespace:team-ops label.env:prod spec.cpu>=4"
  }'
```

OneQL 支持的操作符：`:` (等于), `!=`, `>`, `>=`, `<`, `<=`, `~` (包含)
支持的字段：`namespace`, `owner`, `name`, `label.<key>`, `spec.<key>`（spec 支持任意深度嵌套，如 `spec.pricing.unit_price`）

**排序**：在 query 中加 `--sort field:asc,field2:desc`

```bash
# 排序示例
curl -X POST https://api.h2os.cloud/api/v1/resources/search \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "kind": "BareMetalServer",
    "query": "namespace:team-ops --sort spec.pricing.unit_price:asc"
  }'
```

---

### Secret 工具接口（需认证）

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/v1/secrets/encrypt` | SOPS 加密 |
| `POST` | `/api/v1/secrets/decrypt` | SOPS 解密 |
| `POST` | `/api/v1/secrets/generate-password` | 生成随机密码 |
| `POST` | `/api/v1/secrets/generate-keypair` | 生成 SSH 密钥对 |

> **安全规则**: Secret 资源的 `data` 字段中 `__sops__` 元数据仅对 owner 可见。非 owner 获取 Secret 时 `__sops__` 字段会被过滤。

---

### SSH 证书接口（需认证，Teleport）

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/v1/ssh/cert` | 请求 SSH 证书（Teleport Certificate Bridge） |
| `GET` | `/api/v1/ssh/health` | 证书服务健康检查 |

#### 请求 SSH 证书

```bash
curl -X POST https://api.h2os.cloud/api/v1/ssh/cert \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"node": "my-server", "logins": ["root","ubuntu"], "ttl": "8h"}'
```

返回：`{ "cert": "<base64>", "private_key": "<base64>", "username": "alice", "expires_at": "..." }`

---

### Namespace 接口（需认证）

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/v1/namespaces` | 创建 Namespace |
| `GET` | `/api/v1/namespaces` | 列出可见 Namespace |
| `GET` | `/api/v1/namespaces/{name}` | 获取 Namespace 详情 |
| `POST` | `/api/v1/namespaces/{name}/members` | 添加成员 |
| `DELETE` | `/api/v1/namespaces/{name}/members/{userId}` | 移除成员 |
| `DELETE` | `/api/v1/namespaces/{name}` | 删除 Namespace（仅 owner） |

#### 创建 Namespace

```bash
curl -X POST https://api.h2os.cloud/api/v1/namespaces \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "team-ops"}'
```

#### 添加成员

```bash
curl -X POST https://api.h2os.cloud/api/v1/namespaces/team-ops/members \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"user_id": "bob", "role": "editor"}'
# role: viewer | editor | admin
```

---

### 内部 API

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/internal/policy/evaluate` | OPA 策略评估（内部网络） |

### 健康检查（公开）

```bash
curl https://api.h2os.cloud/health
# {"status":"healthy","version":"v1.0.0"}
```

---

## Namespace RBAC 模型

| 角色 | 读资源 | 写资源 | 删除资源 | 管理成员 | 删除 NS |
|------|--------|--------|----------|----------|---------|
| `viewer` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `editor` | ✅ | ✅ | ❌ | ❌ | ❌ |
| `admin` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `owner` | ✅ | ✅ | ✅ | ✅ | ✅ |

- 每个用户默认有一个个人 Namespace：`user-<username>`
- 资源创建时自动归入个人 Namespace（除非指定 `-n` 或 YAML 内嵌）

---

## EventBus 事件

外部系统可通过 EventBus 订阅资源生命周期事件：

| 事件 | 触发时机 | Payload |
|------|----------|---------|
| `resource.created` | 资源创建后 | `*models.Resource` |
| `resource.updated` | 资源更新后 | `*models.Resource` |
| `resource.deleted` | 资源删除后 | `*models.Resource` |
| `allocation.released` | Allocation 释放（含自动过期） | `*models.Resource` |
| `namespace.member_added` | 成员加入 NS | `{namespace, user_id, role}` |
| `namespace.member_removed` | 成员移除 NS | `{namespace, user_id}` |

### 已注册的适配器

| 适配器 | 订阅事件 | 动作 |
|--------|----------|------|
| `TeleportAdapter` | `namespace.member_added/removed` | 同步 Teleport Role |
| `IncusAdapter` | `resource.created/updated/deleted` | 同步 Incus Project |

---

## 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `SERVER_PORT` | 否 | 监听端口（默认 8080） |
| `SERVER_HOST` | 否 | 监听地址（默认 0.0.0.0） |
| `DB_HOST` | 是 | PostgreSQL 主机 |
| `DB_PORT` | 是 | PostgreSQL 端口 |
| `DB_USER` | 是 | 数据库用户 |
| `DB_PASSWORD` | 是 | 数据库密码 |
| `DB_NAME` | 是 | 数据库名 |
| `ONEAUTH_BASE_URL` | 是 | OneAuth 认证服务地址 |
| `ONEAUTH_CLIENT_ID` | 是 | OAuth2 客户端 ID |
| `ONEAUTH_CLIENT_SECRET` | 是 | OAuth2 客户端密钥 |
| `SOPS_AGE_KEY` / `SOPS_AGE_KEY_FILE` | 否 | SOPS Age 加密密钥 |
| `TELEPORT_AUTH_SERVER` | 否 | Teleport 认证服务器（启用 Cert Bridge） |
| `TELEPORT_BOT_IDENTITY_FILE` | 否 | Teleport Bot 身份文件 |
| `TELEPORT_PROXY_ADDR` | 否 | Teleport 代理地址（启用 TeleportAdapter） |

---

## CLI 命令速查

```bash
# 认证
one login                           # OAuth2 登录
one whoami                          # 查看当前身份

# 资源管理（type 支持小写别名：secret, bms, vm, container, machine, cfg...）
one apply -f <file>                 # 创建/更新资源
one get <type> [name]               # 查看资源
one delete <type> <name>            # 删除资源
one edit <type> <name>              # 编辑资源
one patch <type> <name> --set k=v   # 更新字段
one label <type> <name> k=v         # 更新标签
one move <type> <name> --to <ns>    # 跨 Namespace 转移

# Namespace
one ns create <name>                # 创建
one ns list                         # 列出
one ns get <name>                   # 详情
one ns add-member <ns> <user> --role editor  # 添加成员
one ns remove-member <ns> <user>    # 移除成员
one ns use <name>                   # 切换活跃 NS
one ns delete <name>                # 删除（仅 owner）

# SSH
one ssh <name>                      # 密码 SSH（自动检测类型）
one ssh <type> <name>               # 指定类型 SSH
one ssh <name> --teleport           # Teleport 证书 SSH
one ssh <name> --expose-fs          # SSH + 反向 SSHFS
```

---

## 技术栈

| 层 | 技术 |
|----|------|
| 语言 | Go 1.22+ |
| Web 框架 | Gin |
| 数据库 | PostgreSQL + GORM |
| 认证 | OneAuth (ORY Hydra + Kratos) → OAuth2/OIDC |
| 密钥管理 | SOPS (Age/AWS KMS/GCP KMS) |
| SSH | crypto/ssh + Teleport Certificate Bridge |
| 事件总线 | 内存 EventBus（可扩展至 NATS/Redis） |
| 容器编排 | Docker API |
| VM/LXC | Incus REST API |

---

## 集成指南

### 方式一：HTTP API 对接

1. 通过 OneAuth 获取 Access Token
2. 使用 Bearer Token 调用上述 REST API
3. 资源数据格式遵循 KRM YAML/JSON 规范

### 方式二：EventBus 适配器

1. 实现 `eventbus.Handler` 接口
2. 在 API Server 启动时注册适配器
3. 订阅关注的事件（如 `resource.created`）

```go
// 示例：自定义适配器
bus.Subscribe("resource.created", func(ctx context.Context, event interface{}) error {
    resource := event.(*models.Resource)
    if resource.Kind == "Container" {
        // 同步到外部系统
    }
    return nil
})
```

### 方式三：CLI 脚本集成

```bash
# 在 CI/CD 中使用
one apply -f deployment-resources/*.yaml -n production
one get secret db-creds -o json | jq '.data.password'
```
