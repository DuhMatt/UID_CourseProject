% test_zoom_rotate_viewport_headup.m
% 覆盖 Fix 2:refreshDisplay 的 headUpMode 分支要把 viewCenter 同步到旋转后位置

fprintf('===== test_zoom_rotate_viewport_headup =====\n');
fig = main();
S = getappdata(fig, 'S');

%% 准备:加载一辆车在地图上
% 用 smoke_test 的技巧找一个道路点
maskGray = mean(double(S.basicRoadMask), 3);
[roadRow, roadCol] = ind2sub(size(maskGray), find(maskGray>160,1));
S.vehicles(end+1).id=1; S.vehicles(end).cx=roadCol; S.vehicles(end).cy=roadRow;
S.vehicles(end).angle=45; S.vehicles(end).dispScale=3; S.nextIVid=2;
setappdata(fig,'S',S);
S.handles.ivDropdown.Items = {sprintf('#1 (%d,%d)',roadCol,roadRow)};
S.handles.ivDropdown.Value = S.handles.ivDropdown.Items{1};

%% 1. 关掉 headUp,旋转 0°,记录基线
S.handles.chkHeadUp.Value = false;
S.handles.chkHeadUp.ValueChangedFcn(S.handles.chkHeadUp, []);
S = getappdata(fig, 'S');
S.handles.rotSlider.Value = 0;
S.handles.rotSlider.ValueChangedFcn(S.handles.rotSlider, []);
S = getappdata(fig, 'S');
baseDispW = S.dispW; baseDispH = S.dispH;
fprintf('[baseline] rotDeg=0, dispW=%d, dispH=%d, viewCenter=[%.1f %.1f]\n', ...
    baseDispW, baseDispH, S.viewCenter);

%% 2. 打开 headUp,验证 viewCenter 被设置
S.handles.chkHeadUp.Value = true;
S.handles.chkHeadUp.ValueChangedFcn(S.handles.chkHeadUp, []);
S = getappdata(fig, 'S');
assert(S.headUpMode, 'FAIL: headUpMode not on');
assert(~isempty(S.viewCenter), 'FAIL: viewCenter empty after headUp on');
[dH, dW, ~] = size(S.mapDisplay);
% viewCenter 应在 [0.5, dW+0.5] x [0.5, dH+0.5] 范围内(旋转后新画布内)
assert(S.viewCenter(1) >= 0.5 && S.viewCenter(1) <= dW + 0.5, ...
    sprintf('FAIL: headUp viewCenter col=%.1f not in [0.5 %.1f]', S.viewCenter(1), dW+0.5));
assert(S.viewCenter(2) >= 0.5 && S.viewCenter(2) <= dH + 0.5, ...
    sprintf('FAIL: headUp viewCenter row=%.1f not in [0.5 %.1f]', S.viewCenter(2), dH+0.5));
% XLim/YLim 应当用满新画布(因为 z=1, viewCenter 是新画布内的点)
xlimHu = S.ax.XLim; ylimHu = S.ax.YLim;
fprintf('[headUp] dispW=%d, dispH=%d, viewCenter=[%.1f %.1f], XLim=[%.1f %.1f], YLim=[%.1f %.1f]\n', ...
    dW, dH, S.viewCenter, xlimHu, ylimHu);
% z=1 时,halfW = dW/2,所以 xlim 中心 = viewCenter(1),宽度 = dW
xlimWidth = xlimHu(2) - xlimHu(1);
ylimWidth = ylimHu(2) - ylimHu(1);
assert(abs(xlimWidth - dW) < 2, sprintf('FAIL: headUp XLim width %.1f != dW %d', xlimWidth, dW));
assert(abs(ylimWidth - dH) < 2, sprintf('FAIL: headUp YLim width %.1f != dH %d', ylimWidth, dH));
fprintf('[OK] headUp: XLim/YLim 宽度 = 新画布宽高(用满)\n');

%% 3. 关掉 headUp,viewCenter 应回退到普通旋转/默认
S.handles.chkHeadUp.Value = false;
S.handles.chkHeadUp.ValueChangedFcn(S.handles.chkHeadUp, []);
S = getappdata(fig, 'S');
assert(~S.headUpMode, 'FAIL: headUpMode not off');
% 关掉后:refreshDisplay 走 elseif S.rotDeg ~= 0 分支(若 rotDeg 还是 0,走 else)
% 因为我们没旋转,所以走 else,viewCenter 应该被设为 [] 或保持
fprintf('[headUp off] rotDeg=%d, viewCenter=[%.1f %.1f], dispW=%d\n', ...
    S.rotDeg, S.viewCenter, S.dispW);
fprintf('[OK] headUp 关闭后无崩溃\n');

close(fig);
fprintf('\n===== test_zoom_rotate_viewport_headup PASSED =====\n');
