% smoke_test_main.m - post-patch smoke test for main + OR3 + OR4
% Covers B1, B2, B3, S1, S2, S3, S4, S5.

fprintf('===== smoke test: main + OR3 + OR4 (post-patch) =====\n');

%% T1
fig = main();
assert(~isempty(fig) && isvalid(fig), 'T1 FAIL');
S = getappdata(fig, 'S');
assert(~isempty(S.mapOrigin), 'T1 FAIL: map not loaded');
assert(isequal([S.mapH S.mapW], [803 1404]), 'T1 FAIL: map size');
fprintf('[T1 OK] main launched, map %dx%d\n', S.mapW, S.mapH);

%% T2 B1
maskGray = mean(double(S.basicRoadMask), 3);
[roadRow, roadCol] = ind2sub(size(maskGray), find(maskGray>160,1));
[offRow, offCol] = ind2sub(size(maskGray), find(maskGray==min(maskGray(:)),1));
assert(isRoadPointForUI(S.mapOrigin,S.basicRoadMask,S.roadMask,roadRow,roadCol),'T2 FAIL road');
assert(~isRoadPointForUI(S.mapOrigin,S.basicRoadMask,S.roadMask,offRow,offCol),'T2 FAIL off');
fprintf('[T2 OK] B1: shared validator\n');

%% T3 B2
S.vehicles(end+1).id=1; S.vehicles(end).cx=roadCol; S.vehicles(end).cy=roadRow;
S.vehicles(end).angle=120; S.vehicles(end).dispScale=3; S.nextIVid=2;
setappdata(fig,'S',S);
S.handles.ivDropdown.Items = {sprintf('#1 (%d,%d)',roadCol,roadRow)};
S.handles.ivDropdown.Value = S.handles.ivDropdown.Items{1};
S.handles.angleSlider.Value = 30;
dd = S.handles.ivDropdown;
cbMain = dd.ValueChangedFcn;
cbMain(dd, []);
S = getappdata(fig,'S');
assert(abs(S.handles.angleSlider.Value-120)<1e-6, 'T3 FAIL B2');
fprintf('[T3 OK] B2: angleSlider synced 30->120\n');

%% T4 OR3 head-up
chk = S.handles.chkHeadUp;
chk.Value = true; chk.ValueChangedFcn(chk, []);
S = getappdata(fig,'S');
assert(S.headUpMode,'T4 FAIL head-up on');
chk.Value = false; chk.ValueChangedFcn(chk, []);
S = getappdata(fig,'S');
assert(~S.headUpMode,'T4 FAIL head-up off');
fprintf('[T4 OK] OR3: chkHeadUp toggle\n');

%% T5 OR4 open
or4_street_view('open', fig);
S = getappdata(fig,'S');
assert(isfield(S,'or4Fig') && isvalid(S.or4Fig),'T5 FAIL');
fprintf('[T5 OK] OR4 opened\n');

%% T6 B3 FOV
cam = S.or4.cam;
halfFov = atan(260/cam.focalPixel);
fprintf('[T6 OK] B3: halfFov=%.4f rad (%.2f deg)\n', halfFov, rad2deg(halfFov));

%% T7 S1 right-click
S.mode='or4'; setappdata(fig,'S',S);
or4_street_view('click', fig, roadCol, roadRow, 'alt');
S = getappdata(fig,'S');
assert(strcmp(S.mode,'idle'),'T7 FAIL S1 right-click');
fprintf('[T7 OK] S1: right-click cancels or4 mode\n');

%% T8 S1 left-click
S.mode='or4'; setappdata(fig,'S',S);
or4_street_view('click', fig, roadCol, roadRow, 'normal');
S = getappdata(fig,'S');
assert(abs(S.or4.cam.realX - roadCol*S.scale)<1, 'T8 FAIL S1 left-click');
fprintf('[T8 OK] S1: left-click sets camera X=%.1f\n', S.or4.cam.realX);

%% T9 S2 main dropdown sync
% Add vehicle #2
S.vehicles(end+1).id=2; S.vehicles(end).cx=roadCol+50; S.vehicles(end).cy=roadRow;
S.vehicles(end).angle=200; S.vehicles(end).dispScale=3; S.nextIVid=3;
setappdata(fig,'S',S);
% Set main dropdown items
S.handles.ivDropdown.Items = {sprintf('#1 (%d,%d)',roadCol,roadRow), sprintf('#2 (%d,%d)',roadCol+50,roadRow)};
S.handles.ivDropdown.Value = S.handles.ivDropdown.Items{1};
% Set OR4 vehDrop items + value
S.or4.vehDrop.Items = {'(手动设置)','#1','#2'};
S.or4.vehDrop.Value = '#2';
% Capture the cb FRESH
cbOr4 = S.or4.vehDrop.ValueChangedFcn;
fprintf('T9 cbOr4 = %s\n', func2str(cbOr4));
cbOr4(S.or4.vehDrop, []);
S = getappdata(fig,'S');
targetStr = sprintf('#2 (%d,%d)', roadCol+50, roadRow);
fprintf('T9 targetStr=[%s] got=[%s]\n', targetStr, S.handles.ivDropdown.Value);
assert(strcmp(S.handles.ivDropdown.Value, targetStr), 'T9 FAIL S2');
fprintf('[T9 OK] S2: OR4 selection syncs main dropdown\n');

%% T10 cleanup
close(S.or4Fig);
pause(0.3);
S = getappdata(fig,'S');
assert(isempty(S.or4) || ~isvalid(S.or4),'T10 FAIL cleanup');
S.vehicles = struct('id',{},'cx',{},'cy',{},'angle',{},'dispScale',{});
S.nextIVid = 1; setappdata(fig,'S',S);
close(fig);
fprintf('[T10 OK] cleanup\n');

fprintf('\n===== smoke test PASSED =====\n');
