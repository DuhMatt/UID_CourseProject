function or2_local_view(action, mainFig, varargin)
%OR2_LOCAL_VIEW  OR2 IV缩放与圆形局部地图
    switch action
        case 'open'
            do_open(mainFig);
        case 'click'
            col = varargin{1}; row = varargin{2}; selType = varargin{3};
            do_click(mainFig, col, row, selType);
        case 'sync'
            do_sync(mainFig);
        otherwise
            error('Unknown OR2 action: %s', action);
    end
end


%% ====================================================================
%   打开控制窗口（对应原 main.m 的 onBtnOR2）
%% ====================================================================
function do_open(mainFig)
    S = getappdata(mainFig, 'S');

    % 进入 OR2 模式
    S.mode = 'or2';
    setappdata(mainFig, 'S', S);

    % 若窗口已存在则前置
    if isfield(S, 'or2Fig') && ~isempty(S.or2Fig) && isvalid(S.or2Fig)
        figure(S.or2Fig);
        return;
    end

    % 创建窗口
    or2Fig = uifigure('Name', 'OR2：IV缩放与圆形局部地图', ...
                      'Position', [220 120 640 620], ...
                      'Resize', 'off', ...
                      'WindowStyle', 'alwaysontop');

    gl = uigridlayout(or2Fig, [10 2]);
    gl.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','fit','fit','1x'};
    gl.ColumnWidth = {'1x','1x'};

    % Row 1: 标题
    titleLabel = uilabel(gl, ...
        'Text', 'OR2：IV缩放与圆形局部地图', ...
        'FontSize', 15, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');
    titleLabel.Layout.Row = 1;
    titleLabel.Layout.Column = [1 2];

    % Row 2: IV 数量信息
    infoLabel = uilabel(gl, ...
        'Text', sprintf('当前 IV 数量：%d', numel(S.vehicles)), ...
        'FontSize', 10);
    infoLabel.Layout.Row = 2;
    infoLabel.Layout.Column = [1 2];

    % Row 3: 选择 IV
    labelIV = uilabel(gl, 'Text', '选择 IV：', 'FontSize', 10);
    labelIV.Layout.Row = 3;
    labelIV.Layout.Column = 1;

    if isempty(S.vehicles)
        items = {'(无IV，请先加载车辆)'};
    else
        items = or2MakeVehicleItems(S);
    end

    dropdown = uidropdown(gl, ...
        'Items', items, ...
        'Value', items{1}, ...
        'ValueChangedFcn', @(~,~) or2VehicleChanged(mainFig));
    dropdown.Layout.Row = 3;
    dropdown.Layout.Column = 2;

    % Row 4: 缩放倍数标签
    scaleValue = 3;
    if ~isempty(S.vehicles)
        scaleValue = round(S.vehicles(1).dispScale);
    end

    scaleLabel = uilabel(gl, ...
        'Text', sprintf('IV显示缩放倍数：%d', scaleValue), ...
        'FontSize', 10);
    scaleLabel.Layout.Row = 4;
    scaleLabel.Layout.Column = [1 2];

    % Row 5: 缩放滑块
    scaleSlider = uislider(gl, ...
        'Limits', [1 10], ...
        'Value', scaleValue, ...
        'MajorTicks', 1:10, ...
        'ValueChangedFcn', @(src,~) or2ScaleChanged(mainFig, src));
    scaleSlider.Layout.Row = 5;
    scaleSlider.Layout.Column = [1 2];

    % Row 6: 半径标签
    radiusValue = 120;

    radiusLabel = uilabel(gl, ...
        'Text', sprintf('圆形局部地图半径：%d m', radiusValue), ...
        'FontSize', 10);
    radiusLabel.Layout.Row = 6;
    radiusLabel.Layout.Column = [1 2];

    % Row 7: 半径滑块
    radiusSlider = uislider(gl, ...
        'Limits', [20 500], ...
        'Value', radiusValue, ...
        'MajorTicks', [20 100 200 300 400 500], ...
        'ValueChangedFcn', @(src,~) or2RadiusChanged(mainFig, src));
    radiusSlider.Layout.Row = 7;
    radiusSlider.Layout.Column = [1 2];

    % Row 8: 按钮
    btnShow = uibutton(gl, ...
        'Text', '显示圆形局部地图', ...
        'ButtonPushedFcn', @(~,~) or2ShowLocal(mainFig));
    btnShow.Layout.Row = 8;
    btnShow.Layout.Column = 1;

    btnRestore = uibutton(gl, ...
        'Text', '恢复完整主地图', ...
        'ButtonPushedFcn', @(~,~) or2Restore(mainFig));
    btnRestore.Layout.Row = 8;
    btnRestore.Layout.Column = 2;

    % Row 9: 提示
    hintLabel = uilabel(gl, ...
        'Text', '说明：在主地图点击时，OR2会自动选择最近IV并更新局部圆形地图。', ...
        'FontSize', 9, ...
        'FontAngle', 'italic');
    hintLabel.Layout.Row = 9;
    hintLabel.Layout.Column = [1 2];

    % Row 10: 预览 axes
    previewAx = uiaxes(gl);
    previewAx.Layout.Row = 10;
    previewAx.Layout.Column = [1 2];
    previewAx.XTick = [];
    previewAx.YTick = [];
    previewAx.Box = 'off';
    previewAx.Toolbar.Visible = 'off';

    % 写回 S
    S = getappdata(mainFig, 'S');
    S.mode = 'or2';
    S.or2Fig = or2Fig;
    S.or2 = struct();
    S.or2.dropdown     = dropdown;
    S.or2.scaleSlider  = scaleSlider;
    S.or2.radiusSlider = radiusSlider;
    S.or2.scaleLabel   = scaleLabel;
    S.or2.radiusLabel  = radiusLabel;
    S.or2.infoLabel    = infoLabel;
    S.or2.previewAx    = previewAx;
    S.or2.radiusM      = radiusValue;

    setappdata(mainFig, 'S', S);

    set(or2Fig, 'CloseRequestFcn', @(~,~) or2Close(mainFig));

    S.fn.setStatus(mainFig, 'OR2控制窗口已打开。');

    % 如果已有 IV，立即显示一次；否则显示提示
    if isempty(S.vehicles)
        cla(previewAx);
        text(previewAx, 0.5, 0.5, '请先在主地图加载 IV', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 14);
        previewAx.XLim = [0 1];
        previewAx.YLim = [0 1];
    else
        or2ShowLocal(mainFig);
    end

    drawnow;
end


%% ====================================================================
%   同步状态（main.m 在 IV 增删改后调用，更新 OR2 窗口）
%% ====================================================================
function do_sync(mainFig)
    S = getappdata(mainFig, 'S');

    % 窗口未打开则忽略
    if ~isfield(S, 'or2Fig') || isempty(S.or2Fig) || ~isvalid(S.or2Fig)
        return;
    end

    % 更新 IV 数量信息
    if isfield(S, 'or2') && isfield(S.or2, 'infoLabel') && isvalid(S.or2.infoLabel)
        if ~isempty(S.vehicles)
            S.or2.infoLabel.Text = sprintf('当前 IV 数量：%d', numel(S.vehicles));
        else
            S.or2.infoLabel.Text = '当前无 IV';
        end
    end

    % 更新下拉列表
    items = or2MakeVehicleItems(S);
    if isfield(S, 'or2') && isfield(S.or2, 'dropdown') && isvalid(S.or2.dropdown)
        S.or2.dropdown.Items = items;
        if ~isempty(S.vehicles)
            S.or2.dropdown.Value = items{end};
        else
            S.or2.dropdown.Value = items{1};
        end
    end

    setappdata(mainFig, 'S', S);

    % 刷新局部地图
    if isempty(S.vehicles)
        ax = S.or2.previewAx;
        if isvalid(ax)
            cla(ax);
            text(ax, 0.5, 0.5, '请先加载车辆', ...
                'HorizontalAlignment', 'center', 'FontSize', 14);
            ax.XLim = [0 1];
            ax.YLim = [0 1];
        end
    else
        or2ShowLocal(mainFig);
    end
end


%% ====================================================================
%   鼠标点击（对应原 main.m 的 onOR2MapClick）
%% ====================================================================
function do_click(mainFig, col, row, ~)
    S = getappdata(mainFig, 'S');

    if isempty(S.vehicles)
        S.fn.setStatus(mainFig, 'OR2：请先加载IV。');
        return;
    end

    % 若 OR2 窗口未打开，则打开
    if ~isfield(S, 'or2Fig') || isempty(S.or2Fig) || ~isvalid(S.or2Fig)
        do_open(mainFig);
        S = getappdata(mainFig, 'S');
    end

    idx = or2FindNearestVehicle(S, col, row);
    if idx < 1
        return;
    end

    items = or2MakeVehicleItems(S);
    S.or2.dropdown.Items = items;
    S.or2.dropdown.Value = items{idx};
    setappdata(mainFig, 'S', S);

    or2ShowLocal(mainFig);
end


%% ====================================================================
%   显示圆形局部地图（对应原 main.m 的 or2ShowLocal）
%% ====================================================================
function or2ShowLocal(fig)
    S = getappdata(fig, 'S');

    if isempty(S.vehicles)
        S.fn.setStatus(fig, 'OR2：没有IV，无法显示局部地图。');
        return;
    end

    if ~isfield(S, 'or2') || ~isfield(S.or2, 'previewAx') || ~isvalid(S.or2.previewAx)
        return;
    end

    idx = or2GetSelectedVehicleIndex(S);
    if idx < 1
        return;
    end

    radiusM = round(S.or2.radiusSlider.Value);
    radiusPx = radiusM / S.scale;

    cx = round(S.vehicles(idx).cx);
    cy = round(S.vehicles(idx).cy);

    % 使用当前主显示图作为底图，这样可以保留车辆、道路骨架等叠加结果
    S.fn.refresh(fig);
    S = getappdata(fig, 'S');
    baseMap = S.mapDisplay;
    if isempty(baseMap)
        baseMap = S.mapOrigin;
    end

    localMap = or2MakeCircularLocalMap(baseMap, cx, cy, radiusPx);

    imshow(localMap, 'Parent', S.or2.previewAx);
    axis(S.or2.previewAx, 'image');
    S.or2.previewAx.XTick = [];
    S.or2.previewAx.YTick = [];
    drawnow;

    % 更新 OR2 窗口标题显示当前参数
    if isfield(S, 'or2Fig') && isvalid(S.or2Fig)
        S.or2Fig.Name = sprintf('OR2 — IV #%d 半径%dm 缩放%dx', ...
            S.vehicles(idx).id, radiusM, round(S.vehicles(idx).dispScale));
    end

    S.fn.setStatus(fig, sprintf('OR2：显示IV #%d圆形局部地图，半径%d m。', ...
        S.vehicles(idx).id, radiusM));
end


%% ====================================================================
%   半径滑块变化（对应原 main.m 的 or2RadiusChanged）
%% ====================================================================
function or2RadiusChanged(fig, slider)
    S = getappdata(fig, 'S');

    val = round(slider.Value);
    slider.Value = val;

    if isfield(S, 'or2') && isfield(S.or2, 'radiusLabel') && isvalid(S.or2.radiusLabel)
        S.or2.radiusLabel.Text = sprintf('圆形局部地图半径：%d m', val);
        S.or2.radiusM = val;
        setappdata(fig, 'S', S);
    end

    or2ShowLocal(fig);
end


%% ====================================================================
%   缩放滑块变化（对应原 main.m 的 or2ScaleChanged）
%% ====================================================================
function or2ScaleChanged(fig, slider)
    S = getappdata(fig, 'S');

    if isempty(S.vehicles)
        return;
    end

    idx = or2GetSelectedVehicleIndex(S);
    if idx < 1
        return;
    end

    val = round(slider.Value);
    slider.Value = val;

    S.vehicles(idx).dispScale = val;

    if isfield(S, 'or2') && isfield(S.or2, 'scaleLabel') && isvalid(S.or2.scaleLabel)
        S.or2.scaleLabel.Text = sprintf('IV显示缩放倍数：%d', val);
    end

    setappdata(fig, 'S', S);

    or2ShowLocal(fig);
end


%% ====================================================================
%   车辆选择改变（对应原 main.m 的 or2VehicleChanged）
%% ====================================================================
function or2VehicleChanged(fig)
    S = getappdata(fig, 'S');

    idx = or2GetSelectedVehicleIndex(S);
    if idx < 1
        return;
    end

    scaleVal = round(S.vehicles(idx).dispScale);

    if isfield(S.or2, 'scaleSlider') && isvalid(S.or2.scaleSlider)
        S.or2.scaleSlider.Value = scaleVal;
    end

    if isfield(S.or2, 'scaleLabel') && isvalid(S.or2.scaleLabel)
        S.or2.scaleLabel.Text = sprintf('IV显示缩放倍数：%d', scaleVal);
    end

    setappdata(fig, 'S', S);

    or2ShowLocal(fig);
end


%% ====================================================================
%   恢复主地图（关闭 OR2 窗口，回到主地图）
%% ====================================================================
function or2Restore(fig)
    S = getappdata(fig, 'S');
    % 关闭 OR2 窗口，聚焦主地图
    if isfield(S, 'or2Fig') && ~isempty(S.or2Fig) && isvalid(S.or2Fig)
        delete(S.or2Fig);
    end
    S.or2Fig = [];
    if isfield(S, 'or2')
        S = rmfield(S, 'or2');
    end
    S.mode = 'idle';
    setappdata(fig, 'S', S);
    S.fn.refresh(fig);
    figure(fig);  % 聚焦主窗口
    S.fn.setStatus(fig, 'OR2 已关闭，回到主地图。');
end


%% ====================================================================
%   关闭窗口（对应原 main.m 的 or2Close）
%% ====================================================================
function or2Close(fig)
    S = getappdata(fig, 'S');

    if isfield(S, 'or2Fig') && ~isempty(S.or2Fig) && isvalid(S.or2Fig)
        delete(S.or2Fig);
    end

    if isfield(S, 'or2Fig')
        S.or2Fig = [];
    end

    if isfield(S, 'or2')
        S = rmfield(S, 'or2');
    end

    S.mode = 'idle';
    setappdata(fig, 'S', S);

    S.fn.setStatus(fig, 'OR2已关闭。');
end


%% ====================================================================
%   生成圆形局部地图（对应原 main.m 的 or2MakeCircularLocalMap）
%% ====================================================================
function localMap = or2MakeCircularLocalMap(baseMap, cx, cy, radiusPx)
    [H, W, ~] = size(baseMap);

    r1 = max(1, floor(cy - radiusPx));
    r2 = min(H, ceil(cy + radiusPx));
    c1 = max(1, floor(cx - radiusPx));
    c2 = min(W, ceil(cx + radiusPx));

    localH = r2 - r1 + 1;
    localW = c2 - c1 + 1;

    localMap = zeros(localH, localW, 3, 'uint8');

    R2 = radiusPx * radiusPx;
    borderThickness = 2;

    for rr = r1:r2
        for cc = c1:c2
            dx = cc - cx;
            dy = rr - cy;
            d2 = dx * dx + dy * dy;

            lr = rr - r1 + 1;
            lc = cc - c1 + 1;

            if d2 <= R2
                localMap(lr, lc, :) = baseMap(rr, cc, :);
            end

            % 红色圆形边界，便于肉眼确认确实是圆
            if abs(d2 - R2) <= 2 * radiusPx * borderThickness
                localMap(lr, lc, :) = uint8([255 0 0]);
            end
        end
    end

    % 黄色中心十字
    centerCol = cx - c1 + 1;
    centerRow = cy - r1 + 1;
    localMap = or2DrawCross(localMap, centerCol, centerRow, 6, uint8([255 255 0]));
end


%% ====================================================================
%   绘制十字标记（对应原 main.m 的 or2DrawCross）
%% ====================================================================
function img = or2DrawCross(img, col, row, radius, color)
    [H, W, ~] = size(img);

    col = round(col);
    row = round(row);

    for k = -radius:radius
        rr = row + k;
        cc = col;

        if rr >= 1 && rr <= H && cc >= 1 && cc <= W
            img(rr, cc, :) = color;
        end

        rr = row;
        cc = col + k;

        if rr >= 1 && rr <= H && cc >= 1 && cc <= W
            img(rr, cc, :) = color;
        end
    end
end


%% ====================================================================
%   生成车辆下拉列表项（对应原 main.m 的 or2MakeVehicleItems）
%% ====================================================================
function items = or2MakeVehicleItems(S)
    n = numel(S.vehicles);

    if n == 0
        items = {'(无IV，请先加载车辆)'};
        return;
    end

    items = cell(1, n);

    for i = 1:n
        v = S.vehicles(i);
        items{i} = sprintf('#%d (%.0f,%.0f)', v.id, v.cx, v.cy);
    end
end


%% ====================================================================
%   获取下拉选中的车辆索引（对应原 main.m 的 or2GetSelectedVehicleIndex）
%% ====================================================================
function idx = or2GetSelectedVehicleIndex(S)
    idx = -1;

    if isempty(S.vehicles)
        return;
    end

    if ~isfield(S, 'or2') || ~isfield(S.or2, 'dropdown') || ~isvalid(S.or2.dropdown)
        idx = 1;
        return;
    end

    val = S.or2.dropdown.Value;
    tok = regexp(val, '#(\d+)', 'tokens', 'once');

    if isempty(tok)
        idx = 1;
        return;
    end

    id = str2double(tok{1});

    for i = 1:numel(S.vehicles)
        if S.vehicles(i).id == id
            idx = i;
            return;
        end
    end

    idx = 1;
end


%% ====================================================================
%   查找最近车辆（对应原 main.m 的 or2FindNearestVehicle）
%% ====================================================================
function idx = or2FindNearestVehicle(S, col, row)
    idx = -1;

    if isempty(S.vehicles)
        return;
    end

    bestD = inf;

    for i = 1:numel(S.vehicles)
        dx = S.vehicles(i).cx - col;
        dy = S.vehicles(i).cy - row;
        d2 = dx * dx + dy * dy;

        if d2 < bestD
            bestD = d2;
            idx = i;
        end
    end
end
