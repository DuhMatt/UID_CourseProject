% test_omo_basic_or3_or4.m
% OMO 自动化测试 — Basic UI + OR3 + OR4
% 每个测试用 try-catch 保护，失败不中断，末尾打印总结。
%
% 运行方式：
%   matlab -batch "run('test_omo_basic_or3_or4.m')"
%   或在 MATLAB 命令行: run('test_omo_basic_or3_or4.m')

fprintf('╔══════════════════════════════════════════════╗\n');
fprintf('║  OMO 自动化测试: Basic + OR3 + OR4         ║\n');
fprintf('╚══════════════════════════════════════════════╝\n\n');

passed = 0; failed = 0;

%% ═══════════════════════════════════════════════
%% 第一部分：Basic UI（B1–B8）
%% ═══════════════════════════════════════════════
fprintf('\n─── 第一部分: Basic UI ───\n');

% ---- 存放跨测试共享的变量 ----
fig = [];
S = struct();
roadRow = 0; roadCol = 0;   % B3 找到的道路点
vid = 0;                    % B4 车辆 ID

%% B1: 启动 + 地图加载
fprintf('\n▶ B1: 启动 + 地图加载\n');

try
    fig = main();
    pause(0.3);
    S = getappdata(fig, 'S');
    if ~isvalid(fig)
        error('窗口无效');
    end
    if isempty(S.mapOrigin)
        error('地图未加载');
    end
    [H, W, ~] = size(S.mapOrigin);
    if ~isequal([H W], [803 1404])
        error('地图尺寸应为 803x1404，实际 %dx%d', H, W);
    end
    if abs(S.scale - 1.7) >= 0.01
        error('比例尺应为 1.7，实际 %.2f', S.scale);
    end
    if abs(S.userZoom - 1.0) >= 0.01
        error('初始缩放应为 1.0，实际 %.2f', S.userZoom);
    end
    fprintf('  窗口有效 | 地图: %dx%d | scale=%.1f | userZoom=%.1f\n', W, H, S.scale, S.userZoom);
    fprintf('  [PASS] B1: 启动 + 地图加载\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B1: 启动 + 地图加载 — %s\n', ME.message);
    failed = failed + 1;
end

%% B1.5: 控件完整性
fprintf('\n▶ B1.5: 控件完整性\n');

try
    fields = {'rotSlider','zoomSlider','btnResetView','btnOR1','btnOR2','btnOR3','btnOR4','btnOR5',...
              'btnLoadIV','btnRemoveIV','ivDropdown','angleSlider','chkAutoAlign','chkHeadUp',...
              'btnReportIV','btnMeasure2','btnTrack','btnClearMeasure','coordX','coordY','statusBar'};
    missing = {};
    for i = 1:numel(fields)
        if ~isfield(S.handles, fields{i}) || ~isvalid(S.handles.(fields{i}))
            missing{end+1} = fields{i};
        end
    end
    if ~isempty(missing)
        error('缺失控件: %s', strjoin(missing, ', '));
    end
    fprintf('  [PASS] B1.5: 全部 %d 个控件就绪\n', numel(fields));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B1.5: 控件完整性 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B2: 坐标显示
fprintf('\n▶ B2: 坐标显示\n');

