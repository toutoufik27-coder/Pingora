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


def chicken():
    m = Model("Chicken")
    # body: a plump round egg, back end raised, full chest, fluffy underside
    m.add(Ellipsoid((0, 0.98, 0.1), (0.62, 0.55, 0.72), rot(-15)), WHITE, "body")
    m.add(Ellipsoid((0, 1.08, -0.33), (0.5, 0.52, 0.44)), WHITE, "body", 0.2)
    m.add(Ellipsoid((0, 0.72, 0.08), (0.5, 0.34, 0.52)), WHITE, "body", 0.2)
    # neck and head melt smoothly out of the chest
    m.add(RoundCone((0, 1.25, -0.3), (0, 1.56, -0.42), 0.34, 0.3), WHITE, "head", 0.2)
    m.add(Ellipsoid((0, 1.74, -0.45), (0.39, 0.41, 0.39)), WHITE, "head", 0.12)
    # a ruff of scalloped feathers around the neck
    for deg in range(-120, 121, 30):
        a = np.radians(deg)
        out = np.array([np.sin(a), 0, -np.cos(a)])
        base = np.array([0, 1.5, -0.38]) + out * 0.36
        m.add(feather(base, base + np.array([0, -0.28, 0]) + out * 0.12, 0.26, 0.09, out), WHITE, "body", 0.012, prio=1)
    # comb: five round lobes on a ridge
    m.add(Ellipsoid((0, 2.05, -0.43), (0.07, 0.1, 0.24)), RED, "head", 0.05, prio=5)
    for (y, z, r) in [(2.1, -0.66, 0.1), (2.19, -0.55, 0.125), (2.24, -0.42, 0.14), (2.21, -0.28, 0.13), (2.12, -0.17, 0.1)]:
        m.add(Ellipsoid((0, y, z), (r * 0.65, r, r)), RED, "head", 0.035, prio=5)
    # a bigger two-part beak and drop-shaped wattles
    m.add(RoundCone((0, 1.73, -0.74), (0, 1.65, -1.08), 0.14, 0.035), BEAK, "head", 0.03, prio=5)
    m.add(RoundCone((0, 1.63, -0.76), (0, 1.61, -0.94), 0.08, 0.025), ORANGE_DARK, "head", 0.02, prio=5)
    mirror(lambda s: m.add(Ellipsoid((s * 0.06, 1.46, -0.8), (0.065, 0.13, 0.07)), RED, "head", 0.04, prio=5))

    # wings folded on the sides with three rows of feathers
    def wing(s):
        bone = "wingL" if s < 0 else "wingR"
        m.add(Ellipsoid((s * 0.58, 1.02, 0.08), (0.13, 0.34, 0.52), rot(12, 0, -s * 4)), WING, bone, 0.02, prio=2)
        wing_feathers(m, s, bone, 1.18, 0.12, WING, x=0.69)

    mirror(wing)
    tail_fan(m, (0, 1.16, 0.55), (32, 47, 62, 77, 90), TAIL)

    # fluffy thighs, then short thick orange legs and chunky toes
    def leg(s):
        bone = "legL" if s < 0 else "legR"
        x = s * 0.24
        m.add(Ellipsoid((x, 0.56, 0.06), (0.2, 0.22, 0.23)), WHITE, "body", 0.1)
        m.add(RoundCone((x, 0.5, 0.06), (x, 0.09, 0.02), 0.095, 0.08), ORANGE, bone, 0.02, prio=4)
        for yaw in (-38, 0, 38):
            d = rot(0, yaw, 0) @ np.array([0, 0, -1.0])
            tip = np.array([x, 0.045, 0.02]) + d * 0.32
            m.add(RoundCone((x, 0.06, 0.02), tip, 0.07, 0.045), ORANGE, bone, 0.035, prio=4)
        m.add(RoundCone((x, 0.06, 0.02), (x, 0.05, 0.17), 0.055, 0.04), ORANGE, bone, 0.03, prio=4)

    mirror(leg)
    mirror(lambda s: eye(m, (s * 0.26, 1.83, -0.7), 0.13, -s * 32))
    return m


def duck():
    m = Model("Duck")
    # a round, full body with a breast and a tail tipped up
    m.add(Ellipsoid((0, 0.98, 0.14), (0.6, 0.52, 0.8), rot(-8)), WHITE, "body")
    m.add(Ellipsoid((0, 1.02, -0.4), (0.52, 0.52, 0.5)), WHITE, "body", 0.22)
    m.add(RoundCone((0, 1.05, 0.6), (0, 1.32, 1.02), 0.34, 0.1), WHITE, "tail", 0.2)
    tail_fan(m, (0, 1.12, 0.78), (28, 46, 64), TAIL, sizes=(0.56, 0.44))
    # a short thick neck into a big round head
    m.add(RoundCone((0, 1.3, -0.45), (0, 1.66, -0.5), 0.3, 0.27), WHITE, "head", 0.2)
    m.add(Ellipsoid((0, 1.88, -0.55), (0.41, 0.4, 0.42)), WHITE, "head", 0.14)
    # a long wide bill with a slight upturn
    m.add(Ellipsoid((0, 1.8, -0.95), (0.19, 0.085, 0.26), rot(-6)), BEAK, "head", 0.07, prio=5)
    m.add(Ellipsoid((0, 1.8, -1.16), (0.25, 0.075, 0.17), rot(-12)), BEAK, "head", 0.06, prio=5)
    m.add(Ellipsoid((0, 1.72, -1.0), (0.2, 0.055, 0.28), rot(-4)), ORANGE_DARK, "head", 0.05, prio=5)
    mirror(lambda s: m.detail(Ellipsoid((s * 0.06, 1.88, -1.03), (0.025, 0.012, 0.04)), (200, 110, 20)))

    def wing(s):
        bone = "wingL" if s < 0 else "wingR"
        m.add(Ellipsoid((s * 0.56, 1.04, 0.16), (0.13, 0.33, 0.62), rot(8, 0, -s * 4)), WING, bone, 0.02, prio=2)
        wing_feathers(m, s, bone, 1.2, 0.26, WING, x=0.67)

    mirror(wing)

    # short thick legs and webbed feet with three toes
    def leg(s):
        bone = "legL" if s < 0 else "legR"
        x = s * 0.25
        m.add(RoundCone((x, 0.52, 0.14), (x, 0.08, 0.08), 0.115, 0.095), ORANGE, bone, 0.04, prio=4)
        for yaw in (-28, 0, 28):
            d = rot(0, yaw, 0) @ np.array([0, 0, -1.0])
            m.add(RoundCone((x, 0.05, 0.06), np.array([x, 0.04, 0.06]) + d * 0.38, 0.06, 0.05), ORANGE, bone, 0.03, prio=4)
        m.add(Ellipsoid((x, 0.035, -0.12), (0.2, 0.03, 0.2)), ORANGE, bone, 0.05, prio=4)

    mirror(leg)
    mirror(lambda s: eye(m, (s * 0.26, 1.96, -0.82), 0.12, -s * 35))
    return m


MODELS = {"Chicken": chicken, "Duck": duck}
