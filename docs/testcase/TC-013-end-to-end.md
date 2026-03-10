# TC-013: 完整端到端

> **测试目标**：从零开始，走通设计模板 → 创建 Room → 安装 App → 多人协作 → 状态重建的全链路
> **前置依赖**：无（自包含）
> **测试 Skill**：`/socialware-dev` + `/room` + `/socialware-app-dev` + `/socialware-app`
> **覆盖 Spec**：001-007

---

## 场景：从零搭建一个双角色审批系统并完成协作

### Step 1: 设计 Socialware 模板

- **操作**：执行 `/socialware-dev`，描述"设计一个双角色审批流——提交者提交文档，审批者审批或驳回"
- **前置依赖**：无
- **验证**：模板文件生成
- **验收标准**：
  - 输出文件：`simulation/contracts/two-role-submit-approve.socialware.md`
  - §1 有 R1(提交者) 和 R2(审批者)，Holder 全为 `_待绑定_`
  - §2 有完整的状态转换表（_none_→submit→submitted, submitted→approve→approved, submitted→reject→rejected, rejected→revise→submitted）
  - §3 有 C1（审批者在规定时间内回复）
  - §4 有准入策略
  - §5 有每个 action 的 binding 骨架，Tool 全为 `_待绑定_`
  - 扩展名 `.socialware.md`

### Step 2: 创建 Room

- **操作**：执行 `/room create project-e2e`，创建者 @alice:local
- **前置依赖**：无
- **验证**：Room 目录结构完整
- **验收标准**：
  - `simulation/workspace/rooms/project-e2e/` 存在
  - 子目录：identities/, contracts/, timeline/, content/, artifacts/
  - `config.json` 中 @alice:local 为 owner
  - `state.json` 中所有字段初始化为空

### Step 3: 加入 Room

- **操作**：执行 `/room join project-e2e @bob`
- **前置依赖**：Step 2
- **验证**：@bob 成功加入
- **验收标准**：
  - `config.json` 的 `membership.members` 包含 `"@bob:local": "member"`
  - Identity 文件 `@bob.json` 存在
  - `state.json` 的 `peer_cursors` 有 @bob 条目

### Step 4: 安装 Socialware App

- **操作**：执行 `/socialware-app-dev`
  - 模板：two-role-submit-approve.socialware.md
  - Room：project-e2e
  - Namespace：da
  - 角色绑定：R1→@alice:local, R2→@bob:local
  - 工具绑定：全部 manual
- **前置依赖**：Step 1, Step 3
- **验证**：App 安装成功
- **验收标准**：
  - `contracts/da.app.md` 存在
  - §1 Holder 已填入具体 Identity
  - §5 Tool 已填入（无 `_待绑定_`）
  - `config.json` 的 `socialware.installed` = `["da"]`
  - `state.json` 的 `role_map` 有 @alice 和 @bob 的角色
  - `commitments` 有 `da:C1` 且 status=inactive

### Step 5: Alice 启动 App

- **操作**：执行 `/socialware-app`，Room=project-e2e，Identity=@alice:local
- **前置依赖**：Step 4
- **验证**：启动面板正确
- **验收标准**：
  - 显示角色 da:R1
  - 显示可用操作 da:submit, da:revise
  - Clock = 0，无活跃 Flow

### Step 6: Alice 提交任务

- **操作**：@alice 提交"E2E 测试任务"
- **前置依赖**：Step 5
- **验证**：完整 Hook Pipeline 执行
- **验收标准**：
  - pre_send: Role(R1✓) + CBAC(any✓) + Flow(_none_→submit✓) 通过
  - execute: manual 工具执行，Content Object 生成
  - after_write: Timeline 追加 msg-001(clock:1)，State 更新（submitted），Commitment C1 激活
  - `flow_states["msg-001"]` = `{flow: "da:task_lifecycle", state: "submitted", subject_author: "@alice:local"}`

### Step 7: Bob 查看收件箱

- **操作**：切换到 @bob（`/switch @bob`）
- **前置依赖**：Step 6
- **验证**：收件箱显示 Alice 的提交
- **验收标准**：
  - 收件箱：`[clock:1] @alice:local 提交了任务: E2E 测试任务`
  - @bob 可看到可执行的操作：approve, reject

### Step 8: Bob 审批

- **操作**：@bob 审批 msg-001，意见"方案可行"
- **前置依赖**：Step 7
- **验证**：审批成功，全链路完成
- **验收标准**：
  - pre_send: Role(R2✓) + CBAC(any✓) + Flow(submitted→approve✓) 通过
  - execute: manual 输入审批意见
  - after_write: Timeline 追加 msg-002(clock:2)
  - `flow_states["msg-001"].state` = `approved`
  - `commitments["da:C1"].status` = `fulfilled`

### Step 9: Alice 查看结果

- **操作**：切换回 @alice（`/switch @alice`）
- **前置依赖**：Step 8
- **验证**：Alice 看到审批结果
- **验收标准**：
  - 收件箱：`[clock:2] @bob:local 审批通过: 方案可行`
  - `/status` 显示 msg-001 = approved

### Step 10: 验证 Timeline

- **操作**：读取 `timeline/shard-001.jsonl`
- **前置依赖**：Step 8
- **验证**：完整消息记录
- **验收标准**：
  - 2 行，clock 1 和 2
  - msg-001: author=@alice, action=submit, reply_to=null
  - msg-002: author=@bob, action=approve, reply_to=msg-001
  - 每行的 content_id 指向存在的 Content Object

### Step 11: 验证 State 最终状态

- **操作**：读取 `state.json`
- **前置依赖**：Step 8
- **验证**：最终状态正确
- **验收标准**：
  - `flow_states["msg-001"]` = approved
  - `commitments["da:C1"]` = fulfilled
  - `last_clock` = 2
  - `peer_cursors` 中 @alice 和 @bob 都有值

### Step 12: State 重建验证

- **操作**：执行 `/rebuild`
- **前置依赖**：Step 11
- **验证**：CRDT 属性
- **验收标准**：
  - 重建后 state.json 与重建前完全一致
  - 证明 `State = f(Timeline)` 成立
  - flow_states, commitments, peer_cursors 全部匹配

### Step 13: 模板未被修改

- **操作**：读取 `simulation/contracts/two-role-submit-approve.socialware.md`
- **前置依赖**：Step 4
- **验证**：模板保持只读
- **验收标准**：
  - §1 Holder 仍为 `_待绑定_`
  - §5 Tool 仍为 `_待绑定_`
  - 模板文件未被任何步骤修改

### Step 14: 全链路数据一致性

- **操作**：综合验证所有数据格式
- **前置依赖**：Step 12
- **验证**：所有文件格式符合 data-formats.md 规范
- **验收标准**：
  - config.json 符合 config.json schema
  - state.json 符合 state.json schema
  - Timeline Ref 符合 Ref schema
  - Content Object 符合 Content Object schema
  - da.app.md 符合 .app.md 规范（§1-§6 完整）
  - 所有 Identity 文件符合 Identity schema
