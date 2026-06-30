# REQUIREMENTS LOCK

Do not change these behaviors during refactor.

## Hard requirements

1. Only Matlab.
2. Main script must boot the UI.
3. After running the main script, all relevant operations must be done via UI only.
4. Minimum usage of built-in functions: basic math, basic image I/O such as `imread`/`imshow`, and Matlab UI controls are allowed; other high-level built-ins should not be introduced.

## Basic UI requirements

1. Load and visualize map.
2. Click map point and display real-world coordinates.
3. Load one or multiple IVs.
4. Provide UI operation to initiate loading a new IV.
5. Load IV by clicking map point.
6. Check whether loaded point is on navigable road.
7. Show error message for invalid loaded point.
8. Visualize newly added IV and existing IVs.
9. Adjustable IV orientation.
10. Remove one IV without affecting other IVs.
11. Re-visualize map after IV update.
12. Report real-world positions of all IVs.
13. Display real-world distance of two clicked map points.
14. Display real-world length of a trajectory from continuously clicked points.
15. Rotate map by a specified degree.

## Optional requirements implemented in this project

### OR3

1. Automatically align IV orientation with the road.
2. Visualize the map with IV in a rotated way as if the IV is always heading upward.

### OR4

1. Generate virtual street view associated with an arbitrary road point as if captured at that point.

## Extra implemented feature

OR5 / path planning entry and overlay behavior must be preserved.
This is not the main refactor target, but existing behavior must not be broken.
