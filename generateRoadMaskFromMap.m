function mask = generateRoadMaskFromMap(mapPath, roughMaskPath, outPath)
%GENERATEROADMASKFROMMAP  Clean the hand-drawn road mask into a binary image.

    rootDir = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(mapPath), mapPath = fullfile(rootDir, 'MapForUI.jpg'); end
    if nargin < 2 || isempty(roughMaskPath), roughMaskPath = fullfile(rootDir, 'RoadMask.jpg'); end
    if nargin < 3 || isempty(outPath), outPath = fullfile(rootDir, 'RoadMask_Optimized.png'); end

    mapImage = imread(mapPath);
    [mapH, mapW, ~] = size(mapImage);

    assert(isfile(roughMaskPath), 'RoadMask.jpg not found.');
    roughMask = imread(roughMaskPath);
    assert(size(roughMask, 1) == mapH && size(roughMask, 2) == mapW, ...
        'Road mask size must match map size.');

    mask = mean(double(roughMask), 3) > 160;
    % ponytail: clean only the user's drawn roads; no map color scan, so buildings stay out.
    mask = cleanMask(mask);

    assert(any(mask(:)), 'Generated road mask is empty.');
    assert(~all(mask(:)), 'Generated road mask covers the whole map.');
    imwrite(uint8(mask) * 255, outPath);
end

function mask = cleanMask(mask)
    n = conv2(double(mask), ones(3), 'same');
    mask = (mask & n >= 2) | n >= 7;
end
