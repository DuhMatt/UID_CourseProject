from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from skimage.filters import frangi, sato
from skimage.morphology import remove_small_holes, skeletonize


# Easy-to-tune defaults.
HSV_THRESHOLD_TRIPLETS = [
    (45, 190, 185),
    (55, 180, 175),
    (65, 170, 165),
]
GRAY_MIN_VALUES = [170, 190]
BEIGE_LOW_RGB = np.array([165, 160, 145], dtype=np.uint8)
BEIGE_HIGH_RGB = np.array([255, 245, 225], dtype=np.uint8)
KMEANS_CLUSTERS = 6
MIN_COMPONENT_AREA = 80
MAX_COMPONENT_AREA = 180000
MAX_COMPONENT_COMPACTNESS = 0.8
CLOSE_KERNEL_MIN = 3
CLOSE_KERNEL_MAX = 11
OPEN_KERNEL = 3
PRUNE_LENGTH = 25
ENDPOINT_CONNECT_DISTANCE = 14
VISIBLE_THICKNESS = 2
MAX_SKELETON_PIXELS_FOR_PRUNE = 20000
MAX_ENDPOINTS_FOR_CONNECTION = 250
MAX_ROAD_HALF_WIDTH = 9
BOUNDARY_TOUCH_BONUS = 250.0
ZERO_BOUNDARY_TOUCH_PENALTY = 5000.0
MIN_SKELETON_COMPONENT_SPAN = 70
MIN_SKELETON_COMPONENT_PIXELS = 35
ROADMASK_DILATE = 31
ROADMASK_SCORE_BONUS = 3.0
FINAL_PRUNE_LENGTH = 18
FINAL_KEEP_SPAN = 90
FINAL_KEEP_PIXELS = 55
GREEN_HUE_RANGE = (35, 95)
BLUE_HUE_RANGE = (90, 140)
HIGH_SAT_MIN = 150
VERY_DARK_MAX = 55
TOP_LEFT_CLUSTER = (0.0, 0.0, 0.33, 0.28)
TOP_RIGHT_CLUSTER = (0.67, 0.0, 1.0, 0.28)


@dataclass
class CandidateResult:
    idx: int
    source: str
    close_kernel: int
    mask: np.ndarray
    cleaned: np.ndarray
    skeleton: np.ndarray
    score: float
    stats: dict[str, float]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Multi-candidate automatic road skeleton extraction.")
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--roadmask", type=Path, default=Path("../RoadMask.jpg"))
    parser.add_argument("--min-component-area", type=int, default=MIN_COMPONENT_AREA)
    parser.add_argument("--close-kernel-min", type=int, default=CLOSE_KERNEL_MIN)
    parser.add_argument("--close-kernel-max", type=int, default=CLOSE_KERNEL_MAX)
    parser.add_argument("--prune-length", type=int, default=PRUNE_LENGTH)
    parser.add_argument("--top-k", type=int, default=5)
    parser.add_argument("--endpoint-connect-distance", type=int, default=ENDPOINT_CONNECT_DISTANCE)
    parser.add_argument("--visible-thickness", type=int, default=VISIBLE_THICKNESS)
    return parser.parse_args()


def save_mask(path: Path, mask: np.ndarray) -> None:
    Image.fromarray(mask).save(path)


def clear_output_dir(path: Path) -> None:
    for child in path.rglob("*"):
        if child.is_file():
            child.unlink()


def load_roadmask_prior(path: Path, shape: tuple[int, int]) -> tuple[np.ndarray, np.ndarray]:
    raw = np.array(Image.open(path).convert("L"))
    if raw.shape != shape:
        raw = cv2.resize(raw, (shape[1], shape[0]), interpolation=cv2.INTER_NEAREST)
    binary = (raw > 127).astype(np.uint8)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (ROADMASK_DILATE, ROADMASK_DILATE))
    corridor = cv2.dilate(binary, kernel, iterations=1)
    return binary, corridor


