% test_zoom_rotate_viewport.m
% 回归:验证"缩放/旋转后,显示区域用满整个新画布,不再遵从原图区域"
%
% 用 matlab -batch 跑:matlab -batch "run('test_zoom_rotate_viewport.m')"
% 通过条件:全部 assert 通过 + 退出码 0

fprintf('===== test_zoom_rotate_viewport =====\n');
fig = main();
S = getappdata(fig, 'S');
assert(~isempty(S.mapOrigin), 'pre: map not loaded');
assert(isequal([S.mapH S.mapW], [803 1404]), 'pre: map size');

%% T1: z=1 启动时,XLim/YLim = 整张原图
xlim0 = S.ax.XLim;
ylim0 = S.ax.YLim;
assert(abs(xlim0(1) - 0.5) < 1e-6 && abs(xlim0(2) - (S.mapW + 0.5)) < 1e-6, ...
    sprintf('T1 FAIL: initial XLim=[%.1f %.1f], want [0.5 %.1f]', xlim0(1), xlim0(2), S.mapW+0.5));
assert(abs(ylim0(1) - 0.5) < 1e-6 && abs(ylim0(2) - (S.mapH + 0.5)) < 1e-6, ...
    sprintf('T1 FAIL: initial YLim=[%.1f %.1f], want [0.5 %.1f]', ylim0(1), ylim0(2), S.mapH+0.5));
fprintf('[T1 OK] initial XLim=[%.1f %.1f], YLim=[%.1f %.1f]\n', xlim0, ylim0);

%% T2: z=1 旋转 45°,XLim/YLim 应覆盖完整新画布(不再被自动 bump 到 1.25 缩窗)
rot = S.handles.rotSlider;
rot.ValueChangedFcn(rot, []);   % 触发 0° 路径(初始 0)
S = getappdata(fig, 'S');
% 直接设值并触发回调
rot.Value = 45;
rot.ValueChangedFcn(rot, []);
S = getappdata(fig, 'S');
assert(abs(S.rotDeg - 45) < 1e-6, 'T2 FAIL: rotDeg not 45');
[dH, dW, ~] = size(S.mapDisplay);
xlim2 = S.ax.XLim;
ylim2 = S.ax.YLim;
xlimWidth = xlim2(2) - xlim2(1);
ylimWidth = ylim2(2) - ylim2(1);
ratioX = xlimWidth / dW;
ratioY = ylimWidth / dH;
% 期望 z=1(未 bump):窗口宽度 = 整图宽度
fprintf('[T2] z=1 旋 45°: 新图 %dx%d, XLim=[%.1f %.1f](宽 %.1f, 占比 %.3f), YLim=[%.1f %.1f](宽 %.1f, 占比 %.3f)\n', ...
    dW, dH, xlim2, xlimWidth, ratioX, ylim2, ylimWidth, ratioY);
assert(ratioX > 0.95, sprintf('T2 FAIL: XLim covers only %.1f%% of new canvas', ratioX*100));
assert(ratioY > 0.95, sprintf('T2 FAIL: YLim covers only %.1f%% of new canvas', ratioY*100));
% z 标签也应是 1.0x,不应被自动 bump
assert(abs(S.userZoom - 1) < 1e-6, sprintf('T2 FAIL: viewZoom=%.2f, expected 1.0', S.userZoom));
fprintf('[T2 OK] z=1 旋 45° 后窗口用满新画布(无自动 bump)\n');

%% T3: z=2 + 旋转 90°,XLim/YLim 应为 1/2 新画布宽度(缩放仍然工作)
zoom = S.handles.zoomSlider;
zoom.Value = 1;
zoom.ValueChangedFcn(zoom, []);
S = getappdata(fig, 'S');
zoom.Value = 2;
zoom.ValueChangedFcn(zoom, []);
S = getappdata(fig, 'S');
rot.Value = 90;
rot.ValueChangedFcn(rot, []);
S = getappdata(fig, 'S');
[dH, dW, ~] = size(S.mapDisplay);
xlim3 = S.ax.XLim;
ylim3 = S.ax.YLim;
xlimWidth = xlim3(2) - xlim3(1);
ylimWidth = ylim3(2) - ylim3(1);
expectedHalfW = dW / 2;
expectedHalfH = dH / 2;
fprintf('[T3] z=2 旋 90°: 新图 %dx%d, XLim=[%.1f %.1f](宽 %.1f, 期望 ~%.1f), YLim=[%.1f %.1f](宽 %.1f, 期望 ~%.1f)\n', ...
    dW, dH, xlim3, xlimWidth, expectedHalfW, ylim3, ylimWidth, expectedHalfH);
