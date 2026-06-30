import math
import numpy as np

# Camera parameters
mapW = 1404
mapH = 803
scale = 1.7
cam = {
    'realX': mapW / 2 * scale,
    'realY': mapH / 2 * scale,
    'height': 10,
    'yawDegree': 0,
    'pitchDegree': 15,
    'focalPixel': 280,
    'maxDist': 680,
}

viewW = 520
viewH = 360

pitch = math.radians(cam['pitchDegree'])
yaw   = math.radians(cam['yawDegree'])

R1 = np.array([
    [1, 0, 0],
    [0, math.cos(pitch), -math.sin(pitch)],
    [0, math.sin(pitch),  math.cos(pitch)]
])

R2 = np.array([
    [1, 0,  0],
    [0, 0, -1],
    [0, 1,  0]
])

az = math.pi - yaw
R3 = np.array([
    [math.cos(az), -math.sin(az), 0],
    [math.sin(az),  math.cos(az), 0],
    [0,             0,            1]
])

R = R3 @ R2 @ R1
rcw = R
right   = rcw[:, 0]
up      = rcw[:, 1]
forward = rcw[:, 2]
cameraCenter = np.array([cam['realX'], cam['realY'], cam['height']])

print(f"forward = {forward}")
print()

# Forward direction analysis
# yaw=0 should be looking NORTH (+Y world)
print(f"yaw=0:  forward = {forward}, Y component = {forward[1]}")
yaw90 = math.radians(90)
az90 = math.pi - yaw90
R3_90 = np.array([
    [math.cos(az90), -math.sin(az90), 0],
    [math.sin(az90),  math.cos(az90), 0],
    [0,               0,             1]
])
fwd90 = (R3_90 @ R2 @ R1)[:, 2]
print(f"yaw=90: forward = {fwd90}, X component = {fwd90[0]}")
print()

# Center pixel
xPlane = 0
yPlane = 0
rayDir = cam['focalPixel'] * forward + xPlane * right + yPlane * up
print(f"Center pixel: rayDir={rayDir}, rayDir(3)={rayDir[2]:.4f}")

if rayDir[2] < -0.0001:
    tGround = -cameraCenter[2] / rayDir[2]
    groundPt = cameraCenter + tGround * rayDir
    mapCol = round(groundPt[0] / scale)
    mapRow = round(mapH - groundPt[1] / scale)
    print(f"  tGround={tGround:.1f} groundPt={groundPt} mapCol={mapCol} mapRow={mapRow}")

# Scan all columns, middle row
#  line: above horizon=sky, below=ground
print("\n--- scan middle row across cols ---")
midRow = viewH // 2
for col in [1, 130, 260, 390, 520]:
    xPlane = col - viewW / 2
    yPlane = viewH / 2 - midRow  # should be 0
    rayDir = cam['focalPixel'] * forward + xPlane * right + yPlane * up
    if rayDir[2] >= -0.0001:
        print(f"  col={col}: SKY")
    else:
        tGround = -cameraCenter[2] / rayDir[2]
        groundPt = cameraCenter + tGround * rayDir
        mc = round(groundPt[0] / scale)
        mr = round(mapH - groundPt[1] / scale)
        print(f"  col={col}: Z={rayDir[2]:.1f} tG={tGround:.1f} mc={mc} mr={mr}")
    print(f"         rayDir={rayDir}")

print()
# Vertical scan at center
print("--- scan center col across rows ---")
for row in [1, 90, 180, 270, 360]:
    xPlane = 0
    yPlane = viewH / 2 - row
    rayDir = cam['focalPixel'] * forward + xPlane * right + yPlane * up
    if rayDir[2] >= -0.0001:
        print(f"  row={row:3d}: yPl={yPlane:7.1f} rayZ={rayDir[2]:8.2f} SKY")
    else:
        tGround = -cameraCenter[2] / rayDir[2]
        groundPt = cameraCenter + tGround * rayDir
        mc = round(groundPt[0] / scale)
        mr = round(mapH - groundPt[1] / scale)
        dx = groundPt[0] - cam['realX']
        dy = groundPt[1] - cam['realY']
        dist = math.sqrt(dx*dx+dy*dy)
        in_range = tGround > 0 and dist <= cam['maxDist'] and 1 <= mr <= mapH and 1 <= mc <= mapW
        status = "HIT" if in_range else "OUT"
        print(f"  row={row:3d}: yPl={yPlane:7.1f} rayZ={rayDir[2]:8.2f} tG={tGround:8.1f} gp=({groundPt[0]:8.1f},{groundPt[1]:8.1f}) mc={mc} mr={mr} dist={dist:.0f} {status}")