def build_exclusion_masks(hsv: np.ndarray, gray: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    h = hsv[:, :, 0]
    s = hsv[:, :, 1]
    green = (h >= GREEN_HUE_RANGE[0]) & (h <= GREEN_HUE_RANGE[1]) & (s >= 40)
    blue = (h >= BLUE_HUE_RANGE[0]) & (h <= BLUE_HUE_RANGE[1]) & (s >= 35)
    high_sat = s >= HIGH_SAT_MIN
    dark = gray <= VERY_DARK_MAX
    return green, blue, high_sat, dark


def build_base_candidates(rgb: np.ndarray, hsv: np.ndarray, lab: np.ndarray, gray: np.ndarray) -> list[tuple[str, np.ndarray]]:
    candidates: list[tuple[str, np.ndarray]] = []
    h = hsv[:, :, 0]
    s = hsv[:, :, 1]
    v = hsv[:, :, 2]
    l = lab[:, :, 0]
    green, blue, high_sat, dark = build_exclusion_masks(hsv, gray)
    exclusion = green | blue | high_sat | dark

    for s_max, v_min, l_min in HSV_THRESHOLD_TRIPLETS:
        mask = (s <= s_max) & (v >= v_min) & (l >= l_min) & ~exclusion
        candidates.append((f"hsv_s{s_max}_v{v_min}_l{l_min}", mask))

    for gray_min in GRAY_MIN_VALUES:
        light_gray = gray >= gray_min
        low_sat = s <= 95
        beige = np.all(rgb >= BEIGE_LOW_RGB, axis=2) & np.all(rgb <= BEIGE_HIGH_RGB, axis=2)
        mask = (light_gray & low_sat & ~exclusion) | (beige & ~exclusion)
        candidates.append((f"gray_{gray_min}_beige", mask))

    edges = cv2.Canny(gray, 50, 150)
    edges = cv2.dilate(edges, np.ones((3, 3), np.uint8), iterations=1) > 0
    bright = (v >= 165) & (s <= 100)
    candidates.append(("canny_bright", edges & bright & ~exclusion))

    frangi_img = frangi(gray.astype(np.float32) / 255.0, sigmas=range(1, 4), black_ridges=False)
    sato_img = sato(gray.astype(np.float32) / 255.0, sigmas=range(1, 4), black_ridges=False)
    for name, resp in [("frangi", frangi_img), ("sato", sato_img)]:
        resp = np.nan_to_num(resp, nan=0.0, posinf=0.0, neginf=0.0)
        if resp.max() > 0:
            norm = resp / resp.max()
            for q in [88, 93]:
                thr = np.percentile(norm, q)
                mask = (norm >= thr) & (v >= 130) & ~exclusion
                candidates.append((f"{name}_q{q}", mask))

    for kernel_size in [9, 17]:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kernel_size, kernel_size))
        tophat = cv2.morphologyEx(gray, cv2.MORPH_TOPHAT, kernel)
        blackhat = cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, kernel)
        candidates.append((f"tophat_{kernel_size}", (tophat >= np.percentile(tophat, 92)) & ~exclusion))
        candidates.append((f"blackhat_{kernel_size}", (blackhat <= np.percentile(blackhat, 20)) & (v >= 150) & (s <= 110) & ~exclusion))

    pixels = lab.reshape(-1, 3).astype(np.float32)
    _, labels, centers = cv2.kmeans(
        pixels,
        KMEANS_CLUSTERS,
        None,
        (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.2),
        3,
        cv2.KMEANS_PP_CENTERS,
    )
    labels = labels.reshape(gray.shape)
    centers = centers.astype(np.float32)
    for idx, center in enumerate(centers):
        l_val, a_val, b_val = center
        if l_val >= 150 and abs(a_val - 128) < 14 and abs(b_val - 128) < 22:
            mask = (labels == idx) & ~exclusion
            candidates.append((f"kmeans_{idx}", mask))

    return candidates


def component_compactness(contour: np.ndarray, area: float) -> float:
    perimeter = cv2.arcLength(contour, True)
    if perimeter <= 0:
        return 0.0
    return float(4.0 * np.pi * area / (perimeter * perimeter))