assert(abs(xlimWidth - expectedHalfW) < 2, sprintf('T3 FAIL: XLim 宽 %.1f, 期望 ~%.1f', xlimWidth, expectedHalfW));
assert(abs(ylimWidth - expectedHalfH) < 2, sprintf('T3 FAIL: YLim 宽 %.1f, 期望 ~%.1f', ylimWidth, expectedHalfH));
fprintf('[T3 OK] z=2 旋 90° 后 XLim/YLim 宽度 ≈ 1/2 新画布\n');

%% T4: 重置视图后,XLim/YLim 等于当前显示图尺寸(1x 缩放、center=图中心)
% T3 末尾是 rotDeg=90,所以当前显示图是 803x1404(原图旋转 90°)。
% reset 只重置 zoom/viewCenter,不重置 rotDeg。
resetBtn = S.handles.btnResetView;
resetBtn.ButtonPushedFcn(resetBtn, []);
S = getappdata(fig, 'S');
xlim4 = S.ax.XLim;
ylim4 = S.ax.YLim;
assert(abs(S.userZoom - 1) < 1e-6, 'T4 FAIL: viewZoom not reset');
assert(abs(xlim4(1) - 0.5) < 1e-6 && abs(xlim4(2) - (S.dispW + 0.5)) < 1e-6, ...
    sprintf('T4 FAIL: XLim=[%.1f %.1f], want [0.5 %.1f]', xlim4(1), xlim4(2), S.dispW+0.5));
assert(abs(ylim4(1) - 0.5) < 1e-6 && abs(ylim4(2) - (S.dispH + 0.5)) < 1e-6, ...
    sprintf('T4 FAIL: YLim=[%.1f %.1f], want [0.5 %.1f]', ylim4(1), ylim4(2), S.dispH+0.5));
fprintf('[T4 OK] 重置视图后 XLim=[%.1f %.1f], YLim=[%.1f %.1f](用满当前 %dx%d 画布)\n', ...
    xlim4, ylim4, S.dispW, S.dispH);

%% T5: 旋转关闭后,viewCenter 跟 rotCX/rotCY 联动(复用 verify_view_center_rotation 的逻辑)
rot.Value = 0;
rot.ValueChangedFcn(rot, []);
S = getappdata(fig, 'S');
zoom.Value = 2;
zoom.ValueChangedFcn(zoom, []);
S = getappdata(fig, 'S');
target = [1000.5, 600.5];
S.userZoom = 2;
S.viewCenter = target;
setappdata(fig, 'S', S);
set(S.ax, ...
    'XLim', [target(1) - S.dispW / 4, target(1) + S.dispW / 4], ...
    'YLim', [target(2) - S.dispH / 4, target(2) + S.dispH / 4]);
rot.Value = 45;
rot.ValueChangedFcn(rot, []);
S = getappdata(fig, 'S');
th = S.rotDeg * pi / 180;
c = cos(th); s = sin(th);
corners = [0.5 0.5; S.mapW + 0.5 0.5; S.mapW + 0.5 S.mapH + 0.5; 0.5 S.mapH + 0.5];
centered = corners - [S.rotCX S.rotCY];
rotCorners = [ ...
    centered(:,1) * c - centered(:,2) * s + S.rotCX, ...
    centered(:,1) * s + centered(:,2) * c + S.rotCY];
shiftCol = min(rotCorners(:,1));
shiftRow = min(rotCorners(:,2));
expected = [S.rotCX - shiftCol + 1, S.rotCY - shiftRow + 1];
fprintf('[T5] rotCenter=[%.1f %.1f], viewCenter=[%.1f %.1f], expected=[%.1f %.1f]\n', ...
    S.rotCX, S.rotCY, S.viewCenter, expected);
assert(norm([S.rotCX S.rotCY] - target) < 1.5, 'T5 FAIL: rotation anchor did not track current view center');
assert(norm(S.viewCenter - expected) < 1.5, 'T5 FAIL: view center did not stay on rotated anchor');
fprintf('[T5 OK] viewCenter 在旋转后正确跟踪锚点\n');

%% 清理
resetBtn.ButtonPushedFcn(resetBtn, []);
close(fig);
fprintf('\n===== test_zoom_rotate_viewport PASSED =====\n');
