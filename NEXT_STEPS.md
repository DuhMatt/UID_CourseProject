# NEXT_STEPS — 提交前剩余工作清单

> 状态：Basic + OR3 + OR4 已 patch 并通过冒烟测试。下一步等队友 OR1/OR2/OR5 合并 + 报告收尾 + 打包 + 邮件提交。
> 维护者：吴梓豪 (R32314019，Basic + OR3 + OR4)
> 更新：2026-06-17

---

## 1. 等待队友交付

| 来源 | 期望文件 | 我需要做的事 |
|------|----------|--------------|
| 董劲豪 (OR1) | `or1_skeleton.m` 完善 + 测试 | 合并时确保 `onMouseDown` 的 `case 'sketch'/'erase'` 仍能 dispatch |
| 明子路 (OR2) | `or2_*.m` | 合并时确保 `S.vehicles(i).dispScale` 字段不被 OR2 误改（我初始化为 3） |
| 万静远 (OR5) | `or5_*.m` | 合并时确保 `S.mode` 新加的 `'or5_start'/'or5_end'` 不覆盖 `'loadIV'/'or4'/'measure2'/'track'` |

**合并前必做**：在群里发一句"我已把 main.m 的 `handleLoadIVClick` 改为调共享 `isRoadPointForUI`，大家确认是否会受影响"（B1 patch）。

---

## 2. 合并后必做（必修）

### M-1 打包清理
- [ ] 从 `UID_CourseProject.zip` 中**排除**以下目录/文件：
  - `backup_*/`（两个备份目录）
  - `optional_OR1/`（旧版 OR1）
  - `.pr_work/`（平行工作快照）
  - `.opencode/`（IDE 临时）
  - `.omo/`（OMO 状态）
  - `AGENTS.md`、`.debug-journal.md`（项目元信息，非提交内容）
  - `test_or4_math.py`（Python 旁路脚本，课程要求只用 MATLAB）
  - `test_rotation_output.png`（测试产物）
  - `smoke_test_main.m`、`debug_t9.m`（冒烟测试，按需决定是否提交）
- [ ] **包含** `or1_skeleton.m`（虽然不用但 main.m 引用了它；队友文件缺失会让你 UI 起不来）
- [ ] PowerShell 打包示例（参考）：
  ```powershell
  # 工作目录 = UID_Project
  $include = 'main.m','or3_auto_align.m','or4_street_view.m','or1_skeleton.m',
             'isRoadPointForUI.m',
             'MapForUI.jpg','RoadMask.jpg',
             '技术报告_*.md','README*.md',
             'test_step_*.m','test_or4_*.m','verify_view_center_rotation.m'
  # 复制到 _submit/ 然后压缩
  ```

### S6 旋转逻辑去重（中规模重构，**等 OR1 合并完一起做**）
- [ ] 抽出 `applyRotationToMap(S, map)` 函数
- [ ] 替换 `main.m` 中 `refreshDisplay`（约 line 491-516）和 `drawMeasurement`（约 line 1056-1093）两处的旋转分支
- [ ] 跑 `test_step_e.m` + `verify_view_center_rotation.m` + 手动旋转确认行为不变

### 报告最终化
- [ ] 第 5 节"分工"：根据队友实际交付情况更新 ⬜ → ✅ 或保持 ⬜
- [ ] 替换占位文字 "*(本节待组员 XXX 完成后补充)*" 为队友实际内容
- [ ] 把 §1.3 第 5 条"旋转中心跟随视图"对应代码段加注释引用
- [ ] 确认 17 张截图齐全（详见 §4.2 清单）

---

## 3. 应做（影响演示/验收体验，不影响通过）

- [ ] 手动跑一遍验收 checklist（Basic 12 项 + OR3 5 项 + OR4 7 项）截图存档
- [ ] 17 张演示截图：
  - 01-09 Basic（地图/坐标/IV 加载/IV 无效/IV 移除/IV 报告/测距/轨迹/旋转）
  - 10-12 OR3（自动对齐/对齐弹窗/车头朝上）
  - 13-17 OR4（弹窗/选点+FOV/街景/yaw 微调/非道路错误）