def filter_components(mask: np.ndarray, min_area: int) -> tuple[np.ndarray, float, float]:
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    kept = np.zeros_like(mask)
    compact_blob_area = 0.0
    small_component_penalty = 0.0
    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        if area < min_area:
            small_component_penalty += area
            continue
        if area > MAX_COMPONENT_AREA:
            compact_blob_area += area
            continue
        comp = np.zeros_like(mask)
        comp[labels == label] = 255
        contours, _ = cv2.findContours(comp, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        contour = contours[0] if contours else None
        compactness = component_compactness(contour, area) if contour is not None else 0.0
        fill_ratio = area / max(w * h, 1)
        aspect = max(w, h) / max(min(w, h), 1)
        if fill_ratio > 0.7 and compactness > MAX_COMPONENT_COMPACTNESS and aspect < 3.5:
            compact_blob_area += area
            continue
        if area < min_area * 2 and max(w, h) < 18:
            small_component_penalty += area
            continue
        kept[labels == label] = 255
    return kept, compact_blob_area, small_component_penalty


def connect_close_endpoints(binary: np.ndarray, max_dist: int) -> np.ndarray:
    binary = binary.copy().astype(np.uint8)
    neighbors = count_neighbors(binary)
    endpoints = np.argwhere((binary == 1) & (neighbors == 1))
    if len(endpoints) < 2 or len(endpoints) > MAX_ENDPOINTS_FOR_CONNECTION:
        return binary
    used: set[int] = set()
    for i, p0 in enumerate(endpoints):
        if i in used:
            continue
        best_j = None
        best_dist = float("inf")
        for j in range(i + 1, len(endpoints)):
            if j in used:
                continue
            p1 = endpoints[j]
            dist = float(np.hypot(*(p0 - p1)))
            if dist < best_dist and dist <= max_dist:
                best_dist = dist
                best_j = j
        if best_j is not None:
            y0, x0 = endpoints[i]
            y1, x1 = endpoints[best_j]
            cv2.line(binary, (int(x0), int(y0)), (int(x1), int(y1)), 1, 1)
            used.add(i)
            used.add(best_j)
    return binary


def count_neighbors(binary: np.ndarray) -> np.ndarray:
    kernel = np.array([[1, 1, 1], [1, 10, 1], [1, 1, 1]], dtype=np.uint8)
    conv = cv2.filter2D(binary.astype(np.uint8), -1, kernel, borderType=cv2.BORDER_CONSTANT)
    return conv - 10 * binary.astype(np.uint8)


def prune_skeleton(binary: np.ndarray, prune_length: int) -> np.ndarray:
    binary = binary.astype(np.uint8).copy()
    for _ in range(10):
        neighbors = count_neighbors(binary)
        endpoints = np.argwhere((binary == 1) & (neighbors == 1))
        removed = False
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
                removed = True
        if not removed:
            break
    return binary


def filter_skeleton_components(binary: np.ndarray) -> np.ndarray:
    binary = binary.astype(np.uint8)
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    kept = np.zeros_like(binary)
    h, w = binary.shape
    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        ys, xs = np.where(labels == label)
        if ys.size == 0:
            continue
        span = max(xs.max() - xs.min(), ys.max() - ys.min())
        touches_boundary = np.any((ys == 0) | (ys == h - 1) | (xs == 0) | (xs == w - 1))
        if touches_boundary or span >= MIN_SKELETON_COMPONENT_SPAN or area >= MIN_SKELETON_COMPONENT_PIXELS * 3:
            kept[labels == label] = 1
    return kept


def final_refine_skeleton(binary: np.ndarray, roadmask_prior: np.ndarray | None) -> np.ndarray:
    binary = binary.astype(np.uint8)
    binary = prune_skeleton(binary, FINAL_PRUNE_LENGTH)
    if roadmask_prior is not None:
        support = cv2.dilate(roadmask_prior.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)), iterations=1)
        binary = (binary & support).astype(np.uint8)

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    kept = np.zeros_like(binary)
    h, w = binary.shape
    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        ys, xs = np.where(labels == label)
        if ys.size == 0:
            continue
        span = max(xs.max() - xs.min(), ys.max() - ys.min())
        touches_boundary = np.any((ys == 0) | (ys == h - 1) | (xs == 0) | (xs == w - 1))
        if touches_boundary or span >= FINAL_KEEP_SPAN or area >= FINAL_KEEP_PIXELS:
            kept[labels == label] = 1
    return kept


def cluster_penalty(binary: np.ndarray, region: tuple[float, float, float, float]) -> float:
    h, w = binary.shape
    x0 = int(region[0] * w)
    y0 = int(region[1] * h)
    x1 = int(region[2] * w)
    y1 = int(region[3] * h)
    roi = binary[y0:y1, x0:x1]
    return float(roi.sum())


def skeleton_stats(binary: np.ndarray) -> dict[str, float]:
    binary = binary.astype(np.uint8)
    total_len = float(binary.sum())
    neighbors = count_neighbors(binary)
    endpoints = float(np.sum((binary == 1) & (neighbors == 1)))
    junctions = float(np.sum((binary == 1) & (neighbors >= 3)))
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    comp_areas = stats[1:, cv2.CC_STAT_AREA] if num_labels > 1 else np.array([], dtype=np.int32)
    main_len = float(comp_areas.max()) if comp_areas.size else 0.0
    isolated_count = float(np.sum(comp_areas < 25)) if comp_areas.size else 0.0
    small_count = float(np.sum(comp_areas < 80)) if comp_areas.size else 0.0
    boundary_touch = 0.0
    span_score = 0.0
    boundary_len = 0.0
    for label in range(1, num_labels):
        ys, xs = np.where(labels == label)
        if ys.size == 0:
            continue
        touches_boundary = np.any((ys == 0) | (ys == binary.shape[0] - 1) | (xs == 0) | (xs == binary.shape[1] - 1))
        if touches_boundary:
            boundary_touch += 1.0
            boundary_len += float(len(xs))
        span_score += max(xs.max() - xs.min(), ys.max() - ys.min())
    compactness_proxy = float(binary.sum() / max(num_labels - 1, 1))
    return {
        "total_len": total_len,
        "main_len": main_len,
        "junctions": junctions,
        "endpoints": endpoints,
        "isolated_count": isolated_count,
        "small_count": small_count,
        "boundary_touch": boundary_touch,
        "boundary_len": boundary_len,
        "span_score": span_score,
        "compactness_proxy": compactness_proxy,
    }


