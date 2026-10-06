import bpy, math, sys
from mathutils import Matrix, Vector
parts_file, outdir = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
mats = {}
def mat(rgb, alpha):
    key = (rgb, alpha)
    if key in mats: return mats[key]
    m = bpy.data.materials.new("m%d" % len(mats))
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(((c/255) ** 2.2) for c in rgb)
    b.inputs["Base Color"].default_value = (*lin, 1); b.inputs["Roughness"].default_value = 0.75
    if alpha: b.inputs["Alpha"].default_value = 1 - alpha
    mats[key] = m; return m
R2B = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
BEE = {"bee1": (1.5, 0.5, -0.9), "bee2": (-1.6, 0.9, -0.5), "bee3": (0.5, 1.3, -1.5)}
groups = {}
for line in open(parts_file):
    f = line.split(); n, bone, shape = f[0], f[1], f[2]
    sx, sy, sz, px, py, pz = map(float, f[3:9]); rgb = tuple(map(int, f[9:12])); rx, ry, rz, alpha = map(float, f[12:16])
    if bone in BEE:
        dx, dy, dz = BEE[bone]; px += dx; py += dy; pz += dz
    if shape == "Ellipsoid":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=0.5)
        o = bpy.context.object
        for poly in o.data.polygons: poly.use_smooth = True
    elif shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1)
        o = bpy.context.object
        for poly in o.data.polygons: poly.use_smooth = True
        bev = o.modifiers.new("b", "BEVEL"); bev.width = 0.04; bev.segments = 3
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.object
        bev = o.modifiers.new("b", "BEVEL"); bev.width = 0.03; bev.segments = 2
    rot = Matrix.Rotation(math.radians(rx),4,'X') @ Matrix.Rotation(math.radians(ry),4,'Y') @ Matrix.Rotation(math.radians(rz),4,'Z')
    base = Matrix.Rotation(math.radians(90),4,'Y') if shape == 'Cylinder' else Matrix.Identity(4)
    o.matrix_world = R2B @ Matrix.Translation((px,py,pz)) @ rot @ Matrix.Diagonal((sx,sy,sz,1)) @ base
    o.data.materials.append(mat(rgb, alpha))
    groups.setdefault(n, []).append(o)
bpy.ops.mesh.primitive_plane_add(size=60)
bpy.context.object.data.materials.append(mat((120,125,130), 0))
bpy.ops.object.camera_add(); cam = bpy.context.object; scene.camera = cam; cam.data.lens = 50
lights = []
for loc, e in [((-6,8,10),900),((8,6,5),500),((0,-8,6),600)]:
    bpy.ops.object.light_add(type='AREA', location=loc); l = bpy.context.object
    l.data.energy = e; l.data.size = 6
    l.rotation_euler = (Vector((0,0,1)) - l.location).to_track_quat('-Z','Y').to_euler()
scene.world = bpy.data.worlds.new("w"); scene.world.color = (0.32,0.33,0.35)
scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 24; scene.cycles.use_denoising = False
scene.render.resolution_x = 480; scene.render.resolution_y = 480
scene.view_settings.look = 'AgX - Base Contrast'
for n, objs in groups.items():
    for m, os_ in groups.items():
        for o in os_: o.hide_render = (m != n)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2; r = (hi - lo).length / 2
    d = Vector((0.75, 1.0, 0.42)).normalized()
    cam.location = c + d * r * 3.1
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = f"{outdir}/{n}.png"
    bpy.ops.render.render(write_still=True)
