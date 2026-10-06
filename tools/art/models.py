"""Sculpted animal models (see sdf.py). Studs, y up, facing -Z, ground y = 0.

Bones match src/shared/Art/AnimalShapes.luau so the game animates them the
same way: body, head, tail, wingL/wingR, legL/legR.
"""

import numpy as np

from sdf import Ellipsoid, Model, RoundCone, feather, rot

WHITE = (253, 246, 234)
BEAK = (250, 168, 30)
WING = (247, 240, 228)
TAIL = (250, 243, 232)
ORANGE = (248, 158, 36)
ORANGE_DARK = (232, 130, 28)
RED = (222, 42, 42)
IRIS = (92, 50, 24)
IRIS_LIGHT = (150, 88, 40)
EYE_WHITE = (252, 252, 250)
CLAW = (238, 224, 196)
PUPIL = (20, 14, 12)
SHINE = (255, 255, 255)


def eye(m, center, radius, yaw, bone="head"):
    """A big cartoon eye looking forward and a little outward (yaw in degrees)."""
    r = rot(0, yaw, 0)
    fwd = r @ np.array([0, 0, -1.0])
    side = r @ np.array([1.0, 0, 0])
    c = np.asarray(center, float)
    m.detail(Ellipsoid(c - fwd * radius * 0.08, (radius * 1.1, radius * 1.22, radius * 0.55), r), PUPIL, bone)
    m.detail(Ellipsoid(c, (radius, radius * 1.12, radius * 0.55), r), IRIS, bone)
    m.detail(Ellipsoid(c + fwd * radius * 0.2, (radius * 0.62, radius * 0.7, radius * 0.4), r), PUPIL, bone)
    up = np.array([0, 1.0, 0])
    m.detail(Ellipsoid(c + fwd * radius * 0.42 + up * radius * 0.38 + side * radius * 0.22, (radius * 0.26, radius * 0.26, radius * 0.12), r), SHINE, bone)
    m.detail(Ellipsoid(c + fwd * radius * 0.42 - up * radius * 0.35 - side * radius * 0.25, (radius * 0.11, radius * 0.11, radius * 0.06), r), SHINE, bone)


def mirror(fn):
    for s in (-1, 1):
        fn(s)


def wing_feathers(m, s, bone, top, back, color, x=0.66):
    """Three rows of overlapping feathers on a folded wing, tips pointing back and down."""
    n = (s, 0.05, 0.0)
    rows = [  # (y, z start, count, length, width, x offset)
        (top, back - 0.32, 3, 0.26, 0.2, 0.0),
        (top - 0.13, back - 0.3, 3, 0.36, 0.22, 0.025),
        (top - 0.25, back - 0.26, 3, 0.5, 0.2, 0.05),
    ]
    for y, z0, count, length, width, dx in rows:
        for i in range(count):
            base = np.array([s * (x + dx), y, z0 + i * 0.13])
            tip = base + np.array([0, -0.2, 0.92]) / np.linalg.norm([0, -0.2, 0.92]) * length
            m.add(feather(base, tip, width, 0.11, n), color, bone, 0.008, prio=3)


def tail_fan(m, base, spread, color, sizes=(0.78, 0.62), bone="tail"):
    """Two layers of rounded feathers fanned up and back."""
    base = np.asarray(base, float)
    for layer, (length, dx) in enumerate(((sizes[0], 0.0), (sizes[1], 0.1), (sizes[1] * 0.8, 0.18))):
        for deg in spread:
            a = np.radians(deg)
            d = np.array([0, np.sin(a), np.cos(a)])
            for s in ((-1, 1) if dx else (0,)):
                b = base + np.array([s * dx, 0, 0])
                m.add(feather(b, b + d * length, 0.44 - layer * 0.06, 0.13, (1, 0, 0)), color, bone, 0.02, prio=1 + layer)


