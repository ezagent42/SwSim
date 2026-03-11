---
name: socialware-app-install
description: "Install a developed Socialware App from app-store into a Room — assign roles to members, choose namespace, and activate the App."
---

# Socialware App Install — 安装 App 到 Room

## 启动前置

1. 如果存在 `simulation/workspace/.active-session.json`，删除它（退出 runtime 模式）。
2. **身份确认**: 扫描 `simulation/workspace/identities/*.json`，列出可用身份。
   - 如果无身份 → 提示用户先用 `/room create` 创建身份。
   - 如果有身份 → 让用户选择以哪个身份操作（即 App 的 `安装者`）。
   - **该身份必须是目标 Room 的成员**（Phase 1 选择 Room 后验证）。

## 你在做什么

**你在把一个已开发的 Socialware App 安装到 Room 中——绑定具体用户并激活**。

App 已经在 app-store 中（`.app.md`，§5 工具已填），但 §1 持有者还是 `_待绑定_`，也没有 namespace。你需要：
- 选择目标 Room
- 为 App 选择 namespace
- 把每个角色绑定到 Room 的具体成员
- 把 App 实例复制到 Room 并更新配置

## 制品关系

```
输入                                      输出
─────                                    ─────
simulation/app-store/                    simulation/workspace/rooms/{room}/
  {app-id}.app.md                           ├── socialware-app/{app-id}.app.md  ← 已安装实例
  状态: 已开发                                ├── config.json  ← 更新
  §1 = _待绑定_                              ├── state.json   ← 更新
  §5 = 已填工具                              └── ...
  namespace = 未定
```

- **app-store 原件不变**: 安装是复制，不是移动
- **同一 App 可安装到多个 Room**: 每个 Room 独立实例，各自独立的 namespace 和用户绑定

## 流程

### Phase 1: 选择 App 和 Room

1. 读取 `simulation/app-store/registry.json`，列出已注册的 App，展示摘要（app_id, socialware, developer, description）
2. 让用户选择要安装的 App（通过 app_id）
3. 根据选中的 registry 条目，定位 App 文件: `simulation/app-store/{registry.apps[app_id].app_file}`
4. 列出可用 Room（`simulation/workspace/rooms/`），让用户选择目标 Room
5. 让用户选择 namespace（2-4 字母简称，如 `dc`, `ta`, `ew`）
6. 检查 namespace 在该 Room 中是否已被占用

### Phase 2: 绑定角色（§1 持有者）

7. 列出 Room 的现有成员（从 config.json 读取）
8. 展示 App 的角色表（从 app-store 中的 App 读取）
9. 逐个角色问持有者（必须是 Room 成员，或新加入）
10. 如需新成员:
   - 创建 `simulation/workspace/identities/{username}@{namespace}.json`
   - 在 `simulation/workspace/rooms/{room}/identities/` 创建引用
   - 更新 config.json 的 `membership.members`
   - 初始化 state.json 的 `peer_cursors`

### Phase 3: 跨契约 Mock

11. 检查 App 中声明的跨契约引用（依赖/委托/资源）
12. 同 Room 已安装 → 验证引用原子
13. 不存在 → 询问最小信息 → 生成 mock 数据到 state.json

### Phase 4: 写入

14. 复制 app-store 中的 App 到 `workspace/rooms/{room}/socialware-app/{app-id}.app.md`
15. 在安装副本上修改:
    - 头部状态 → `已安装`
    - 添加 `安装者: {当前身份}`、`Namespace: {ns}`、`Room: {room}`
    - §1 填入持有者（具体 identity）
    - 添加 §6 模拟环境
16. 更新 config.json:
    - `socialware-app.installed` 添加:
      ```json
      {
        "app_id": "{app-id}",
        "namespace": "{ns}",
        "contract": "{app-id}.app.md",
        "template": "{template_name}.socialware.md"
      }
      ```
      其中 `app-id` 使用 `{AppName}.{DeveloperName}.{SocialwareName}` 格式
    - `socialware-app.roles` 添加: `"{ns}:{R-ID}": "{username}:{nickname}@{namespace}"` 对每个角色
17. 更新 state.json:
    - `role_map` 添加: `"{ns}:{R-ID}": "{username}:{nickname}@{namespace}"`
    - `commitments` 添加每个声明的 Commitment

## 完成提示

安装完成后，提示用户：

> App 已安装到 Room。下一步用 `/socialware-app` 进入 Room 运行 App。

## 关键原则

- **app-store 原件不变**: 安装是复制操作
- **Room 必须先存在**: 使用 `/room create` 创建
- **成员必须在 Room 中**: 不在的成员需要先加入
- **namespace 不可重复**: 同一 Room 内每个 App 实例有唯一 namespace
- **一个 App 可多次安装**: 不同 Room 或同 Room 不同 namespace
- **身份格式**: `{username}:{nickname}@{namespace}`（如 `alice:Alice@local`），无 `@` 前缀
