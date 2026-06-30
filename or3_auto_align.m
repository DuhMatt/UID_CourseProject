function varargout = or3_auto_align(action, mainFig, varargin)
%OR3_AUTO_ALIGN  OR3 车辆加载时自动对齐方向 + 车头朝上显示模式
%
%  核心函数（由 main.m 内部调用）：
%    angle = or3_auto_align('findAngle', mainFig, col, row)
%        返回 (col,row) 处最近道路的方向角（度），用于自动对齐。
%
%        优先使用 OR1 骨架边（精确）；若骨架不可用，分析 basicRoadMask
%        中该点附近道路像素的主方向。
%
%    out = or3_auto_align('rotateAround', img, cx, cy, deg)
%        绕任意点 (cx,cy) 旋转图像 img（手搓反向映射），用于车头朝上模式。

    switch action
        case 'open'
            or3_open(mainFig);
        case 'headUpToggled'
            or3_headUpToggled(mainFig, varargin{1});
        case 'headUpParams'
            [varargout{1}, varargout{2}, varargout{3}] = or3_getHeadUpParams(mainFig);
        case 'alignCurrent'
            or3_alignCurrent(mainFig);
        case 'findAngle'
            varargout{1} = findNearestRoadAngle(mainFig, varargin{1}, varargin{2});
        case 'rotateAround'
            varargout{1} = rotateMapAroundPoint(mainFig, varargin{1}, varargin{2}, varargin{3});
    end
end


%% ====================================================================
%   findNearestRoadAngle
%   返回 (col, row) 处道路的走向角（度，Matlab atan2d 约定）
%% ====================================================================
function angle = findNearestRoadAngle(fig, col, row)
    S = getappdata(fig, 'S');
    angle = 0;  % 默认 0°（水平向右）

    % ---- 方法 1：使用 OR1 骨架边 ----
    hasSkeleton = ~isempty(S.sk.nodes) && size(S.sk.nodes,1) >= 2 ...
               && ~isempty(S.sk.edges) && size(S.sk.edges,1) >= 1;
    if hasSkeleton
        bestDist = inf;
        bestAngle = 0;
        P = [col, row];
        for i = 1:size(S.sk.edges, 1)
            ni = S.sk.edges(i, 1);
            nj = S.sk.edges(i, 2);
            A = S.sk.nodes(ni, :);
            B = S.sk.nodes(nj, :);
            d = ptToSeg(P, A, B);
            if d < bestDist
                bestDist = d;
                % 方向：沿边的方向角
                dx = B(1) - A(1);
                dy = B(2) - A(2);
                if dx == 0 && dy == 0
                    bestAngle = 0;
                else
                    bestAngle = atan2d(dy, dx);
                end
            end
        end
        angle = bestAngle;
        return;
    end

    % ---- 方法 2：分析 basicRoadMask 中该点附近的道路像素主方向 ----
    mask = S.basicRoadMask;
    if isempty(mask), return; end
    [mH, mW, mC] = size(mask);
    scanR = 15;   % 扫描半径（像素）
    pts = [];     % 收集的附近道路像素坐标
    for dr = -scanR:scanR
        for dc = -scanR:scanR
            rr = round(row) + dr;
            cc = round(col) + dc;
            if rr < 1 || rr > mH || cc < 1 || cc > mW, continue; end
            if mC == 3
                v = (double(mask(rr,cc,1)) + double(mask(rr,cc,2)) + double(mask(rr,cc,3))) / 3;
            else
                v = double(mask(rr,cc));
            end
            if v > 160   % 白色像素 = 道路
                pts(end+1, :) = [cc, rr];   %#ok<AGROW>
            end
        end
    end
    if size(pts, 1) < 5, return; end

    % 居中后做简化 PCA（协方差矩阵主方向）
    cx0 = mean(pts(:,1));
    cy0 = mean(pts(:,2));
    dx  = pts(:,1) - cx0;
    dy  = pts(:,2) - cy0;
    Cxx = mean(dx .* dx);
    Cxy = mean(dx .* dy);
    Cyy = mean(dy .* dy);

    % 协方差矩阵最大特征值对应的特征向量方向
    theta = 0.5 * atan2(2 * Cxy, Cxx - Cyy);   % 主方向角（弧度）
    angle = rad2deg(theta);
end