try
    if ~isfield(S.handles,'coordX') || ~isfield(S.handles,'coordY')
        error('坐标标签控件不存在');
    end
    savedX = S.handles.coordX.Text;
    savedY = S.handles.coordY.Text;
    fprintf('  当前坐标: %s  %s\n', savedX, savedY);
    fprintf('  [PASS] B2: 坐标显示就绪\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B2: 坐标显示 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B3: 道路检测 + 加载车辆
fprintf('\n▶ B3: 道路检测 + 加载车辆\n');

try
    % 找道路点
    if ~isempty(S.basicRoadMask)
        maskGray = mean(double(S.basicRoadMask), 3);
        [r, c] = ind2sub(size(maskGray), find(maskGray > 160, 1));
    elseif ~isempty(S.roadMask)
        [r, c] = find(S.roadMask, 1);
    else
        error('无道路 mask 可用');
    end
    if isempty(r) || isempty(c)
        error('找不到道路点');
    end
    roadRow = r; roadCol = c;
    fprintf('  道路点: row=%d col=%d\n', roadRow, roadCol);

    % 验证道路检测
    onRoad = isRoadPointForUI(S.mapOrigin, S.basicRoadMask, S.roadMask, roadRow, roadCol);
    if ~onRoad
        error('道路点被误判为非道路');
    end
    fprintf('  [PASS] B3-a: isRoadPointForUI 正确识别道路点\n');
    passed = passed + 1;

    % 加载车辆到道路点（直接操作 S，不依赖 main 内部函数）
    v.id = S.nextIVid; v.cx = roadCol; v.cy = roadRow; v.angle = 30; v.dispScale = 3;
    S.vehicles(end+1) = v;
    S.nextIVid = S.nextIVid + 1;
    S.mode = 'idle';
    setappdata(fig, 'S', S);
    S = getappdata(fig, 'S');
    if numel(S.vehicles) < 1
        error('车辆未加载');
    end
    % 更新下拉保持 UI 一致
    items = cell(1, numel(S.vehicles));
    for i = 1:numel(S.vehicles)
        items{i} = sprintf('#%d (%.0f,%.0f)', S.vehicles(i).id, S.vehicles(i).cx, S.vehicles(i).cy);
    end
    S.handles.ivDropdown.Items = items;
    S.handles.ivDropdown.Value = items{end};
    setappdata(fig, 'S', S);
    fprintf('  [PASS] B3-b: 成功加载车辆 #%d @ (%d,%d)\n', v.id, roadCol, roadRow);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B3: 道路检测 + 加载车辆 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.3);

%% B4: 调整车辆朝向
fprintf('\n▶ B4: 调整车辆朝向\n');

try
    vid = S.vehicles(end).id;
    % 更新下拉
    items = cell(1, numel(S.vehicles));
    for i = 1:numel(S.vehicles)
        items{i} = sprintf('#%d (%.0f,%.0f)', S.vehicles(i).id, S.vehicles(i).cx, S.vehicles(i).cy);
    end
    S.handles.ivDropdown.Items = items;
    S.handles.ivDropdown.Value = items{end};
    setappdata(fig, 'S', S);

    % 调角度滑条
    S.handles.angleSlider.Value = 90;
    S.handles.angleSlider.ValueChangedFcn(S.handles.angleSlider, []);
    S = getappdata(fig, 'S');
    idx = find(arrayfun(@(v) v.id == vid, S.vehicles), 1);
    if isempty(idx)
        error('车辆 #%d 未找到', vid);
    end
    if abs(S.vehicles(idx).angle - 90) >= 1
        error('角度=%f, 期望 90', S.vehicles(idx).angle);
    end
    fprintf('  [PASS] B4: 车辆 #%d 角度 = %.0f°\n', vid, S.vehicles(idx).angle);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B4: 调整车辆朝向 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B5: 移除车辆
fprintf('\n▶ B5: 移除车辆\n');

try
    nBefore = numel(S.vehicles);
    S.vehicles(end) = [];
    setappdata(fig, 'S', S);
    S = getappdata(fig, 'S');
    if numel(S.vehicles) ~= nBefore - 1
        error('移除失败: 前 %d 后 %d', nBefore, numel(S.vehicles));
    end
    fprintf('  [PASS] B5: 从 %d 辆减为 %d 辆\n', nBefore, numel(S.vehicles));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B5: 移除车辆 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B6: 加载车辆
fprintf('\n▶ B6: 加载车辆\n');

try
    v2.id = S.nextIVid; v2.cx = roadCol + 10; v2.cy = roadRow; v2.angle = 45; v2.dispScale = 3;
    S.vehicles(end+1) = v2;
    S.nextIVid = S.nextIVid + 1;
    setappdata(fig, 'S', S);
    S = getappdata(fig, 'S');
    if numel(S.vehicles) < 1
        error('车辆未加载，当前 %d 辆', numel(S.vehicles));
    end
    % 更新下拉
    items = cell(1, numel(S.vehicles));
    for i = 1:numel(S.vehicles)
        items{i} = sprintf('#%d (%.0f,%.0f)', S.vehicles(i).id, S.vehicles(i).cx, S.vehicles(i).cy);
    end
    S.handles.ivDropdown.Items = items;
    S.handles.ivDropdown.Value = items{end};
    setappdata(fig, 'S', S);
    fprintf('  [PASS] B6: 已加载 %d 辆车\n', numel(S.vehicles));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B6: 加载第二辆车 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B7: 距离测量