def score_candidate(skeleton: np.ndarray, compact_blob_area: float, small_component_penalty: float, roadmask_prior: np.ndarray | None) -> tuple[float, dict[str, float]]:
    stats = skeleton_stats(skeleton)
    dense_building_penalty = cluster_penalty(skeleton, TOP_LEFT_CLUSTER) + cluster_penalty(skeleton, TOP_RIGHT_CLUSTER)
    interior_len = max(stats["total_len"] - stats["boundary_len"], 0.0)
    junction_density_penalty = (stats["junctions"] / max(stats["total_len"], 1.0)) * 20000.0
    zero_boundary_penalty = ZERO_BOUNDARY_TOUCH_PENALTY if stats["boundary_touch"] == 0 else 0.0
    prior_overlap = 0.0
    if roadmask_prior is not None:
        prior_overlap = float(np.sum((skeleton > 0) & (roadmask_prior > 0)))
    score = (
        stats["boundary_len"] * 2.0
        + stats["main_len"] * 3.2
        + stats["boundary_touch"] * BOUNDARY_TOUCH_BONUS
        + stats["span_score"] * 1.2
        + stats["total_len"] * 0.35
        + prior_overlap * ROADMASK_SCORE_BONUS
        - interior_len * 0.2
        - junction_density_penalty
        - stats["isolated_count"] * 80.0
        - stats["small_count"] * 55.0
        - compact_blob_area * 0.12
        - small_component_penalty * 0.5
        - dense_building_penalty * 0.8
        - zero_boundary_penalty
    )
    stats["compact_blob_area"] = compact_blob_area
    stats["small_component_penalty"] = small_component_penalty
    stats["dense_building_penalty"] = dense_building_penalty
    stats["interior_len"] = interior_len
    stats["junction_density_penalty"] = junction_density_penalty
    stats["zero_boundary_penalty"] = zero_boundary_penalty
    stats["prior_overlap"] = prior_overlap
    return float(score), stats