- [ ] 报告页眉填组号、提交日期、组长姓名
- [ ] 检查中文字体在截图里渲染正常（MATLAB 默认字体可能显示 □）

---

## 4. 可选（不影响验收，但能加分）

- [ ] 把 `smoke_test_main.m` 移到一个 `tests/` 子目录，让项目结构更清晰
- [ ] 在 `main.m` 头部加一段 "Patches Applied 2026-06-17" 注释（列 B1-B3/S1-S5），方便老师看到主动改进
- [ ] 在 README 里加一张主界面截图（放缩略图占位即可）

---

## 5. 提交邮件 checklist

- [ ] 收件人：Hao Li 教授邮箱
- [ ] 主题：ISE 333 Course Project — Group [组号] — [组名]
- [ ] 附件 1：`UID_CourseProject_GroupX.zip`（见 M-1 打包）
- [ ] 附件 2：`技术报告_GroupX.pdf`（md 转 pdf，推荐用 pandoc 或 typora）
- [ ] 邮件正文包含所有 5 位组员的完整姓名 + 学号
- [ ] **发送后必须等待教授回复 (Acknowledgement of reception)**，否则视为未提交

---

## 6. 关键文件状态

| 文件 | 状态 | 备注 |
|------|------|------|
| `main.m` | 已 patch（B1/B2/S1/S4/S5） | 1440 行 |
| `or3_auto_align.m` | 未动 | 160 行，OR3 算法 |
| `or4_street_view.m` | 已 patch（B3/S1/S2/S3） | 601 行 |
| `isRoadPointForUI.m` | 未动 | 91 行，共享道路验证 |
| `or1_skeleton.m` | 等队友 | 仅按钮触发，未在范围内修改 |
| `smoke_test_main.m` | 新增 | 8 项 patch 行为冒烟 |
| `技术报告_模板.md` | 已更新（FOV/sync/S1 描述） | 还差截图 + 队友补全 |
| `NEXT_STEPS.md` | 本文件 | 提交前 todo |
| `README_UI_Structure.md` | 待复核 | OR 状态从 Active/Disabled 改为按实际情况 |
| `OR2_OR5_开发接入指南.md` | 待精简 | §6 OR3/OR4 建议做法已成历史，可删 |
| `AGENTS.md` / `.debug-journal.md` | 元信息 | 不进 zip |

---

## 7. 验证命令

```matlab
% 算法层（无 UI）
run('test_step_a.m')              % 地图 + 坐标转换
run('test_step_d.m')              % IV 绘制 + pointInPolygon
run('test_step_e.m')              % 旋转算法 + 中心对齐
run('test_step_f.m')              % 测距算法
run('test_or4_road_point.m')      % OR4 道路点
run('test_or4_debug.m')           % OR4 渲染（独立）
run('verify_view_center_rotation.m')  % 旋转中心

% 端到端（matlab -batch 可跑）
run('smoke_test_main.m')          % main + OR3 + OR4 冒烟

% 启动
main                              % UI 启动（需图形环境）
```

所有 7 个测试脚本 + smoke test 已在 `matlab -batch` 下全部 PASS。

---

## 8. 紧急回滚

如果合并后出问题，按以下顺序回滚（每个都可独立回滚）：

| Patch | 回滚方式 |
|-------|----------|
| B1 | 把 `main.m:355` 改回 4 行 isBasicRoadPoint 写法 |
| B2 | 删 `main.m:831-843` 的 onIVDropdownChanged + 删 line 191 的 ValueChangedFcn |
| B3 | `or4_street_view.m:472` 删 viewW 局部，line 483 改回 `halfFov = 27.5 * pi / 180` |
| S1 | main.m:279 改回不带 selType；or4_street_view.m:17-22 改回 varargin{1}{2}；or4_street_view.m:231-240 改回 do_click(mainFig, col, row) |
| S2 | 删 `or4_street_view.m:317-322` |
| S3 | 还原 line 132 label 文字 |
| S4 | `main.m:1186` 改回带"手搓反向映射" |
| S5 | 重新加 `function out = rotateMap(img, deg) ... end` 5 行 |
