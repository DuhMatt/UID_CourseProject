from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from skimage.morphology import skeletonize


# Easy-to-tune defaults.
HSV_S_MAX = 70
HSV_V_MIN = 150
LAB_L_MIN = 155
GRAY_MIN = 150
GREEN_HUE_RANGE = (35, 95)
BLUE_HUE_RANGE = (90, 140)
HIGH_SAT_MIN = 150
MIN_COMPONENT_AREA = 100
MAX_COMPONENT_AREA = 150000
CLOSE_KERNEL = 5
OPEN_KERNEL = 3
DILATE_KERNEL = 3
PRUNE_LENGTH = 20
FINAL_SKELETON_DILATION = 2
RECT_FILL_RATIO = 0.72
COMPACTNESS_MIN = 0.45


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract a thin road skeleton from a stylized campus map.")
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--min-component-area", type=int, default=MIN_COMPONENT_AREA)
    parser.add_argument("--max-component-area", type=int, default=MAX_COMPONENT_AREA)
    parser.add_argument("--close-kernel", type=int, default=CLOSE_KERNEL)
    parser.add_argument("--open-kernel", type=int, default=OPEN_KERNEL)
    parser.add_argument("--dilate-kernel", type=int, default=DILATE_KERNEL)
    parser.add_argument("--prune-length", type=int, default=PRUNE_LENGTH)
    parser.add_argument("--final-skeleton-dilation", type=int, default=FINAL_SKELETON_DILATION)
    return parser.parse_args()


def save_mask(path: Path, mask: np.ndarray) -> None:
    Image.fromarray(mask).save(path)


def keep_reasonable_components(mask: np.ndarray, min_area: int, max_area: int) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    kept = np.zeros_like(mask)
    for label in range(1, num_labels):
        area = stats[label, cv2.CC_STAT_AREA]
        if area < min_area or area > max_area:
            continue
        comp = (labels == label).astype(np.uint8)
        ys, xs = np.where(comp > 0)
        if ys.size == 0:
            continue
        x0, x1 = xs.min(), xs.max()
        y0, y1 = ys.min(), ys.max()
        w = x1 - x0 + 1
        h = y1 - y0 + 1
        bbox_area = w * h
        fill_ratio = area / max(bbox_area, 1)
        perimeter = cv2.arcLength(np.column_stack([xs, ys]).reshape(-1, 1, 2).astype(np.int32), False)
        compactness = 4.0 * np.pi * area / max(perimeter * perimeter, 1.0)
        aspect = max(w, h) / max(min(w, h), 1)

        # ponytail: coarse blob rules are enough here; tune thresholds before adding shape models.
        if fill_ratio > RECT_FILL_RATIO and compactness > COMPACTNESS_MIN and aspect < 4.0:
            continue

        kept[labels == label] = 255
    return kept


def remove_text_like_components(mask: np.ndarray) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    kept = np.zeros_like(mask)
    for label in range(1, num_labels):
        area = stats[label, cv2.CC_STAT_AREA]
        x = stats[label, cv2.CC_STAT_LEFT]
        y = stats[label, cv2.CC_STAT_TOP]
        w = stats[label, cv2.CC_STAT_WIDTH]
        h = stats[label, cv2.CC_STAT_HEIGHT]
        aspect = max(w, h) / max(min(w, h), 1)
        if area < 30 and max(w, h) < 18:
            continue
        if area < 90 and aspect > 6:
            continue
        kept[labels == label] = 255
    return kept


def count_neighbors(binary: np.ndarray) -> np.ndarray:
    kernel = np.array([[1, 1, 1], [1, 10, 1], [1, 1, 1]], dtype=np.uint8)
    conv = cv2.filter2D(binary.astype(np.uint8), -1, kernel, borderType=cv2.BORDER_CONSTANT)
    return conv - 10 * binary.astype(np.uint8)


def prune_skeleton(binary: np.ndarray, prune_length: int) -> np.ndarray:
    binary = binary.astype(np.uint8).copy()
    for _ in range(8):
        neighbors = count_neighbors(binary)
        endpoints = np.argwhere((binary == 1) & (neighbors == 1))
        removed_any = False
        for y0, x0 in endpoints:
            path = [(y0, x0)]
            prev = None
            current = (y0, x0)
            while True:
                y, x = current
                neigh = []
                for yy in range(max(0, y - 1), min(binary.shape[0], y + 2)):
                    for xx in range(max(0, x - 1), min(binary.shape[1], x + 2)):
                        if (yy, xx) == current or binary[yy, xx] == 0:
                            continue
                        if prev is not None and (yy, xx) == prev:
                            continue
                        neigh.append((yy, xx))
                if len(neigh) != 1:
                    break
                prev = current
                current = neigh[0]
                path.append(current)
                if len(path) > prune_length:
                    break
            if len(path) <= prune_length:
                for y, x in path[:-1]:
                    binary[y, x] = 0
                removed_any = True
        if not removed_any:
            break
    return binary