def clean_candidate(mask: np.ndarray, close_kernel: int, min_area: int, prune_length: int, endpoint_connect_distance: int, roadmask_corridor: np.ndarray | None) -> tuple[np.ndarray, np.ndarray, float, float]:
    mask_u8 = (mask.astype(np.uint8) * 255)
    if roadmask_corridor is not None:
        mask_u8 = cv2.bitwise_and(mask_u8, mask_u8, mask=(roadmask_corridor > 0).astype(np.uint8))
    open_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (OPEN_KERNEL, OPEN_KERNEL))
    close_elem = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (close_kernel, close_kernel))
    cleaned = cv2.morphologyEx(mask_u8, cv2.MORPH_OPEN, open_kernel, iterations=1)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, close_elem, iterations=1)
    cleaned = remove_small_holes(cleaned > 0, area_threshold=min_area * 3, connectivity=2)
    cleaned = (cleaned.astype(np.uint8) * 255)
    cleaned, compact_blob_area, small_component_penalty = filter_components(cleaned, min_area)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, close_elem, iterations=1)
    distance = cv2.distanceTransform((cleaned > 0).astype(np.uint8), cv2.DIST_L2, 5)
    skeleton = skeletonize(cleaned > 0).astype(np.uint8)
    skeleton = (skeleton & (distance <= MAX_ROAD_HALF_WIDTH)).astype(np.uint8)
    if int(skeleton.sum()) <= MAX_SKELETON_PIXELS_FOR_PRUNE:
        skeleton = connect_close_endpoints(skeleton, endpoint_connect_distance)
        skeleton = prune_skeleton(skeleton, prune_length)
    skeleton = filter_components((skeleton * 255).astype(np.uint8), max(10, min_area // 2))[0]
    skeleton = (skeleton > 0).astype(np.uint8)
    skeleton = filter_skeleton_components(skeleton)
    return cleaned, skeleton, compact_blob_area, small_component_penalty


def overlay_on_map(rgb: np.ndarray, skeleton_mask: np.ndarray) -> np.ndarray:
    overlay = rgb.copy()
    overlay[skeleton_mask > 0] = np.array([255, 0, 0], dtype=np.uint8)
    return overlay


def write_scores_csv(path: Path, results: list[CandidateResult]) -> None:
    fieldnames = ["idx", "source", "close_kernel", "score"] + sorted(results[0].stats.keys()) if results else ["idx", "source", "close_kernel", "score"]
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            out = {"idx": row.idx, "source": row.source, "close_kernel": row.close_kernel, "score": row.score}
            out.update(row.stats)
            writer.writerow(out)


def main() -> None:
    args = parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    candidates_dir = args.output / "candidates"
    top_dir = args.output / "top_candidates"
    candidates_dir.mkdir(parents=True, exist_ok=True)
    top_dir.mkdir(parents=True, exist_ok=True)
    clear_output_dir(args.output)
    candidates_dir.mkdir(parents=True, exist_ok=True)
    top_dir.mkdir(parents=True, exist_ok=True)

    bgr = cv2.imread(str(args.image), cv2.IMREAD_COLOR)
    if bgr is None:
        raise FileNotFoundError(f"could not read image: {args.image}")
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    roadmask_prior = None
    roadmask_corridor = None
    if args.roadmask.exists():
        roadmask_prior, roadmask_corridor = load_roadmask_prior(args.roadmask, gray.shape)
        save_mask(args.output / "00_roadmask_prior.png", (roadmask_prior * 255).astype(np.uint8))
        save_mask(args.output / "00_roadmask_corridor.png", (roadmask_corridor * 255).astype(np.uint8))

    base_candidates = build_base_candidates(rgb, hsv, lab, gray)
    close_values = list(range(args.close_kernel_min, args.close_kernel_max + 1, 2))
    results: list[CandidateResult] = []

    idx = 0
    for source, mask in base_candidates:
        save_mask(candidates_dir / f"candidate_{idx:03d}.png", mask.astype(np.uint8) * 255)
        for close_kernel in close_values:
            cleaned, skeleton, compact_blob_area, small_component_penalty = clean_candidate(
                mask,
                close_kernel,
                args.min_component_area,
                args.prune_length,
                args.endpoint_connect_distance,
                roadmask_corridor,
            )
            score, stats = score_candidate(skeleton, compact_blob_area, small_component_penalty, roadmask_prior)
            results.append(
                CandidateResult(
                    idx=idx,
                    source=source,
                    close_kernel=close_kernel,
                    mask=(mask.astype(np.uint8) * 255),
                    cleaned=cleaned,
                    skeleton=(skeleton * 255).astype(np.uint8),
                    score=score,
                    stats=stats,
                )
            )
        idx += 1

    results.sort(key=lambda x: x.score, reverse=True)
    write_scores_csv(args.output / "candidate_scores.csv", results)

    for rank, result in enumerate(results[: args.top_k], start=1):
        save_mask(top_dir / f"top_{rank}_mask.png", result.cleaned)
        save_mask(top_dir / f"top_{rank}_skeleton.png", result.skeleton)
        Image.fromarray(overlay_on_map(rgb, result.skeleton > 0)).save(top_dir / f"top_{rank}_overlay.png")

    best = results[0]
    final_skeleton = final_refine_skeleton((best.skeleton > 0).astype(np.uint8), roadmask_prior)
    final_skeleton_u8 = (final_skeleton * 255).astype(np.uint8)
    basic_mask = cv2.dilate(final_skeleton_u8, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)), iterations=1)

    save_mask(args.output / "01_best_road_candidate_mask.png", best.mask)
    save_mask(args.output / "02_best_cleaned_mask.png", best.cleaned)
    save_mask(args.output / "03_road_skeleton_1px.png", final_skeleton_u8)
    save_mask(args.output / "06_basic_road_mask.png", basic_mask)

    if args.visible_thickness > 1:
        vis_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (args.visible_thickness, args.visible_thickness))
        visible = cv2.dilate(final_skeleton_u8, vis_kernel, iterations=1)
    else:
        visible = final_skeleton_u8.copy()
    save_mask(args.output / "04_road_skeleton_visible.png", visible)
    Image.fromarray(overlay_on_map(rgb, visible > 0)).save(args.output / "05_overlay_skeleton_on_map.png")
    print(f"saved {len(base_candidates)} candidates and best outputs to {args.output}")


if __name__ == "__main__":
    main()
