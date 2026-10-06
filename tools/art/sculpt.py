"""Builds the sculpted animals from models.py in Blender.

    python -I tools/art/sculpt.py OUT_DIR [Chicken Duck ...] [--render] [--export]

--render writes OUT_DIR/<Animal>_front.png and _side.png,
--export writes OUT_DIR/<Animal>.glb (vertex colours, one mesh per bone).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  (must come before bmesh)
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from models import MODELS  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0]
NAMES = args[1:] or list(MODELS)
RENDER = "--render" in sys.argv
EXPORT = "--export" in sys.argv
TARGET_TRIS = 9000


def to_blender(v):
    """Roblox studs (x, y, z), facing -Z  ->  Blender (x, -z, y), facing +Y."""
    v = np.asarray(v, float)
    return np.stack([v[:, 0], -v[:, 2], v[:, 1]], axis=1)


def linear(rgb):
    return np.power(np.asarray(rgb, float) / 255.0, 2.2)


def make_mesh(name, verts, faces, colors):
    me = bpy.data.meshes.new(name)
    me.from_pydata(to_blender(verts).tolist(), [], faces.tolist())
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    lin = linear(colors)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.concatenate([lin, np.ones((len(lin), 1))], axis=1).astype(np.float32).ravel())
    for poly in me.polygons:
        poly.use_smooth = True
    return o


def apply(o, kind, **props):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(mod, k, v)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def detail_mesh(part):
    s = part.shape
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=1)
    o = bpy.context.object
    # the same rotation, expressed in Blender's axes
    basis = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    rotm = basis @ Matrix(np.asarray(s.m).tolist())
    c = to_blender([s.c])[0]
    o.matrix_world = Matrix.Translation(Vector(c)) @ rotm.to_4x4() @ Matrix.Diagonal((*s.r, 1))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    n = len(o.data.vertices)
    lin = linear([part.color] * n)
    attr = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.concatenate([lin, np.ones((n, 1))], axis=1).astype(np.float32).ravel())
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def build(name):
    model = MODELS[name]()
    verts, faces, colors, bones = model.mesh()
    o = make_mesh(name, verts, faces, colors)
    apply(o, "LAPLACIANSMOOTH", iterations=1, lambda_factor=0.35)
    tris = len(o.data.polygons)
    if tris > TARGET_TRIS:
        apply(o, "DECIMATE", ratio=TARGET_TRIS / tris)
    o["bones"] = ",".join(sorted(set(bones)))
    pieces = [o] + [detail_mesh(p) for p in model.details]
    print(f"{name}: {len(o.data.polygons)} body triangles, {len(model.details)} detail pieces")
    return pieces


def material():
    m = bpy.data.materials.new("Animal")
    nodes = m.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    vc = nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    m.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Coat Weight"].default_value = 0.08
    return m


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.resolution_x = scene.render.resolution_y = 560
    scene.view_settings.look = "AgX - Base Contrast"
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.62, 0.6, 0.58)
    bpy.ops.mesh.primitive_plane_add(size=60)
    floor = bpy.context.object
    fm = bpy.data.materials.new("floor")
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.56, 1)
    floor.data.materials.append(fm)
    for loc, energy, size in [((-4, 6, 7), 800, 5), ((6, 3, 4), 380, 5), ((0, -6, 5), 450, 5)]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.data.energy = energy
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.lens = 60
    scene.camera = cam
    return scene, cam


def render(scene, cam, built):
    for name, objs in built.items():
        for other, os_ in built.items():
            for o in os_:
                o.hide_render = other != name
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c = (lo + hi) / 2
        r = (hi - lo).length / 2
        for view, d in (("front", Vector((0.9, 0.75, 0.3))), ("side", Vector((1.0, 0.05, 0.12)))):
            cam.location = c + d.normalized() * r * 3.0
            cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = f"{OUT}/{name}_{view}.png"
            bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = material()
    built = {}
    for name in NAMES:
        objs = build(name)
        for o in objs:
            o.data.materials.append(mat)
        built[name] = objs
    if EXPORT:
        for name, objs in built.items():
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.ops.export_scene.gltf(filepath=f"{OUT}/{name}.glb", use_selection=True, export_format="GLB")
    if RENDER:
        scene, cam = setup_scene()
        render(scene, cam, built)


main()