%% ====================================================================
%   rotateMapAroundPoint
%   绕任意点 (cx,cy) 旋转图像（手搓反向映射，最近邻采样）
%% ====================================================================
function out = rotateMapAroundPoint(img, cx, cy, deg)
    [H, W, ~] = size(img);
    th = deg * pi / 180;
    c  = cos(th);
    s  = sin(th);

    % 1. 计算旋转后画布尺寸（绕 (cx,cy) 旋转四个角点）
    corners    = [0.5 0.5; W + 0.5 0.5; W + 0.5 H + 0.5; 0.5 H + 0.5];
    % 先平移到以 (cx,cy) 为原点，旋转，再平移回来
    centered    = corners - [cx cy];           % Nx2，以 (cx,cy) 为原点
    rotCentered = centered * [c -s; s c]';     % 旋转（注意转置：等同于 centered * R(θ)）
    rotCorners  = rotCentered + [cx cy];
    newW = ceil(max(rotCorners(:,1)) - min(rotCorners(:,1)));
    newH = ceil(max(rotCorners(:,2)) - min(rotCorners(:,2)));
    out  = uint8(255 * ones(newH, newW, 3));

    % 2. 新画布原点在旋转后空间中的偏移量
    shiftCol = min(rotCorners(:,1));
    shiftRow = min(rotCorners(:,2));

    % 3. 向量化反向映射
    [rowGrid, colGrid] = ndgrid(1:newH, 1:newW);
    % 新画布像素 (cc,rr) 在旋转后空间中的坐标
    rotX = shiftCol + colGrid(:) - 1;
    rotY = shiftRow + rowGrid(:) - 1;
    % 相对旋转中心的偏移（旋转后空间）
    xRot = rotX - cx;
    yRot = rotY - cy;
    % 反旋转回到原图空间（绕旋转中心）
    xOld =  xRot*c + yRot*s + cx;     % xRot*c + yRot*s = R(-θ)*[xRot;yRot] 的 x 分量
    yOld = -xRot*s + yRot*c + cy;
    rOld = round(yOld);
    cOld = round(xOld);

    valid = rOld>=1 & rOld<=H & cOld>=1 & cOld<=W;
    idx   = find(valid);
    for ch = 1:3
        tmp  = out(:,:,ch);
        tmp2 = img(:,:,ch);
        tmp(idx) = tmp2(rOld(idx) + (cOld(idx)-1)*H);
        out(:,:,ch) = tmp;
    end
end


%% ====================================================================
%   辅助：点到线段距离
%% ====================================================================
function d = ptToSeg(P, A, B)
    AB = B - A;
    AP = P - A;
    ab2 = dot(AB, AB);
    if ab2 == 0
        d = norm(P - A);
        return;
    end
    t = max(0, min(1, dot(AP, AB) / ab2));
    d = norm(P - (A + t * AB));
end