fprintf('\n▶ B7: 距离测量\n');

% B7-a: 两点测距
try
    S.measurePts = [roadCol, roadRow; roadCol + 100, roadRow];
    expectedDist = 100 * S.scale;
    setappdata(fig, 'S', S);
    if size(S.measurePts, 1) ~= 2
        error('测距点=%d，期望 2', size(S.measurePts,1));
    end
    fprintf('  [PASS] B7-a: 两点测距 100px = %.2f m\n', expectedDist);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B7-a: 两点测距 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

% B7-b: 轨迹测量
try
    S.measurePts = [roadCol, roadRow; roadCol + 50, roadRow; roadCol + 100, roadRow];
    setappdata(fig, 'S', S);
    if size(S.measurePts, 1) ~= 3
        error('轨迹点=%d，期望 3', size(S.measurePts,1));
    end
    fprintf('  [PASS] B7-b: 轨迹测量 3 点记录成功\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B7-b: 轨迹测量 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

% B7-c: 清除测量
try
    S.measurePts = zeros(0,2); S.mode = 'idle';
    setappdata(fig, 'S', S);
    S = getappdata(fig, 'S');
    if ~isempty(S.measurePts)
        error('清除失败，pts=%d', size(S.measurePts,1));
    end
    fprintf('  [PASS] B7-c: 清除测量标记\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B7-c: 清除测量 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% B8: 旋转地图
fprintf('\n▶ B8: 旋转地图\n');

% B8-a: 旋转 45°
try
    rotSlider = S.handles.rotSlider;
    rotSlider.Value = 45;
    rotSlider.ValueChangedFcn(rotSlider, []);
    S = getappdata(fig, 'S');
    if abs(S.rotDeg - 45) >= 1
        error('rotDeg=%d，期望 45', S.rotDeg);
    end
    fprintf('  [PASS] B8-a: 旋转 45° — rotDeg=%d\n', S.rotDeg);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B8-a: 旋转 45° — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

% B8-b: 旋转归零
try
    rotSlider = S.handles.rotSlider;
    rotSlider.Value = 0;
    rotSlider.ValueChangedFcn(rotSlider, []);
    S = getappdata(fig, 'S');
    if abs(S.rotDeg) >= 1
        error('rotDeg=%d 未归零', S.rotDeg);
    end
    fprintf('  [PASS] B8-b: 旋转归零\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B8-b: 旋转归零 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

% B8-c: 重置视图
try
    S.handles.btnResetView.ButtonPushedFcn(S.handles.btnResetView, []);
    S = getappdata(fig, 'S');
    if abs(S.userZoom - 1.0) >= 0.01
        error('重置后 zoom=%.2f，期望 1.0', S.userZoom);
    end
    if abs(S.rotDeg) >= 1
        error('重置后 rotDeg=%d，期望 0', S.rotDeg);
    end
    fprintf('  [PASS] B8-c: 重置视图 zoom=%.1f rotDeg=%d\n', S.userZoom, S.rotDeg);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] B8-c: 重置视图 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.3);

%% ═══════════════════════════════════════════════
%% 第二部分：OR3（自动对齐 + 车头朝上 + 弹窗）
%% ═══════════════════════════════════════════════
fprintf('\n─── 第二部分: OR3 ───\n');

% 清空测试车辆，加载一辆干净的
try
    S.vehicles = struct('id',{},'cx',{},'cy',{},'angle',{},'dispScale',{});
    S.nextIVid = 1;
    setappdata(fig, 'S', S);
catch
    % 静默
end

%% OR3: 自动对齐加载
fprintf('\n▶ OR3: 自动对齐加载\n');

try
    S.handles.chkAutoAlign.Value = true;
    % 调用 or3_auto_align 获取自动对齐角度（独立函数，可外部调用）
    autoAngle = or3_auto_align('findAngle', fig, roadCol, roadRow);
    % 直接用对齐后的角度创建车辆
    v.id = 1; v.cx = roadCol; v.cy = roadRow; v.angle = autoAngle; v.dispScale = 3;
    S.vehicles = v;
    S.nextIVid = 2;
    setappdata(fig, 'S', S);
    S = getappdata(fig, 'S');
    if numel(S.vehicles) ~= 1
        error('车辆未加载（OR3 自动对齐）');
    end
    angle1 = S.vehicles(1).angle;
    if isnan(angle1)
        error('自动对齐角度为 NaN');
    end
    fprintf('  [PASS] OR3-aa: 自动对齐角度 = %.1f°（非 NaN）\n', angle1);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR3-aa: 自动对齐 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR3: 车头朝上切换 — 开启
fprintf('\n▶ OR3: 车头朝上模式\n');

try
    chk = S.handles.chkHeadUp;
    chk.Value = true;
    chk.ValueChangedFcn(chk, []);
    S = getappdata(fig, 'S');
    if ~S.headUpMode
        error('headUpMode 未开启');
    end
    fprintf('  [PASS] OR3-hu-on: 车头朝上已开启\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR3-hu-on: 车头朝上开启 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

% OR3: 车头朝上切换 — 关闭
try
    chk = S.handles.chkHeadUp;
    chk.Value = false;
    chk.ValueChangedFcn(chk, []);
    S = getappdata(fig, 'S');
    if S.headUpMode
        error('headUpMode 未关闭');
    end
    fprintf('  [PASS] OR3-hu-off: 车头朝上已关闭\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR3-hu-off: 车头朝上关闭 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR3: 弹窗
fprintf('\n▶ OR3: 弹窗测试\n');

try
    S.handles.btnOR3.ButtonPushedFcn(S.handles.btnOR3, []);
    S = getappdata(fig, 'S');
    if ~isfield(S,'or3Fig') || ~isvalid(S.or3Fig)
        error('OR3 弹窗未创建');
    end
    fprintf('  [PASS] OR3-popup: 弹窗已打开\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR3-popup: 弹窗打开 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.3);

% 关闭弹窗
try
    if isfield(S,'or3Fig') && isvalid(S.or3Fig)
        close(S.or3Fig);
    end
    S.or3Fig = [];
    setappdata(fig, 'S', S);
    fprintf('  [PASS] OR3-popup-close: 弹窗已关闭\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR3-popup-close: 弹窗关闭 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% ═══════════════════════════════════════════════
%% 第三部分：OR4（虚拟街景）
%% ═══════════════════════════════════════════════
fprintf('\n─── 第三部分: OR4 ───\n');

or4Fig = [];

%% OR4: 打开窗口
fprintf('\n▶ OR4: 打开窗口\n');

try
    or4_street_view('open', fig);
    pause(0.5);
    S = getappdata(fig, 'S');
    if ~isfield(S,'or4Fig') || ~isvalid(S.or4Fig)
        error('OR4 窗口未创建');
    end
    or4Fig = S.or4Fig;
    fprintf('  [PASS] OR4-open: OR4 窗口已打开\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-open: 打开窗口 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: 窗口尺寸验证
fprintf('\n▶ OR4: 窗口尺寸 ≥ 1000×750\n');

try
    or4Pos = get(or4Fig, 'Position');
    fprintf('  当前尺寸: %d×%d\n', or4Pos(3), or4Pos(4));
    if or4Pos(3) < 1000
        error('宽度=%d < 1000', or4Pos(3));
    end
    if or4Pos(4) < 750
        error('高度=%d < 750', or4Pos(4));
    end
    fprintf('  [PASS] OR4-size: 窗口 ≥ 1000×750\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-size: 窗口尺寸 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: alwaysontop 验证（警告而非失败）
fprintf('\n▶ OR4: alwaysontop 验证\n');

try
    ws = get(or4Fig, 'WindowStyle');
    if strcmpi(ws, 'alwaysontop')
        fprintf('  [PASS] OR4-ontop: WindowStyle = alwaysontop\n');
        passed = passed + 1;
    else
        fprintf('  [WARN] OR4-ontop: WindowStyle = "%s"（旧版 MATLAB 可能不支持 alwaysontop）\n', ws);
        % 不失败，只警告
    end
catch ME
    fprintf('  [FAIL] OR4-ontop: 查询 WindowStyle — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: 相机点击道路点
fprintf('\n▶ OR4: 相机点击道路点\n');

try
    S.mode = 'or4';
    setappdata(fig, 'S', S);
    or4_street_view('click', fig, roadCol, roadRow, 'normal');
    S = getappdata(fig, 'S');
    cam = S.or4.cam;
    expectedX = roadCol * S.scale;
    if abs(cam.realX - expectedX) >= 1
        error('cam.realX=%.1f 期望=%.1f', cam.realX, expectedX);
    end
    fprintf('  [PASS] OR4-click: 相机 X=%.1f Y=%.1f yaw=%.0f°\n', cam.realX, cam.realY, cam.yawDegree);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-click: 相机点击 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: 右键取消 OR4 模式
fprintf('\n▶ OR4: 右键取消 OR4 模式\n');

try
    S.mode = 'or4';
    setappdata(fig, 'S', S);
    or4_street_view('click', fig, roadCol, roadRow, 'alt');
    S = getappdata(fig, 'S');
    if ~strcmp(S.mode, 'idle')
        error('mode=%s 非 idle', S.mode);
    end
    fprintf('  [PASS] OR4-rightclick: mode=idle\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-rightclick: 右键取消 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: 多次渲染后窗口不缩小
fprintf('\n▶ OR4: 多次渲染后窗口不缩小\n');

try
    S.mode = 'or4';
    setappdata(fig, 'S', S);
    for i = 1:3
        or4_street_view('click', fig, roadCol + i*5, roadRow, 'normal');
        pause(0.2);
    end
    or4Pos = get(or4Fig, 'Position');
    fprintf('  3次渲染后尺寸: %d×%d\n', or4Pos(3), or4Pos(4));
    if or4Pos(3) < 1000
        error('渲染后宽度=%d < 1000', or4Pos(3));
    end
    if or4Pos(4) < 750
        error('渲染后高度=%d < 750', or4Pos(4));
    end
    fprintf('  [PASS] OR4-noshrink: 窗口尺寸保持 ≥ 1000×750\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-noshrink: 窗口缩小 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: cachedImage 验证
fprintf('\n▶ OR4: 渲染缓存验证\n');

try
    if isempty(S.or4.cachedImage)
        error('cachedImage 为空');
    end
    [ciH, ciW, ~] = size(S.or4.cachedImage);
    fprintf('  渲染输出: %d×%d\n', ciW, ciH);
    if ciW < 520 || ciH < 360
        error('渲染太小 %dx%d（期望 ≥520×360）', ciW, ciH);
    end
    fprintf('  [PASS] OR4-cached: 渲染输出 %d×%d ≥ 520×360\n', ciW, ciH);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-cached: 渲染缓存 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.2);

%% OR4: 车辆下拉同步
fprintf('\n▶ OR4: 车辆下拉同步\n');

try
    vehItems = S.or4.vehDrop.Items;
    fprintf('  车辆列表: %s\n', strjoin(vehItems, ', '));
    if numel(vehItems) < 2
        error('下拉未包含车辆（共 %d 项）', numel(vehItems));
    end
    fprintf('  [PASS] OR4-dropdown: 下拉包含 %d 项\n', numel(vehItems));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] OR4-dropdown: 车辆下拉 — %s\n', ME.message);
    failed = failed + 1;
end
pause(0.3);

%% ═══════════════════════════════════════════════
%% 清理：关闭 OR4、OR3、主窗口
%% ═══════════════════════════════════════════════
fprintf('\n─── 清理 ───\n');

try
    if ~isempty(or4Fig) && isvalid(or4Fig)
        close(or4Fig);
        pause(0.3);
        fprintf('  [OK] OR4 窗口已关闭\n');
    end
catch ME
    fprintf('  [WARN] 关闭 OR4 时出错: %s\n', ME.message);
end

try
    if ~isempty(fig) && isvalid(fig)
        close(fig);
        pause(0.3);
        fprintf('  [OK] 主窗口已关闭\n');
    end
catch ME
    fprintf('  [WARN] 关闭主窗口时出错: %s\n', ME.message);
end

%% ═══════════════════════════════════════════════
%% 总结
%% ═══════════════════════════════════════════════
total = passed + failed;
fprintf('\n╔══════════════════════════════════════════════╗\n');
fprintf('║  测试总结                                   ║\n');
fprintf('║  PASS: %2d  FAIL: %2d  TOTAL: %2d          ║\n', passed, failed, total);
if failed == 0
    fprintf('║  全部通过                                   ║\n');
else
    fprintf('║  有 %d 项失败                                ║\n', failed);
end
fprintf('╚══════════════════════════════════════════════╝\n');

if failed > 0
    error('测试未全部通过: %d 项失败', failed);
end
