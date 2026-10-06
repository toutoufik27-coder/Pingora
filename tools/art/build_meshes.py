"""Builds smooth game meshes for the animals in src/shared/Art/AnimalShapes.luau.

For every animal and every bone (body, head, legs, tail, wings...) the rounded
parts are fused into one clay-like mesh (voxel remesh + smoothing), coloured
per vertex from the part each point belongs to, and reduced to a small
triangle count. Eyes, noses and blocks stay as crisp separate pieces.

Usage (Blender as a Python module, `pip install bpy`):
    python -I tools/art/build_meshes.py PARTS.txt OUT_DIR [--render] [--export]

PARTS.txt comes from `luau-runner run tools/art/dump_shapes.luau`.
--render writes OUT_DIR/<Animal>.png previews, --export writes OUT_DIR/<Animal>.glb.
"""

import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

args = [a for a in sys.argv[1:] if not a.startswith("--")]
PARTS_FILE, OUT = args[-2], args[-1]
RENDER = "--render" in sys.argv
EXPORT = "--export" in sys.argv

# Roblox (x, y, z) with the animal facing -Z  ->  Blender (x, -z, y), facing +Y.
R2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
# Preview-only offsets so the bees fly around the hive instead of inside it.
BEE_OFFSET = {"bee1": (1.5, 0.5, -0.9), "bee2": (-1.6, 0.9, -0.5), "bee3": (0.5, 1.3, -1.5)}


class Prim:
    def __init__(self, f):
        self.animal, self.bone, self.shape = f[0], f[1], f[2]
        self.size = np.array(list(map(float, f[3:6])))
        self.pos = np.array(list(map(float, f[6:9])))
        self.rgb = tuple(int(c) for c in f[9:12])
        rot = list(map(float, f[12:15]))
        self.alpha = float(f[15])
        self.detail = f[16] == "1"
        if self.bone in BEE_OFFSET and (RENDER and not EXPORT):
            self.pos = self.pos + np.array(BEE_OFFSET[self.bone])
        rx, ry, rz = (math.radians(a) for a in rot)
        self.rot = Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z")
        self.rot_np = np.array(self.rot)

    @property
    def fused(self):
        return not self.detail and self.alpha == 0

    def world(self):
        base = Matrix.Rotation(math.radians(90), 4, "Y") if self.shape == "Cylinder" else Matrix.Identity(4)
        local = Matrix.Translation(Vector(self.pos)) @ self.rot.to_4x4() @ Matrix.Diagonal((*self.size, 1)) @ base
        return R2B @ local

    def field(self, pts):
        """How far points (Roblox space, N x 3) are from this part: 1 on its surface."""
        local = (pts - self.pos) @ self.rot_np  # R^T (p - c) for row vectors
        half = self.size / 2
        q = local / half
        if self.shape == "Ellipsoid":
            return np.linalg.norm(q, axis=1)
        if self.shape == "Cylinder":
            return np.maximum(np.abs(q[:, 0]), np.hypot(q[:, 1], q[:, 2]))
        return np.max(np.abs(q), axis=1)


def linear(rgb):
    return tuple((c / 255) ** 2.2 for c in rgb) + (1.0,)


def add_primitive(p: Prim, hi_res: bool):
    if p.shape == "Ellipsoid":
        seg, ring = (40, 22) if hi_res else (16, 10)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=0.5)
    elif p.shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=32 if hi_res else 16, radius=0.5, depth=1)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.matrix_world = p.world()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if p.shape == "Block":
        bev = o.modifiers.new("bevel", "BEVEL")
        bev.width = min(0.04, float(min(p.size)) * 0.25)
        bev.segments = 2
        bpy.ops.object.modifier_apply(modifier=bev.name)
    return o


def set_color(o, colors):
    """colors: N x 4 array of per-vertex linear colours."""
    attr = o.data.color_attributes.get("Col") or o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.asarray(colors, dtype=np.float32).ravel())


def fill_color(o, rgb):
    n = len(o.data.vertices)
    set_color(o, np.tile(np.array(linear(rgb)), (n, 1)))


def smooth_shading(o):
    for poly in o.data.polygons:
        poly.use_smooth = True


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    return o


