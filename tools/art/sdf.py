"""Tiny signed-distance-field sculpting kit for Kinfield's animals.

A model is a list of parts. Each part is a shape (ellipsoid, round cone...),
a colour, the bone it belongs to and how softly it melts into what came
before it (`blend`, in studs). The parts are combined with a smooth union,
turned into a mesh with marching cubes, and every vertex takes the colour and
bone of the part it lies on.

Space is Roblox studs: y up, the animal faces -Z, ground at y = 0.
"""

from dataclasses import dataclass, field

import numpy as np
from skimage import measure


def rot_x(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def rot(x=0.0, y=0.0, z=0.0):
    """Like Roblox CFrame.Angles(x, y, z) in degrees."""
    return rot_x(x) @ rot_y(y) @ rot_z(z)


class Shape:
    def dist(self, p):  # p: N x 3
        raise NotImplementedError

    def bounds(self):  # (lo, hi)
        raise NotImplementedError


class Ellipsoid(Shape):
    def __init__(self, center, radii, r=None):
        self.c = np.asarray(center, float)
        self.r = np.asarray(radii, float)
        self.m = np.eye(3) if r is None else np.asarray(r, float)

    def dist(self, p):
        q = (p - self.c) @ self.m  # into local space
        k0 = np.linalg.norm(q / self.r, axis=1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

    def bounds(self):
        e = np.abs(self.m) @ self.r
        return self.c - e, self.c + e


def feather(base, tip, width, thick, normal):
    """A flat leaf-like ellipsoid from base to tip; `normal` is the way its flat side faces."""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    y = tip - base
    length = np.linalg.norm(y)
    y /= length
    n = np.asarray(normal, float)
    z = n - y * (n @ y)
    z /= np.linalg.norm(z)
    x = np.cross(y, z)
    m = np.stack([x, y, z], axis=1)  # columns are the local axes
    return Ellipsoid((base + tip) / 2, (width / 2, length / 2, thick / 2), m)


class RoundCone(Shape):
    """A capsule from a (radius ra) to b (radius rb)."""

    def __init__(self, a, b, ra, rb):
        self.a = np.asarray(a, float)
        self.b = np.asarray(b, float)
        self.ra, self.rb = float(ra), float(rb)

    def dist(self, p):
        ba = self.b - self.a
        l2 = ba @ ba
        rr = self.ra - self.rb
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - self.a
        y = pa @ ba
        z = y - l2
        x = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", x, x)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        out = (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - self.ra
        c1 = np.sign(z) * a2 * z2 > k
        c2 = np.sign(y) * a2 * y2 < k
        out = np.where(c1, np.sqrt(x2 + z2) * il2 - self.rb, out)
        out = np.where(c2, np.sqrt(x2 + y2) * il2 - self.ra, out)
        return out

    def bounds(self):
        r = max(self.ra, self.rb)
        return np.minimum(self.a, self.b) - r, np.maximum(self.a, self.b) + r


def smin(a, b, k):
    """Polynomial smooth minimum: melts two surfaces together over ~k studs."""
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


@dataclass
class Part:
    shape: Shape
    color: tuple
    bone: str = "body"
    blend: float = 0.08
    prio: float = 0.0  # colour priority where parts overlap (higher wins)


@dataclass
class Model:
    name: str
    parts: list = field(default_factory=list)
    details: list = field(default_factory=list)  # crisp separate pieces (eyes)

    def add(self, shape, color, bone="body", blend=0.08, prio=0.0):
        self.parts.append(Part(shape, color, bone, blend, prio))

    def detail(self, shape, color, bone="head"):
        self.details.append(Part(shape, color, bone, 0, 0))

    def volume(self, voxel=0.014, details=False):
        """Signed distances on a grid. Returns (grid, lo corner).

        Each part is only evaluated inside its own bounding box (plus its blend
        distance): further away it cannot change the smooth union."""
        parts = self.parts + (self.details if details else [])
        lo = np.min([p.shape.bounds()[0] for p in parts], axis=0) - 0.1
        hi = np.max([p.shape.bounds()[1] for p in parts], axis=0) + 0.1
        n = np.ceil((hi - lo) / voxel).astype(int) + 1
        d = np.full(n, 1e3, np.float64)

        def region(part, margin):
            a, b = part.shape.bounds()
            i0 = np.clip(np.floor((a - margin - lo) / voxel).astype(int), 0, n)
            i1 = np.clip(np.ceil((b + margin - lo) / voxel).astype(int) + 1, 0, n)
            axes = [lo[k] + np.arange(i0[k], i1[k]) * voxel for k in range(3)]
            gx, gy, gz = np.meshgrid(*axes, indexing="ij")
            pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1)
            sl = tuple(slice(i0[k], i1[k]) for k in range(3))
            return sl, part.shape.dist(pts).reshape(gx.shape)

        for part in self.parts:
            sl, pd = region(part, part.blend + 2 * voxel)
            d[sl] = smin(d[sl], pd, part.blend)
        if details:
            for part in self.details:
                sl, pd = region(part, 2 * voxel)
                d[sl] = np.minimum(d[sl], pd)
        return d, lo

    def silhouette(self, view, voxel=0.01):
        """Orthographic silhouette, rows top to bottom. view: front, side (facing right), back, top."""
        if getattr(self, "_sil_voxel", None) != voxel:
            self._sil_vol, _ = self.volume(voxel, details=True)
            self._sil_voxel = voxel
        vol = self._sil_vol
        inside = vol < 0  # axes x, y, z
        if view in ("front", "back"):
            img = inside.any(axis=2).T  # (y, x)
            if view == "back":
                img = img[:, ::-1]
        elif view == "side":
            img = inside.any(axis=0)  # (y, z); forward is -z, show it on the right
            img = img[:, ::-1]
        else:  # top: looking down, forward (-z) at the bottom of the image
            img = inside.any(axis=1).T  # (z, x)
        return img[::-1]  # y up (top view: back at the top)

    def mesh(self, voxel=0.014):
        """Marching cubes over the smooth union. Returns verts, faces, colours, bones."""
        vol, lo = self.volume(voxel)
        verts, faces, _, _ = measure.marching_cubes(vol, level=0.0, spacing=(voxel, voxel, voxel))
        verts = verts + lo
        # colour and bone of the part each vertex lies on
        dists = np.stack([p.shape.dist(verts) - p.prio * 0.002 for p in self.parts], axis=1)
        owner = np.argmin(dists, axis=1)
        colors = np.array([self.parts[i].color for i in owner], float)
        bones = [self.parts[i].bone for i in owner]
        return verts, faces, colors, bones