def keep_main_and_boundary_segments(binary: np.ndarray) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary.astype(np.uint8), connectivity=8)
    if num_labels <= 1:
        return (binary * 255).astype(np.uint8)
    largest = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    kept = np.zeros_like(binary, dtype=np.uint8)
    h, w = binary.shape
    for label in range(1, num_labels):
        comp = labels == label
        if label == largest:
            kept[comp] = 1
            continue
        ys, xs = np.where(comp)
        if ys.size == 0:
            continue
        touches_border = np.any((ys == 0) | (ys == h - 1) | (xs == 0) | (xs == w - 1))
        if touches_border or stats[label, cv2.CC_STAT_AREA] >= 80:
            kept[comp] = 1
    return (kept * 255).astype(np.uint8)


def build_candidate_mask(rgb: np.ndarray, hsv: np.ndarray, lab: np.ndarray, gray: np.ndarray) -> np.ndarray:
    h = hsv[:, :, 0]
    s = hsv[:, :, 1]
    v = hsv[:, :, 2]
    l = lab[:, :, 0]

    bright_low_sat = (s <= HSV_S_MAX) & (v >= HSV_V_MIN)
    light_lab = l >= LAB_L_MIN
    light_gray = gray >= GRAY_MIN

    road_like = bright_low_sat & (light_lab | light_gray)

    green = (h >= GREEN_HUE_RANGE[0]) & (h <= GREEN_HUE_RANGE[1]) & (s >= 40)
    blue = (h >= BLUE_HUE_RANGE[0]) & (h <= BLUE_HUE_RANGE[1]) & (s >= 40)
    high_sat = s >= HIGH_SAT_MIN

    edges = cv2.Canny(gray, 50, 140)
    linear_hint = cv2.dilate(edges, np.ones((3, 3), np.uint8), iterations=1) > 0

    candidate = (road_like & ~green & ~blue & ~high_sat) | (bright_low_sat & linear_hint & ~green & ~blue)
    return candidate.astype(np.uint8) * 255


def main() -> None:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    bgr = cv2.imread(str(args.image), cv2.IMREAD_COLOR)
    if bgr is None:
        raise FileNotFoundError(f"could not read image: {args.image}")
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)

    candidate = build_candidate_mask(rgb, hsv, lab, gray)
    save_mask(args.output / "01_road_candidate_mask.png", candidate)

    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (args.close_kernel, args.close_kernel))
    open_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (args.open_kernel, args.open_kernel))
    dilate_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (args.dilate_kernel, args.dilate_kernel))

    cleaned = cv2.morphologyEx(candidate, cv2.MORPH_CLOSE, close_kernel, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, open_kernel, iterations=1)
    cleaned = cv2.dilate(cleaned, dilate_kernel, iterations=1)
    cleaned = keep_reasonable_components(cleaned, args.min_component_area, args.max_component_area)
    cleaned = remove_text_like_components(cleaned)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, close_kernel, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, open_kernel, iterations=1)
    save_mask(args.output / "02_road_mask_cleaned.png", cleaned)

    skeleton = skeletonize(cleaned > 0).astype(np.uint8)
    skeleton = prune_skeleton(skeleton, args.prune_length)
    skeleton = keep_main_and_boundary_segments(skeleton)
    save_mask(args.output / "03_road_skeleton_1px.png", skeleton)

    if args.final_skeleton_dilation > 1:
        vis_kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE,
            (args.final_skeleton_dilation, args.final_skeleton_dilation),
        )
        visible = cv2.dilate(skeleton, vis_kernel, iterations=1)
    else:
        visible = skeleton.copy()
    save_mask(args.output / "04_road_skeleton_visible.png", visible)

    overlay = rgb.copy()
    overlay[visible > 0] = np.array([255, 0, 0], dtype=np.uint8)
    Image.fromarray(overlay).save(args.output / "05_overlay_skeleton_on_map.png")
    print(f"saved outputs to {args.output}")


if __name__ == "__main__":
    main()