def cartoon_eye(m, center, rx, ry, yaw, bone="head", brow=True):
    """The reference eye: white with a big brown iris, black pupil, two shines,
    a dark lid line along the top and a thin eyebrow above it."""
    r = rot(0, yaw, 0)
    fwd = r @ np.array([0, 0, -1.0])
    side = r @ np.array([1.0, 0, 0])
    up = np.array([0, 1.0, 0])
    c = np.asarray(center, float)
    depth = min(rx, ry) * 0.55
    m.detail(Ellipsoid(c - fwd * depth * 0.2 + up * ry * 0.1, (rx * 1.08, ry * 1.04, depth), r), PUPIL, bone)  # lid line
    m.detail(Ellipsoid(c, (rx, ry, depth), r), EYE_WHITE, bone)
    ic = c + fwd * depth * 0.3 - up * ry * 0.08 + side * rx * 0.08
    m.detail(Ellipsoid(ic, (rx * 0.8, ry * 0.76, depth * 0.75), r), IRIS, bone)
    m.detail(Ellipsoid(ic + fwd * depth * 0.18, (rx * 0.66, ry * 0.62, depth * 0.62), r), IRIS_LIGHT, bone)
    m.detail(Ellipsoid(ic + fwd * depth * 0.3, (rx * 0.44, ry * 0.46, depth * 0.55), r), PUPIL, bone)
    m.detail(Ellipsoid(ic + fwd * depth * 0.62 + up * ry * 0.26 + side * rx * 0.18, (rx * 0.22, rx * 0.22, depth * 0.2), r), SHINE, bone)
    m.detail(Ellipsoid(ic + fwd * depth * 0.62 - up * ry * 0.3 - side * rx * 0.2, (rx * 0.09, rx * 0.09, depth * 0.1), r), SHINE, bone)
    if brow:
        b = c + up * ry * 1.45 + side * rx * 0.25 + fwd * depth * 0.2
        m.detail(Ellipsoid(b, (rx * 0.62, ry * 0.075, depth * 0.35), r @ rot(0, 0, -4 if yaw < 0 else 4)), PUPIL, bone)


CHICKEN = dict(  # fitted by tools/art/autofit.py to docs/art/ref/chicken-turnaround.png
    body_y=0.8,
    body_z=-0.04,
    body_rx=0.61,
    body_ry=0.62,
    body_rz=0.78,
    low_y=0.76,
    low_r=1.06,
    chest_y=1.12,
    chest_z=-0.2,
    chest_r=0.94,
    head_y=1.64,
    head_z=-0.39,
    head_r=0.91,
    comb=1.06,
    comb_y=-0.06,
    wing_x=0.62,
    wing_y=0.83,
    wing_s=1.0,
    tail_y=0.98,
    tail_z=0.6,
    tail_len=0.62,
    tail_tilt=48.0,
    leg_top=0.29,
    foot=0.3,
)


