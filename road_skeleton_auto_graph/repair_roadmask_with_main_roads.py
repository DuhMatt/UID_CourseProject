from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


THRESHOLD = 127
MIN_COMPONENT_AREA = 60
MIN_ADD_SPAN = 120
MIN_ADD_AREA = 120
ROAD_LIKE_S_MAX = 95
ROAD_LIKE_V_MIN = 150
ROAD_LIKE_L_MIN = 145
PRIOR_CORRIDOR_DILATE = 61
MAIN_ROAD_CLOSE = 9
FINAL_CLOSE = 7


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repair RoadMask.jpg by adding likely missing main-road segments.")
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--mask", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def save_mask(path: Path, array: np.ndarray) -> None:
    Image.fromarray(array).save(path)


def remove_small(mask: np.ndarray, min_area: int) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    out = np.zeros_like(mask)
    for label in range(1, num_labels):
        if stats[label, cv2.CC_STAT_AREA] >= min_area:
            out[labels == label] = 255
    return out


def build_map_road_like(image_path: Path, shape: tuple[int, int]) -> np.ndarray:
    rgb = np.array(Image.open(image_path).convert("RGB"))
    if rgb.shape[:2] != shape:
        rgb = cv2.resize(rgb, (shape[1], shape[0]), interpolation=cv2.INTER_LINEAR)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)

    s = hsv[:, :, 1]
    v = hsv[:, :, 2]
    l = lab[:, :, 0]
    h = hsv[:, :, 0]

    green = ((h >= 35) & (h <= 95) & (s >= 40))
    blue = ((h >= 90) & (h <= 140) & (s >= 35))
    dark = gray < 70

    road = (s <= ROAD_LIKE_S_MAX) & (v >= ROAD_LIKE_V_MIN) & (l >= ROAD_LIKE_L_MIN) & ~green & ~blue & ~dark
    road = road.astype(np.uint8) * 255
    road = cv2.morphologyEx(
        road,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (MAIN_ROAD_CLOSE, MAIN_ROAD_CLOSE)),
        iterations=1,
    )
    return road


def select_main_road_additions(add_candidates: np.ndarray) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(add_candidates, connectivity=8)
    kept = np.zeros_like(add_candidates)
    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        ys, xs = np.where(labels == label)
        if ys.size == 0:
            continue
        span = max(xs.max() - xs.min(), ys.max() - ys.min())
        if area >= MIN_ADD_AREA and span >= MIN_ADD_SPAN:
            kept[labels == label] = 255
    return kept


def main() -> None:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    mask = np.array(Image.open(args.mask).convert("L"))
    binary = np.where(mask > THRESHOLD, 255, 0).astype(np.uint8)
    cleaned = cv2.morphologyEx(
        binary,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (FINAL_CLOSE, FINAL_CLOSE)),
        iterations=1,
    )
    cleaned = remove_small(cleaned, MIN_COMPONENT_AREA)

    corridor = cv2.dilate(
        (cleaned > 0).astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (PRIOR_CORRIDOR_DILATE, PRIOR_CORRIDOR_DILATE)),
        iterations=1,
    )

    road_like = build_map_road_like(args.image, cleaned.shape)
    guided = cv2.bitwise_and(road_like, road_like, mask=corridor)
    additions = cv2.bitwise_and(guided, cv2.bitwise_not(cleaned))
    additions = remove_small(additions, MIN_COMPONENT_AREA)
    additions = select_main_road_additions(additions)

    repaired = cv2.bitwise_or(cleaned, additions)
    repaired = cv2.morphologyEx(
        repaired,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (FINAL_CLOSE, FINAL_CLOSE)),
        iterations=1,
    )

    save_mask(args.output / "10_repair_guided_candidates.png", guided)
    save_mask(args.output / "11_repair_additions.png", additions)
    save_mask(args.output / "12_repaired_roadmask.png", repaired)
    print(f"saved repaired roadmask outputs to {args.output}")


if __name__ == "__main__":
    main()
