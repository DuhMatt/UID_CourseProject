# Road Skeleton CV

Pure classical image processing for extracting a thin road skeleton from `MapForUI.jpg`.

## Files

```text
road_skeleton_cv/
  extract_road_skeleton.py
  README.md
  outputs/
```

## Dependencies

- `opencv-python`
- `numpy`
- `pillow`
- `scikit-image`

## Run

```bash
python3 extract_road_skeleton.py \
  --image "/Users/mattw/Library/CloudStorage/OneDrive2-Personal/For class/UID_Project/MapForUI.jpg" \
  --output "/Users/mattw/Library/CloudStorage/OneDrive2-Personal/For class/UID_Project/road_skeleton_cv/outputs" \
  --min-component-area 100 \
  --close-kernel 5 \
  --prune-length 20
```

## What it does

1. Loads the map and converts it to RGB, HSV, Lab, and grayscale.
2. Builds a road candidate mask from low-saturation bright regions while suppressing green, blue, and highly saturated decoration.
3. Cleans the mask with morphology plus connected-component filtering to remove blobs, buildings, and text-like noise.
4. Skeletonizes the cleaned mask, prunes short branches, and keeps the main road network plus valid boundary-connected segments.
5. Saves:
   - `01_road_candidate_mask.png`
   - `02_road_mask_cleaned.png`
   - `03_road_skeleton_1px.png`
   - `04_road_skeleton_visible.png`
   - `05_overlay_skeleton_on_map.png`

## Tuning

Adjust the constants near the top of `extract_road_skeleton.py` if the map style changes:

- HSV thresholds
- grayscale and Lab lightness cutoffs
- min/max component area
- morphology kernel sizes
- pruning length
- visible skeleton dilation
