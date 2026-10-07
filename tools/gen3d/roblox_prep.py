"""Cleans a generated GLB for Roblox with Blender (Windows or Linux).

    blender -b -P roblox_prep.py -- IN.glb OUT.glb [--tris 8000] [--texture 1024]
                                    [--height 2.4] [--yaw 0] [--preview OUT.png]

Also works with the `bpy` Python package:  python roblox_prep.py -- IN.glb OUT.glb

What it does:
  * joins everything into one mesh, removes duplicate vertices, fixes normals
  * reduces it to --tris triangles (Roblox meshes are limited in size and
    phones need light models; 5-10k is plenty for an animal)
  * shrinks every texture to --texture pixels (Roblox shows at most 1024)
  * stands the model on the ground, centred, facing forward (-Z in Roblox),
    --yaw turns it if the generator faced it another way
  * scales it to --height (the size you want in game, in studs; check in
    Studio and use Model:ScaleTo if the importer reads units differently)
  * exports a GLB with PNG textures, and with --preview renders a quick
    front/side picture so you can check the facing before importing
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def opt(name, default, cast=float):
    if name in argv:
        return cast(argv[argv.index(name) + 1])
    return default


positional = [a for i, a in enumerate(argv) if not a.startswith("--") and (i == 0 or not argv[i - 1].startswith("--"))]
SRC, DST = positional[0], positional[1]
TRIS = opt("--tris", 8000, int)
TEX = opt("--texture", 1024, int)
HEIGHT = opt("--height", 2.4)
YAW = opt("--yaw", 0.0)
PREVIEW = opt("--preview", None, str)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("no mesh in " + SRC)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.object
obj.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)

# clean up
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

# reduce triangles (keeps UVs, so the texture still fits)
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = TRIS / tris
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
for p in obj.data.polygons:
    p.use_smooth = True

# shrink textures and save them as PNG
for img in bpy.data.images:
    if img.size[0] > TEX or img.size[1] > TEX:
        img.scale(min(TEX, img.size[0]), min(TEX, img.size[1]))
    img.file_format = "PNG"

# facing, ground, centre, size (Blender is Z-up; glTF export turns it to Y-up)
obj.rotation_euler = (0, 0, math.radians(YAW))
bpy.ops.object.transform_apply(rotation=True)
pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
s = HEIGHT / max(hi.z - lo.z, 1e-6)
obj.location = (-(lo.x + hi.x) / 2 * s, -(lo.y + hi.y) / 2 * s, -lo.z * s)
obj.scale = (s, s, s)
bpy.ops.object.transform_apply(location=True, scale=True)
obj.name = obj.data.name = "Model"

final = sum(len(p.vertices) - 2 for p in obj.data.polygons)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", export_image_format="AUTO", use_selection=False)
print(f"{SRC} -> {DST}: {tris} -> {final} triangles, height {HEIGHT}", flush=True)

if PREVIEW:
    scene = bpy.context.scene
    import ctypes
    import ctypes.util

    def has_gl():
        if sys.platform != "linux":
            return True
        try:
            ctypes.CDLL(ctypes.util.find_library("EGL") or "libEGL.so.1")
            return True
        except OSError:
            return False

    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 1024, 512
    scene.render.film_transparent = True
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = HEIGHT * 2.3
    scene.camera = cam
    # front (the model should look at you) then side
    import os
    base, ext = os.path.splitext(PREVIEW)
    for tag, loc in (("front", (0, HEIGHT * 4, HEIGHT / 2)), ("side", (HEIGHT * 4, 0, HEIGHT / 2))):
        cam.location = loc
        cam.rotation_euler = (Vector((0, 0, HEIGHT / 2)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{base}_{tag}{ext or '.png'}"
        if not has_gl():  # headless server without OpenGL: slower, CPU only
            scene.render.engine = "CYCLES"
            scene.cycles.device = "CPU"
            scene.cycles.samples = 16
            scene.world = scene.world or bpy.data.worlds.new("w")
            scene.world.color = (0.9, 0.9, 0.9)
            if not any(o.type == "LIGHT" for o in scene.objects):
                bpy.ops.object.light_add(type="SUN", rotation=(0.8, 0.2, 0.6))
                bpy.context.object.data.energy = 4
                scene.camera = cam
        bpy.ops.render.render(write_still=True)