def fuse(prims, voxel, name):
    objs = [add_primitive(p, True) for p in prims]
    o = join(objs, name)
    rm = o.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=rm.name)
    sm = o.modifiers.new("smooth", "LAPLACIANSMOOTH")
    sm.iterations = 3
    sm.lambda_factor = 0.6
    bpy.ops.object.modifier_apply(modifier=sm.name)
    # keep it light for phones: about 1 triangle per 0.004 square studs
    area = sum(poly.area for poly in o.data.polygons)
    target = int(min(2600, max(160, area * 260)))
    tris = sum(len(poly.vertices) - 2 for poly in o.data.polygons)
    if tris > target:
        dec = o.modifiers.new("decimate", "DECIMATE")
        dec.ratio = target / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    # colour each vertex from the part it lies on
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    b = co.reshape(-1, 3)
    pts = np.stack([b[:, 0], b[:, 2], -b[:, 1]], axis=1)  # Blender -> Roblox space
    fields = np.stack([p.field(pts) for p in prims], axis=1)
    owner = np.argmin(fields, axis=1)
    palette = np.array([linear(p.rgb) for p in prims])
    set_color(o, palette[owner])
    smooth_shading(o)
    return o


def build_animal(name, prims):
    height = max(p.pos[1] + p.size[1] / 2 for p in prims)
    voxel = 0.022 if height < 2.6 else 0.032
    groups = {}
    for p in prims:
        groups.setdefault(p.bone, []).append(p)
    objs = []
    for bone, ps in groups.items():
        pieces = []
        fused = [p for p in ps if p.fused]
        if fused:
            pieces.append(fuse(fused, voxel, f"{name}_{bone}"))
        for p in ps:
            if not p.fused:
                o = add_primitive(p, False)
                fill_color(o, p.rgb)
                if p.shape != "Block":
                    smooth_shading(o)
                if p.alpha:
                    o["alpha"] = p.alpha
                pieces.append(o)
        alpha_pieces = [o for o in pieces if "alpha" in o]
        solid = [o for o in pieces if "alpha" not in o]
        if solid:
            objs.append(join(solid, bone))
        for i, o in enumerate(alpha_pieces):
            o.name = f"{bone}_glass{i}"
            objs.append(o)
    return objs


def material(alpha=0.0):
    m = bpy.data.materials.new("Animal" if not alpha else "Glass")
    nodes = m.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    m.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    if alpha:
        bsdf.inputs["Alpha"].default_value = 1 - alpha
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    animals = {}
    for line in open(PARTS_FILE):
        f = line.split()
        if len(f) == 17:
            p = Prim(f)
            animals.setdefault(p.animal, []).append(p)
    solid_mat, glass_mat = material(), material(0.6)
    built = {}
    for name, prims in animals.items():
        objs = build_animal(name, prims)
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(glass_mat if "alpha" in o else solid_mat)
        built[name] = objs
        tris = sum(sum(len(poly.vertices) - 2 for poly in o.data.polygons) for o in objs)
        print(f"{name}: {len(objs)} pieces, {tris} triangles")
    if EXPORT:
        export(built)
    if RENDER:
        render(built)


def export(built):
    for name, objs in built.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f"{OUT}/{name}.glb", use_selection=True, export_format="GLB", export_yup=True)


def render(built):
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=60)
    floor = bpy.context.object
    fm = bpy.data.materials.new("floor")
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = linear((150, 154, 158))
    floor.data.materials.append(fm)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    scene.camera = cam
    cam.data.lens = 50
    for loc, energy in [((-6, 8, 10), 900), ((8, 6, 5), 500), ((0, -8, 6), 600)]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.data.energy = energy
        light.data.size = 6
        light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.32, 0.33, 0.35)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.render.resolution_x = scene.render.resolution_y = 480
    scene.view_settings.look = "AgX - Base Contrast"
    for name, objs in built.items():
        for other, os_ in built.items():
            for o in os_:
                o.hide_render = other != name
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c = (lo + hi) / 2
        r = (hi - lo).length / 2
        d = Vector((0.75, 1.0, 0.42)).normalized()
        cam.location = c + d * r * 3.0
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{OUT}/{name}.png"
        bpy.ops.render.render(write_still=True)


main()