%% ====================================================================
%   or3_open — 打开 OR3 车辆朝向工具弹窗
%% ====================================================================
function or3_open(mainFig)
    S = getappdata(mainFig, 'S');
    if isfield(S, 'or3Fig') && ~isempty(S.or3Fig) && isvalid(S.or3Fig)
        figure(S.or3Fig);
        return;
    end
    or3Fig = uifigure('Name', 'OR3 车辆朝向工具', ...
                      'Position', [160 160 300 260], ...
                      'Resize', 'off', ...
                      'WindowStyle', 'alwaysontop');
    setappdata(or3Fig, 'mainFig', mainFig);

    gl = uigridlayout(or3Fig, [7 1]);
    gl.RowHeight = repmat({'fit'}, 7, 1);
    gl.ColumnWidth = {'1x'};

    r = 0;
    function c = addC(type, rowIdx, varargin)
        c = feval(['ui' type], gl, varargin{:});
        c.Layout.Row = rowIdx; c.Layout.Column = 1;
    end

    r = r + 1;
    addC('label', r, 'Text', 'OR3 车辆朝向工具', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    r = r + 1;
    addC('label', r, 'Text', '──── 功能说明 ────', 'FontSize', 11, 'FontWeight', 'bold');
    r = r + 1;
    addC('label', r, 'Text', '自动对齐：加载车辆时自动与道路走向对齐。', ...
         'FontSize', 9, 'WordWrap', 'on');
    r = r + 1;
    addC('label', r, 'Text', '车头朝上：地图围绕选定车辆旋转，使车头始终指向上方。', ...
         'FontSize', 9, 'WordWrap', 'on');
    r = r + 1;
    addC('label', r, 'Text', '──── 操作 ────', 'FontSize', 11, 'FontWeight', 'bold');
    r = r + 1;
    addC('button', r, 'Text', '对齐到道路（当前车辆）', ...
         'ButtonPushedFcn', @(~,~) or3_auto_align('alignCurrent', mainFig));
    r = r + 1;
    addC('button', r, 'Text', '关闭', ...
         'ButtonPushedFcn', @(~,~) close(or3Fig));

    S = getappdata(mainFig, 'S');
    S.or3Fig = or3Fig;
    setappdata(mainFig, 'S', S);
    set(or3Fig, 'CloseRequestFcn', @(~,~) close(or3Fig));
end


%% ====================================================================
%   or3_alignCurrent — 将当前选中车辆对齐到最近道路方向
%% ====================================================================
function or3_alignCurrent(mainFig)
    S = getappdata(mainFig, 'S');
    if isempty(S.vehicles)
        uialert(mainFig, '当前没有已加载的车辆。', '提示');
        return;
    end
    sel = S.handles.ivDropdown.Value;
    tok = regexp(sel, '#(\d+)', 'tokens', 'once');
    if isempty(tok)
        uialert(mainFig, '请先在下拉列表中选中一辆车辆。', '提示');
        return;
    end
    vid = str2double(tok{1});
    idx = find(arrayfun(@(v) v.id==vid, S.vehicles), 1);
    if isempty(idx), return; end
    newAngle = or3_auto_align('findAngle', mainFig, S.vehicles(idx).cx, S.vehicles(idx).cy);
    S.vehicles(idx).angle = newAngle;
    if S.headUpMode
        S.headUpAngle = newAngle;
    end
    setappdata(mainFig, 'S', S);
    S.fn.refresh(mainFig);
    if isfield(S.handles,'angleSlider') && isvalid(S.handles.angleSlider)
        S.handles.angleSlider.Value = newAngle;
    end
    S.fn.setStatus(mainFig, sprintf('车辆 #%d 朝向已对齐至 %.1f°', vid, newAngle));
end


%% ====================================================================
%   or3_headUpToggled — 切换车头朝上显示模式
%% ====================================================================
function or3_headUpToggled(mainFig, src)
    S = getappdata(mainFig, 'S');
    S.headUpMode = src.Value;
    if S.headUpMode
        if ~isempty(S.vehicles) && isfield(S.handles,'ivDropdown') && isvalid(S.handles.ivDropdown)
            sel = S.handles.ivDropdown.Value;
            tok = regexp(sel, '#(\d+)', 'tokens', 'once');
            if ~isempty(tok)
                vid = str2double(tok{1});
                idx = find(arrayfun(@(v) v.id==vid, S.vehicles), 1);
                if ~isempty(idx)
                    S.headUpAngle = S.vehicles(idx).angle;
                end
            end
        end
        S.fn.setStatus(mainFig, '车头朝上模式已启用：地图将围绕选定车辆旋转。');
    else
        S.fn.setStatus(mainFig, '车头朝上模式已关闭。');
    end
    setappdata(mainFig, 'S', S);
    S.fn.refresh(mainFig);
end


%% ====================================================================
%   or3_getHeadUpParams — 返回 [angle, cx, cy] 供车头朝上旋转
%% ====================================================================
function [angle, cx, cy] = or3_getHeadUpParams(mainFig)
    S = getappdata(mainFig, 'S');
    angle = S.headUpAngle;
    cx = S.mapW / 2;
    cy = S.mapH / 2;
    if ~isempty(S.vehicles) && isfield(S.handles,'ivDropdown') && isvalid(S.handles.ivDropdown)
        sel = S.handles.ivDropdown.Value;
        tok = regexp(sel, '#(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            vid = str2double(tok{1});
            idx = find(arrayfun(@(v) v.id==vid, S.vehicles), 1);
            if ~isempty(idx)
                angle = S.vehicles(idx).angle;
                cx    = S.vehicles(idx).cx;
                cy    = S.vehicles(idx).cy;
            end
        end
    end
end
