# Road Skeleton Auto Graph

This version replaces the previous single-threshold CV attempt with a multi-candidate automatic search.

## Why the previous simple threshold failed

The old pipeline depended too much on one bright low-saturation rule. On this stylized campus map, roads, roofs, labels, and some building interiors can all look light and low-saturation, so the mask drifted into building blocks.

## New idea

Instead of trusting one threshold, the script generates many different road candidates from:

- HSV low-saturation bright masks
- Lab lightness masks
- gray and beige road-like masks
- Canny-assisted bright linear masks
- Frangi and Sato line-enhanced masks
- top-hat and black-hat morphology masks
- k-means color clustering in Lab space

Each candidate is cleaned, skeletonized, and scored by road-network properties. The best road-like graph wins automatically.

## Outputs

- `outputs/candidates/candidate_000.png`, ...: raw candidate masks for debugging
- `outputs/candidate_scores.csv`: score table for every candidate/cleanup combination
- `outputs/top_candidates/`: top-k cleaned masks, skeletons, and overlays
- `outputs/01_best_road_candidate_mask.png`: best raw candidate mask
- `outputs/02_best_cleaned_mask.png`: best cleaned road mask
- `outputs/03_road_skeleton_1px.png`: best thin skeleton
- `outputs/04_road_skeleton_visible.png`: slightly dilated visible skeleton
- `outputs/05_overlay_skeleton_on_map.png`: skeleton overlay on the original map

## Run

```bash
python3 extract_auto_graph_skeleton.py \
  --image "/Users/mattw/Library/CloudStorage/OneDrive2-Personal/For class/UID_Project/MapForUI.jpg" \
  --output "/Users/mattw/Library/CloudStorage/OneDrive2-Personal/For class/UID_Project/road_skeleton_auto_graph/outputs" \
  --min-component-area 80 \
  --close-kernel-min 3 \
  --close-kernel-max 11 \
  --prune-length 25 \
  --top-k 5
```

## Tuning

If buildings are still detected:

- lower `HSV_S_MAX_VALUES`
- raise `HSV_V_MIN_VALUES` or `LAB_L_MIN_VALUES`
- raise `MIN_COMPONENT_AREA`
- lower `MAX_COMPONENT_COMPACTNESS`
- raise the dense-building penalties near `score_candidate`

If roads are missing:

- add looser values to `HSV_S_MAX_VALUES`, `HSV_V_MIN_VALUES`, `LAB_L_MIN_VALUES`, or `GRAY_MIN_VALUES`
- increase `CLOSE_KERNEL_MAX`
- increase `ENDPOINT_CONNECT_DISTANCE`
- reduce `PRUNE_LENGTH`

## Dependencies

- `opencv-python`
- `numpy`
- `pillow`
- `scikit-image`

No manual annotation, no `RoadMask.jpg`, no deep learning, no downloaded datasets.