def chicken(P=None):
    """After docs/art/ref/chicken-turnaround.png: 2.4 studs tall, chibi pear shape.
    Proportions live in CHICKEN (fitted to the reference by autofit.py)."""
    p = dict(CHICKEN, **(P or {}))
    m = Model("Chicken")
    hy, hz, hr = p["head_y"], p["head_z"], p["head_r"]
    # one soft pear: a wide round body melting up into a big head
    m.add(Ellipsoid((0, p["body_y"], p["body_z"]), (p["body_rx"], p["body_ry"], p["body_rz"])), WHITE, "body")
    m.add(Ellipsoid((0, p["low_y"], p["body_z"]), np.array([0.6, 0.36, 0.68]) * p["low_r"]), WHITE, "body", 0.2)
    m.add(Ellipsoid((0, p["chest_y"], p["chest_z"]), np.array([0.5, 0.36, 0.55]) * p["chest_r"]), WHITE, "body", 0.25)
    m.add(Ellipsoid((0, hy, hz), np.array([0.43, 0.42, 0.44]) * hr), WHITE, "head", 0.3)
    # a ring of scalloped feathers where the head meets the body
    ring_y = (p["chest_y"] + hy) / 2 - 0.06
    for deg in range(-125, 126, 25):
        a = np.radians(deg)
        out = np.array([np.sin(a), 0, -np.cos(a)])
        base = np.array([0, ring_y, (p["chest_z"] + hz) / 2]) + out * np.array([0.47, 0, 0.5]) * (0.5 + 0.5 * hr)
        m.add(feather(base, base + np.array([0, -0.2, 0]) + out * 0.06, 0.24, 0.09, out + np.array([0, -0.3, 0])), WHITE, "body", 0.01, prio=1)
    # crown comb: five fat lobes from the forehead back over the head
    c, top = p["comb"], hy + 0.42 * hr + p["comb_y"]
    for (dy, dz, ry, tilt) in [(-0.12, -0.26, 0.15, -30), (0.03, -0.14, 0.18, -15), (0.09, 0.01, 0.19, 0), (0.04, 0.16, 0.18, 15), (-0.09, 0.28, 0.15, 30)]:
        m.add(Ellipsoid((0, top + dy * c, hz + dz * c), (0.1 * c, ry * c, 0.11 * c), rot(tilt)), RED, "head", 0.03, prio=6)
    def side_lobes(s):
        m.add(Ellipsoid((s * 0.13 * c, top - 0.03 * c, hz - 0.08), (0.08 * c, 0.16 * c, 0.1 * c), rot(0, 0, -s * 28)), RED, "head", 0.03, prio=6)
        m.add(Ellipsoid((s * 0.21 * c, top - 0.13 * c, hz - 0.12), (0.07 * c, 0.13 * c, 0.09 * c), rot(0, 0, -s * 48)), RED, "head", 0.03, prio=6)

    mirror(side_lobes)
    # a small two-part beak, wattles hanging under it
    front = hz - 0.44 * hr
    by = hy - 0.03
    m.add(RoundCone((0, by, front + 0.06), (0, by - 0.05, front - 0.2), 0.13, 0.035), BEAK, "head", 0.03, prio=7)
    m.add(RoundCone((0, by - 0.08, front + 0.06), (0, by - 0.1, front - 0.08), 0.075, 0.025), ORANGE_DARK, "head", 0.02, prio=6)
    mirror(lambda s: m.add(Ellipsoid((s * 0.055, by - 0.27, front + 0.03), (0.048, 0.1, 0.05)), RED, "head", 0.01, prio=6))

    # wings: an egg on each side covered in four rows of rounded feathers
    def wing(s):
        bone = "wingL" if s < 0 else "wingR"
        ws, wx, wy = p["wing_s"], p["wing_x"], p["wing_y"]
        m.add(Ellipsoid((s * wx, wy, 0.0), np.array([0.13, 0.36, 0.5]) * ws, rot(10, 0, -s * 6)), WING, bone, 0.02, prio=2)
        rows = [(0.23, -0.32, 3, 0.24), (0.1, -0.36, 4, 0.3), (-0.05, -0.38, 4, 0.36), (-0.19, -0.3, 3, 0.4)]
        for k, (dy, z0, count, length) in enumerate(rows):
            for i in range(count):
                base = np.array([s * (wx + 0.12 + k * 0.015), wy + dy * ws, (z0 + i * 0.17) * ws])
                d = np.array([0, -0.25, 1.0])
                tip = base + d / np.linalg.norm(d) * length * ws
                m.add(feather(base, tip, 0.21 * ws, 0.13, (s, 0.1, 0)), WING, bone, 0.004, prio=3)

    mirror(wing)
    # tail: a fan of rounded feathers up and back, a few side by side
    base = np.array([0, p["tail_y"], p["tail_z"]])
    for k, (deg, dx) in enumerate(((p["tail_tilt"] - 36, 0.0), (p["tail_tilt"] - 14, -0.1), (p["tail_tilt"] - 14, 0.1), (p["tail_tilt"] + 10, 0.0), (p["tail_tilt"] + 32, -0.07), (p["tail_tilt"] + 32, 0.07))):
        a = np.radians(deg)
        d = np.array([0, np.sin(a), np.cos(a)])
        b = base + np.array([dx, 0, 0])
        length = p["tail_len"] * (1.0 - abs(deg - p["tail_tilt"]) / 60)
        m.add(feather(b, b + d * length, 0.27, 0.15, (1, 0, 0)), TAIL, "tail", 0.012, prio=2 + (k % 2))

    # short thick legs with fluffy cuffs, three toes and a back toe, pale claws
    def leg(s):
        bone = "legL" if s < 0 else "legR"
        x, z, lt, fl = s * 0.22, -0.12, p["leg_top"], p["foot"]
        m.add(Ellipsoid((x, lt, z), (0.17, 0.12, 0.17)), WHITE, "body", 0.06)
        m.add(RoundCone((x, lt - 0.01, z), (x, 0.1, z), 0.1, 0.09), ORANGE, bone, 0.02, prio=4)
        for yaw in (-32, 0, 32):
            d = rot(0, yaw, 0) @ np.array([0, 0, -1.0])
            root = np.array([x, 0.065, z])
            tip = root + d * fl + np.array([0, -0.015, 0])
            m.add(RoundCone(root, tip, 0.085, 0.06), ORANGE, bone, 0.04, prio=4)
            m.detail(Ellipsoid(tip + d * 0.05, (0.035, 0.03, 0.05), rot(0, yaw, 0)), CLAW, bone)
        m.add(RoundCone((x, 0.065, z), (x, 0.05, z + fl * 0.55), 0.06, 0.045), ORANGE, bone, 0.03, prio=4)

    mirror(leg)
    mirror(lambda s: cartoon_eye(m, (s * 0.21 * hr, hy + 0.02, hz - 0.34 * hr), 0.145 * hr, 0.2 * hr, -s * 26))
    return m


