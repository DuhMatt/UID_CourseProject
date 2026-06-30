# OPTIONAL OR1 KNOWLEDGE

## OVERVIEW

Legacy OR1-focused MATLAB subtree with its own launcher, OR1 docs, and GUI tests. Do not assume it is the active root app.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Run this subtree app | `main_OR1.m` | OR1-specific launcher, separate from root `main.m`. |
| OR1 implementation | `or1_skeleton.m` | Local copy for this subtree. |
| Test/run guidance | `队友开发指南.md` | Most explicit OR1 workflow and test command list. |
| User-facing guide | `使用手册.md` | Manual use notes. |
| Algorithm checks | `test_step_b.m`, `test_step_c.m` | OR1 geometry and mask checks. |
| GUI checks | `test_gui_*.m`, `test_or1_popup.m` | OR1 UI workflow and popup behavior. |

## CONVENTIONS

- Keep changes local to `optional_OR1/`; the root app has separate active files.
- Run MATLAB tests from this directory unless a test explicitly references root files.
- State flows through `S` in appdata. Read with `getappdata`, mutate, and write back.
- OR1 coordinates use image `[col, row]`; world `Y` is inverted relative to image rows.
- Draw OR1 road/skeleton overlays by editing image matrices and refreshing the UI.

## TESTS

```matlab
run('test_gui_smoke.m')
run('test_gui_rot.m')
run('test_gui_step_b.m')
run('test_gui_step_c.m')
run('test_gui_step_d.m')
run('test_gui_step_f.m')
run('test_or1_popup.m')
run('test_step_b.m')
run('test_step_c.m')
```

## ANTI-PATTERNS

- Do not copy changes blindly between this subtree and the root app; same names do not mean same state.
- Do not add optional OR2-OR5 work here unless the user specifically asks for the legacy OR1 subtree.
- Do not mutate the original map image; build display copies and refresh.
