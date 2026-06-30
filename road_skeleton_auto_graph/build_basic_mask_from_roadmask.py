from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from skimage.morphology import skeletonize


THRESHOLD = 127
MIN_AREA = 80
CLOSE_KERNEL = 7
OPEN_KERNEL = 3
BASIC_MASK_DILATE = 5
MAP_ROAD_S_MAX = 85
MAP_ROAD_V_MIN = 155
MAP_ROAD_L_MIN = 150
PRIOR_CORRIDOR_DILATE = 41
ENDPOINT_BRIDGE_DIST = 90
ENDPOINT_SEARCH_RADIUS = 14


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a usable basic road mask from RoadMask.jpg.")
    parser.add_argument("--mask", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--min-area", type=int, default=MIN_AREA)
    return parser.parse_args()


def save_mask(path: Path, array: np.ndarray) -> None:
    Image.fromarray(array).save(path)


def remove_small_components(mask: np.ndarray, min_area: int) -> np.ndarray:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    kept = np.zeros_like(mask)
    for label in range(1, num_labels):
        if stats[label, cv2.CC_STAT_AREA] >= min_area:
            kept[labels == label] = 255
    return kept


def count_neighbors(binary: np.ndarray) -> np.ndarray:
    kernel = np.array([[1, 1, 1], [1, 10, 1], [1, 1, 1]], dtype=np.uint8)
    conv = cv2.filter2D(binary.astype(np.uint8), -1, kernel, borderType=cv2.BORDER_CONSTANT)
    return conv - 10 * binary.astype(np.uint8)


def get_endpoints(binary: np.ndarray) -> np.ndarray:
    neighbors = count_neighbors(binary)
    return np.argwhere((binary == 1) & (neighbors == 1))


def build_map_candidate(image_path: Path, shape: tuple[int, int]) -> np.ndarray:
    rgb = np.array(Image.open(image_path).convert("RGB"))
    if rgb.shape[:2] != shape:
        rgb = cv2.resize(rgb, (shape[1], shape[0]), interpolation=cv2.INTER_LINEAR)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    s = hsv[:, :, 1]
    v = hsv[:, :, 2]
    l = lab[:, :, 0]
    road_like = (s <= MAP_ROAD_S_MAX) & (v >= MAP_ROAD_V_MIN) & (l >= MAP_ROAD_L_MIN) & (gray >= 145)
    return road_like.astype(np.uint8)


def bridge_endpoints(skeleton: np.ndarray, candidate: np.ndarray) -> np.ndarray:
    out = skeleton.copy().astype(np.uint8)
    endpoints = get_endpoints(out)
    if len(endpoints) < 2:
        return out
    used: set[int] = set()
    for i, p0 in enumerate(endpoints):
        if i in used:
            continue
        y0, x0 = p0
        best_j = None
        best_dist = float("inf")
        for j in range(i + 1, len(endpoints)):
            if j in used:
                continue
            y1, x1 = endpoints[j]
            dist = float(np.hypot(y0 - y1, x0 - x1))
            if dist > ENDPOINT_BRIDGE_DIST or dist >= best_dist:
                continue
            line = np.zeros_like(out)
            cv2.line(line, (int(x0), int(y0)), (int(x1), int(y1)), 1, 1)
            samples = np.sum(candidate[line > 0])
            support_ratio = samples / max(np.sum(line > 0), 1)
            if support_ratio < 0.55:
                continue
            best_dist = dist
            best_j = j
        if best_j is not None:
            y1, x1 = endpoints[best_j]
            cv2.line(out, (int(x0), int(y0)), (int(x1), int(y1)), 1, 1)
            used.add(i)
            used.add(best_j)
    return out


def main() -> None:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    gray = np.array(Image.open(args.mask).convert("L"))
    binary = np.where(gray > THRESHOLD, 255, 0).astype(np.uint8)
    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (CLOSE_KERNEL, CLOSE_KERNEL))
    open_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (OPEN_KERNEL, OPEN_KERNEL))

    cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, close_kernel, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_OPEN, open_kernel, iterations=1)
    cleaned = remove_small_components(cleaned, args.min_area)

    prior_corridor = cv2.dilate((cleaned > 0).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (PRIOR_CORRIDOR_DILATE, PRIOR_CORRIDOR_DILATE)), iterations=1)
    map_candidate = build_map_candidate(args.image, gray.shape)
    guided_candidate = (map_candidate & (prior_corridor > 0)).astype(np.uint8)

    skeleton_binary = skeletonize(cleaned > 0).astype(np.uint8)
    skeleton_binary = bridge_endpoints(skeleton_binary, guided_candidate)
    skeleton = skeleton_binary * 255
    basic_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (BASIC_MASK_DILATE, BASIC_MASK_DILATE))
    basic_mask = cv2.dilate(skeleton, basic_kernel, iterations=1)

    save_mask(args.output / "07_roadmask_cleaned.png", cleaned)
    save_mask(args.output / "07b_map_guided_candidate.png", (guided_candidate * 255).astype(np.uint8))
    save_mask(args.output / "08_roadmask_skeleton_1px.png", skeleton)
    save_mask(args.output / "09_basic_road_mask_from_roadmask.png", basic_mask)
    print(f"saved roadmask-based outputs to {args.output}")


if __name__ == "__main__":
    main()