DUCK = dict(  # fitted by tools/art/autofit.py to docs/art/ref/duck-turnaround.png
    body_y=0.67,
    body_z=0.19,
    body_rx=0.58,
    body_ry=0.43,
    body_rz=0.68,
    chest_y=0.92,
    chest_z=-0.22,
    chest_r=0.64,
    neck_y=1.73,
    neck_r=1.15,
    head_y=1.6,
    head_z=-0.03,
    head_r=1.06,
    bill_y=1.44,
    bill_len=1.03,
    bill_w=1.15,
    tuft=0.88,
    wing_x=0.5,
    wing_y=0.8,
    wing_s=0.95,
    tail_y=0.86,
    tail_z=0.76,
    tail_len=0.36,
    tail_tilt=46.0,
    leg_top=0.3,
    foot=0.38,
)


def duck(P=None):
    """After docs/art/ref/duck-turnaround.png: 2.4 studs tall, big round head."""
    p = dict(DUCK, **(P or {}))
    m = Model("Duck")
    hy, hz, hr = p["head_y"], p["head_z"], p["head_r"]
    # a round body with a full breast, a short neck and a big round head
    m.add(Ellipsoid((0, p["body_y"], p["body_z"]), (p["body_rx"], p["body_ry"], p["body_rz"]), rot(-6)), WHITE, "body")
    m.add(Ellipsoid((0, p["chest_y"], p["chest_z"]), np.array([0.5, 0.4, 0.42]) * p["chest_r"]), WHITE, "body", 0.2)
    m.add(Ellipsoid((0, p["neck_y"], (p["chest_z"] + hz) / 2), np.array([0.3, 0.3, 0.3]) * p["neck_r"]), WHITE, "head", 0.18)
    m.add(Ellipsoid((0, hy, hz), np.array([0.47, 0.45, 0.46]) * hr), WHITE, "head", 0.14)
    # a small row of scallops on the breast
    for deg in range(-60, 61, 30):
        a = np.radians(deg)
        out = np.array([np.sin(a), 0, -np.cos(a)])
        base = np.array([0, p["chest_y"] + 0.12, p["chest_z"]]) + out * np.array([0.42, 0, 0.36]) * p["chest_r"]
        m.add(feather(base, base + np.array([0, -0.16, 0]) + out * 0.04, 0.2, 0.08, out + np.array([0, -0.3, 0])), WHITE, "body", 0.01, prio=1)
    # a tuft of three feathers curling back on the head
    tu = p["tuft"]
    for k, (dx, back) in enumerate(((-0.07, 0.06), (0.0, 0.0), (0.07, 0.06))):
        base = np.array([dx, hy + 0.4 * hr, hz + 0.05 + back])
        tip = base + np.array([dx * 0.8, 0.2 * tu, 0.2 * tu])
        m.add(feather(base, tip, 0.11 * tu, 0.08, (1, 0, 0)), WHITE, "head", 0.02, prio=1)
    # a long wide flat bill, a little upturned, with nostrils and a smile line
    front = hz - 0.46 * hr
    bl, bw, by = p["bill_len"], p["bill_w"], p["bill_y"]
    m.add(Ellipsoid((0, by + 0.03, front - 0.1 * bl), (0.22 * bw, 0.085, 0.24 * bl), rot(-6)), BEAK, "head", 0.06, prio=7)
    m.add(Ellipsoid((0, by + 0.06, front - 0.32 * bl), (0.3 * bw, 0.075, 0.2 * bl), rot(-16)), BEAK, "head", 0.05, prio=7)
    m.add(Ellipsoid((0, by - 0.05, front - 0.15 * bl), (0.2 * bw, 0.05, 0.24 * bl), rot(-3)), ORANGE_DARK, "head", 0.03, prio=7)
    mirror(lambda s: m.detail(Ellipsoid((s * 0.06 * bw, by + 0.11, front - 0.15 * bl), (0.025, 0.012, 0.04)), (200, 110, 20)))

    # wings with rows of rounded feathers
    def wing(s):
        bone = "wingL" if s < 0 else "wingR"
        ws, wx, wy = p["wing_s"], p["wing_x"], p["wing_y"]
        m.add(Ellipsoid((s * wx, wy, 0.2), np.array([0.13, 0.33, 0.55]) * ws, rot(8, 0, -s * 5)), WING, bone, 0.02, prio=2)
        rows = [(0.2, -0.1, 3, 0.24), (0.07, -0.14, 4, 0.3), (-0.07, -0.14, 4, 0.36)]
        for k, (dy, z0, count, length) in enumerate(rows):
            for i in range(count):
                base = np.array([s * (wx + 0.12 + k * 0.015), wy + dy * ws, 0.2 + (z0 + i * 0.16) * ws])
                d = np.array([0, -0.1, 1.0])
                tip = base + d / np.linalg.norm(d) * length * ws
                m.add(feather(base, tip, 0.2 * ws, 0.13, (s, 0.1, 0)), WING, bone, 0.004, prio=3)

    mirror(wing)
    # a little tail fan tipped up
    tilt = p["tail_tilt"]
    base = np.array([0, p["tail_y"], p["tail_z"]])
    for k, (deg, dx) in enumerate(((tilt - 28, 0.0), (tilt - 8, -0.09), (tilt - 8, 0.09), (tilt + 14, 0.0), (tilt + 30, -0.06), (tilt + 30, 0.06))):
        a = np.radians(deg)
        d = np.array([0, np.sin(a), np.cos(a)])
        b = base + np.array([dx, 0, 0])
        m.add(feather(b, b + d * p["tail_len"] * (1 - abs(deg - tilt) / 70), 0.24, 0.14, (1, 0, 0)), TAIL, "tail", 0.015, prio=2)

    # short legs with fluffy cuffs and webbed feet
    def leg(s):
        bone = "legL" if s < 0 else "legR"
        x, z, lt, fl = s * 0.22, 0.1, p["leg_top"], p["foot"]
        m.add(Ellipsoid((x, lt, z), (0.16, 0.11, 0.16)), WHITE, "body", 0.06)
        m.add(RoundCone((x, lt - 0.01, z), (x, 0.1, z), 0.1, 0.09), ORANGE, bone, 0.02, prio=4)
        toes = []
        for yaw in (-30, 0, 30):
            d = rot(0, yaw, 0) @ np.array([0, 0, -1.0])
            root = np.array([x, 0.05, z])
            tip = root + d * fl
            toes.append(tip)
            m.add(RoundCone(root, tip, 0.07, 0.055), ORANGE, bone, 0.03, prio=4)
        # the web between the toes
        web_c = (np.array([x, 0.035, z]) + toes[0] + toes[2]) / 3
        m.add(Ellipsoid(web_c + np.array([0, 0, -0.04]), (fl * 0.7, 0.035, fl * 0.5)), ORANGE, bone, 0.04, prio=4)

    mirror(leg)
    mirror(lambda s: cartoon_eye(m, (s * 0.2 * hr, hy + 0.15, hz - 0.36 * hr), 0.15 * hr, 0.2 * hr, -s * 24))
    return m


MODELS = {"Chicken": chicken, "Duck": duck}
