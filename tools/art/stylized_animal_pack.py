
import bpy, math
from mathutils import Vector

# ============================================================
# ROBLOX FARM ANIMAL PACK - procedural Blender generator
# Stylized low-poly / smooth, deliberately NOT voxel/cubical
# Blender 4.x
# ============================================================

# ---------- cleanup ----------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass

# ---------- materials ----------
def mat(name, color, rough=0.82):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.roughness = rough
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = rough
    return m

WHITE = mat("White", (0.92,0.92,0.88))
CREAM = mat("Cream", (0.88,0.80,0.64))
BLACK = mat("Black", (0.035,0.03,0.025))
DARK_BROWN = mat("DarkBrown", (0.20,0.09,0.035))
BROWN = mat("Brown", (0.40,0.18,0.07))
HORSE = mat("HorseBrown", (0.48,0.22,0.08))
ORANGE = mat("FoxOrange", (0.95,0.34,0.045))
CAT_ORANGE = mat("CatOrange", (0.93,0.43,0.08))
YELLOW = mat("BeeYellow", (1.0,0.66,0.04))
GOLD = mat("HiveGold", (0.93,0.56,0.06))
PINK = mat("Pink", (1.0,0.36,0.40))
SKIN = mat("Muzzle", (0.72,0.48,0.33))
EYE = mat("Eye", (0.012,0.012,0.012))
GREEN = mat("EyeGreen", (0.18,0.55,0.12))
RED = mat("CombRed", (0.82,0.06,0.045))
ORANGE2 = mat("BeakFeet", (1.0,0.48,0.04))
HIVE_DARK = mat("HiveWood", (0.34,0.17,0.055))
HIVE_LIGHT = mat("HiveBody", (0.96,0.61,0.08))
HIVE_TOP = mat("HiveTop", (0.46,0.25,0.09))
BLUE = mat("WingBlue", (0.60,0.80,0.92), 0.55)

# ---------- helpers ----------
def smooth(obj):
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj

def uv(name, loc, scale, material, seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o=bpy.context.object; o.name=name
    o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(o); o.data.materials.append(material)
    return o

def ico(name, loc, scale, material, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(o); o.data.materials.append(material)
    return o

def cube(name, loc, scale, material, bevel=0.12):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod=o.modifiers.new("SoftEdges","BEVEL"); mod.width=bevel; mod.segments=3
    o.data.materials.append(material)
    return o

def cyl(name, loc, radius, depth, material, vertices=12, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name; o.data.materials.append(material)
    bevel=o.modifiers.new("SoftEdges","BEVEL"); bevel.width=min(radius*0.22, depth*0.08); bevel.segments=2
    return o

def cone(name, loc, r1, r2, depth, material, vertices=12, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o=bpy.context.object; o.name=name; o.data.materials.append(material)
    return o

def eye_pair(ox, x, y, z, forward=0.0, material=EYE, size=.065):
    # animals face +Y
    return [uv("Eye", (ox+sx, y+forward, z), (size,size*0.55,size), material, 12, 8) for sx in (-x,x)]

def tail_cone(name, base, tip, r1, r2, material):
    a=Vector(base); b=Vector(tip); d=b-a
    o=cone(name, (a+b)/2, r1, r2, d.length, material, 12)
    o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    return o

def leg4(prefix, x, y, z, lx, ly, h, material, hoof=None, thin=False):
    r=.095 if thin else .13
    out=[]
    for i,sx in enumerate((-1,1)):
        for j,sy in enumerate((-1,1)):
            p=(x+sx*lx, y+sy*ly, z-h/2)
            out.append(cyl(f"{prefix}_Leg_{i}{j}",p,r,h,material,10))
            if hoof: out.append(uv(f"{prefix}_Hoof_{i}{j}",(p[0],p[1]+.025,p[2]-h/2),(r*1.15,r*1.4,r*.55),hoof,10,6))
    return out

def group_parent(objs, name):
    root=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(root)
    for o in objs: o.parent=root
    return root

# ---------- CHICKEN ----------
def chicken(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a.append(uv("Body",(ox,oy,oz+1.15),(0.62,0.78,0.60),WHITE))
    a.append(uv("Chest",(ox,oy+.58,oz+1.18),(0.42,0.30,0.48),WHITE))
    a.append(uv("Head",(ox,oy+.42,oz+1.78),(0.40,0.40,0.42),WHITE))
    a.append(cone("Beak",(ox,oy+.83,oz+1.75),.18,0,.28,ORANGE2,4,(math.radians(90),0,0)))
    a.append(uv("Comb",(ox,oy+.40,oz+2.17),(.18,.08,.20),RED))
    a.append(uv("Wattle",(ox,oy+.77,oz+1.48),(.10,.07,.16),RED))
    a += eye_pair(ox,.19,oy+.72,oz+1.84,0,EYE,.075)
    for sx in (-.26,.26):
        a.append(uv("Wing",(ox+sx,oy+.22,oz+1.22),(.25,.18,.38),WHITE))
    a += leg4("Chicken",ox,oy,oz+.60,.22,.17,.52,ORANGE2,None,True)
    for sx in (-.22,.22):
        a.append(cube("Toe",(ox+sx,oy+.13,oz+.14),(.13,.20,.035),ORANGE2,.025))
    return group_parent(a,"Chicken")

# ---------- DUCK ----------
def duck(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.02),(.68,.82,.55),WHITE),
          uv("Head",(ox,oy+.44,oz+1.62),(.43,.43,.43),WHITE)]
    a.append(cone("Bill",(ox,oy+.83,oz+1.56),.22,0,.38,ORANGE2,4,(math.radians(90),0,0)))
    a += eye_pair(ox,.20,oy+.76,oz+1.72,0,EYE,.07)
    for sx in (-.27,.27): a.append(uv("Wing",(ox+sx,oy+.16,oz+1.10),(.27,.20,.36),WHITE))
    a += leg4("Duck",ox,oy,oz+.50,.25,.16,.43,ORANGE2,None,True)
    return group_parent(a,"Duck")

# ---------- DOG ----------
def dog(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.05),(.72,.98,.58),HORSE),
          uv("Chest",(ox,oy+.67,oz+1.13),(.48,.42,.52),HORSE),
          uv("Head",(ox,oy+.75,oz+1.63),(.46,.48,.48),HORSE)]
    a.append(uv("Muzzle",(ox,oy+1.10,oz+1.53),(.28,.20,.23),CREAM))
    a += eye_pair(ox,.21,oy+1.05,oz+1.74,0,EYE,.075)
    a.append(uv("Nose",(ox,oy+1.29,oz+1.56),(.11,.08,.08),BLACK))
    for sx in (-.40,.40):
        a.append(uv("Ear",(ox+sx,oy+.70,oz+1.82),(.18,.16,.34),HORSE))
    a += leg4("Dog",ox,oy,oz+.56,.42,.27,.65,HORSE,BLACK)
    a.append(tail_cone("Tail",(ox,oy-.92,oz+1.30),(ox-.18,oy-1.35,oz+1.75),.13,.035,HORSE))
    return group_parent(a,"Dog")

# ---------- CAT ----------
def cat(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.05),(.63,.88,.50),CAT_ORANGE),
          uv("Head",(ox,oy+.67,oz+1.62),(.43,.43,.42),CAT_ORANGE)]
    for sx in (-.22,.22):
        a.append(cone("Ear",(ox+sx,oy+.62,oz+2.02),.18,0,.42,CAT_ORANGE,4))
        a.append(cone("InnerEar",(ox+sx,oy+.62,oz+2.03),.09,0,.27,PINK,4))
    a += eye_pair(ox,.19,oy+1.00,oz+1.70,0,GREEN,.075)
    a.append(uv("Nose",(ox,oy+1.11,oz+1.56),(.06,.05,.05),PINK))
    for i,sx in enumerate((-1,1)):
        a.append(uv("Leg",(ox+sx*.36,oy+.34,oz+.56),(.14,.14,.52),CAT_ORANGE))
        a.append(uv("Leg",(ox+sx*.36,oy-.34,oz+.56),(.14,.14,.52),CAT_ORANGE))
    # curved-ish tail as segments
    pts=[(ox,oy-.83,oz+1.30),(ox-.10,oy-1.15,oz+1.65),(ox-.02,oy-1.30,oz+2.00)]
    for i in range(2): a.append(tail_cone("Tail",(pts[i]),pts[i+1],.10,.07,CAT_ORANGE))
    return group_parent(a,"Cat")

# ---------- COW ----------
def cow(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.20),(0.82,1.02,.62),WHITE),
          uv("Head",(ox,oy+.88,oz+1.70),(.48,.50,.48),WHITE),
          uv("Muzzle",(ox,oy+1.20,oz+1.58),(.30,.20,.20),PINK)]
    a += eye_pair(ox,.22,oy+1.14,oz+1.78,0,EYE,.06)
    for sx in (-.48,.48):
        a.append(uv("Horn",(ox+sx*.5,oy+.92,oz+2.08),(.08,.08,.24),CREAM))
        a.append(uv("Ear",(ox+sx*.47,oy+.82,oz+1.94),(.16,.10,.11),BLACK))
    for sx,sy in [(-.47,-.45),(.47,-.45),(-.47,.42),(.47,.42)]:
        a.append(uv("Leg",(ox+sx,oy+sy,oz+.62),(.15,.15,.62),WHITE))
        a.append(uv("Hoof",(ox+sx,oy+sy+.04,oz+.18),(.17,.19,.10),BLACK))
    for p in [(-.30,-.30,1.63),(.25,-.15,1.45),(-.20,.20,1.55)]:
        a.append(uv("Spot",(ox+p[0],oy+p[1],oz+p[2]),(.18,.10,.14),BLACK,12,8))
    a.append(tail_cone("Tail",(ox,oy-.96,oz+1.55),(ox+.05,oy-1.18,oz+1.30),.07,.035,BLACK))
    return group_parent(a,"Cow")

# ---------- GOAT ----------
def goat(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.16),(.68,.95,.52),CREAM),
          uv("Head",(ox,oy+.77,oz+1.70),(.40,.42,.43),CREAM),
          uv("Muzzle",(ox,oy+1.06,oz+1.60),(.24,.17,.17),CREAM)]
    a += eye_pair(ox,.18,oy+1.04,oz+1.79,0,EYE,.06)
    for sx in (-.20,.20):
        a.append(tail_cone("Horn",(ox+sx*.8,oy+.78,oz+2.00),(ox+sx*.72,oy+.76,oz+2.38),.10,.025,DARK_BROWN))
    for sx,sy in [(-.40,-.38),(.40,-.38),(-.40,.38),(.40,.38)]:
        a.append(cyl("Leg",(ox+sx,oy+sy,oz+.55),.105,.72,CREAM,10))
        a.append(uv("Hoof",(ox+sx,oy+sy+.03,oz+.17),(.12,.14,.07),BLACK))
    a.append(uv("Beard",(ox,oy+1.05,oz+1.37),(.12,.08,.22),CREAM))
    a.append(tail_cone("Tail",(ox,oy-.88,oz+1.48),(ox,oy-1.06,oz+1.73),.06,.025,CREAM))
    return group_parent(a,"Goat")

# ---------- SHEEP ----------
def sheep(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a.append(uv("Body",(ox,oy,oz+1.25),(.80,1.00,.66),WHITE,20,12))
    # wool clumps
    for x in (-.45,0,.45):
        for y in (-.55,0,.55):
            a.append(uv("Wool",(ox+x,oy+y,oz+1.38),( .32,.32,.30),WHITE,12,8))
    a += [uv("Head",(ox,oy+.88,oz+1.62),(.38,.40,.45),BLACK),
          uv("Muzzle",(ox,oy+1.16,oz+1.56),(.22,.15,.16),BLACK)]
    a += eye_pair(ox,.17,oy+1.10,oz+1.75,0,WHITE,.055)
    for sx in (-.42,.42):
        a.append(uv("Ear",(ox+sx,oy+.90,oz+1.70),(.16,.07,.09),BLACK))
    a += leg4("Sheep",ox,oy,oz+.62,.40,.37,.72,BLACK)
    return group_parent(a,"Sheep")

# ---------- RABBIT ----------
def rabbit(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.0),(.57,.70,.55),BROWN),
          uv("Head",(ox,oy+.60,oz+1.52),(.40,.40,.40),BROWN),
          uv("Chest",(ox,oy+.70,oz+1.10),(.40,.30,.45),CREAM)]
    for sx in (-.18,.18):
        a.append(uv("Ear",(ox+sx,oy+.60,oz+2.05),(.12,.13,.52),BROWN))
        a.append(uv("InnerEar",(ox+sx,oy+.72,oz+2.05),(.055,.045,.35),PINK))
    a += eye_pair(ox,.18,oy+.94,oz+1.61,0,EYE,.065)
    a.append(uv("Nose",(ox,oy+1.00,oz+1.48),(.055,.045,.05),PINK))
    for sx in (-.36,.36):
        a.append(uv("Leg",(ox+sx,oy+.30,oz+.52),(.13,.13,.48),BROWN))
    a.append(uv("Tail",(ox,oy-.72,oz+1.20),(.20,.20,.20),WHITE))
    return group_parent(a,"Rabbit")

# ---------- HORSE ----------
def horse(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.30),(0.76,1.12,.65),HORSE),
          uv("Neck",(ox,oy+.55,oz+1.75),(.42,.52,.90),HORSE),
          uv("Head",(ox,oy+.85,oz+2.28),(.42,.55,.45),HORSE),
          uv("Muzzle",(ox,oy+1.22,oz+2.20),(.27,.22,.22),CREAM)]
    a += eye_pair(ox,.20,oy+1.17,oz+2.38,0,EYE,.06)
    for sx in (-.17,.17):
        a.append(cone("Ear",(ox+sx,oy+.86,oz+2.68),.11,0,.28,HORSE,4))
    # mane
    for i in range(5):
        z=oz+1.75+i*.18
        a.append(uv("Mane",(ox-.35,oy+.50, z),(.10,.10,.18),BLACK,10,6))
    a += leg4("Horse",ox,oy,oz+.65,.43,.48,.95,HORSE,BLACK)
    a.append(tail_cone("Tail",(ox,oy-.98,oz+1.55),(ox,oy-1.25,oz+.90),.15,.035,BLACK))
    return group_parent(a,"Horse")

# ---------- BEE ----------
def bee(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.10),(.45,.75,.42),YELLOW),
          uv("Head",(ox,oy+.68,oz+1.13),(.36,.36,.34),BLACK)]
    for yy in (-.25,.05,.35):
        a.append(cyl("Stripe",(ox,oy+yy,oz+1.10),.43,.10,BLACK,16,(math.radians(90),0,0)))
    a += eye_pair(ox,.15,oy+1.00,oz+1.22,0,BLACK,.06)
    for sx in (-.28,.28):
        a.append(uv("Wing",(ox+sx*.9,oy+.05,oz+1.42),(.30,.50,.06),BLUE,16,8))
    for sx in (-.20,0,.20):
        a.append(cyl("Leg",(ox+sx,oy-.05,oz+.72),.035,.35,BLACK,8))
    for sx in (-.15,.15):
        a.append(cyl("Antenna",(ox+sx,oy+.82,oz+1.48),.025,.25,BLACK,8))
    return group_parent(a,"Bee")

# ---------- BEE HIVE ----------
def hive(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    for i,z in enumerate((.45, .90, 1.35)):
        a.append(cube(f"HiveBox_{i}",(ox,oy,oz+z),(.62,.62,.22),HIVE_LIGHT,.10))
    a.append(cube("HiveRoof",(ox,oy,oz+1.72),(.76,.76,.16),HIVE_TOP,.10))
    a.append(cube("HiveBase",(ox,oy,oz+.20),(.70,.70,.12),HIVE_DARK,.05))
    # entrance
    a.append(cube("HiveEntrance",(ox,oy+.635,oz+.82),(.16,.045,.12),BLACK,.04))
    return group_parent(a,"Bee_Hive")

# ---------- FOX ----------
def fox(origin=(0,0,0)):
    ox,oy,oz=origin; a=[]
    a += [uv("Body",(ox,oy,oz+1.05),(.62,.95,.48),ORANGE),
          uv("Head",(ox,oy+.78,oz+1.60),(.42,.42,.42),ORANGE),
          uv("Muzzle",(ox,oy+1.10,oz+1.52),(.25,.20,.19),WHITE)]
    a += eye_pair(ox,.19,oy+1.05,oz+1.72,0,EYE,.065)
    for sx in (-.22,.22):
        a.append(cone("Ear",(ox+sx,oy+.72,oz+2.02),.18,0,.40,ORANGE,4))
        a.append(cone("InnerEar",(ox+sx,oy+.83,oz+2.02),.08,0,.25,PINK,4))
    a += leg4("Fox",ox,oy,oz+.56,.38,.34,.64,BLACK)
    # orange upper legs over black feet
    for sx in (-.38,.38):
        for sy in (-.34,.34):
            a.append(uv("UpperLeg",(ox+sx,oy+sy,oz+.68),(.15,.15,.35),ORANGE))
    # big segmented tail
    a.append(tail_cone("Tail",(ox,oy-.85,oz+1.30),(ox,oy-1.28,oz+1.62),.22,.12,ORANGE))
    a.append(tail_cone("TailTip",(ox,oy-1.28,oz+1.62),(ox,oy-1.43,oz+1.70),.14,.025,WHITE))
    return group_parent(a,"Fox")

# ---------- arrange ----------
# Large spacing so every asset can be selected/exported independently.
animals = [
    chicken((-9,  5,0)),
    duck   ((-3,  5,0)),
    dog    (( 3,  5,0)),
    cat    (( 9,  5,0)),
    cow    ((-9, -2,0)),
    goat   ((-3, -2,0)),
    sheep  (( 3, -2,0)),
    rabbit (( 9, -2,0)),
    horse  ((-7, -9,0)),
    bee    ((-1, -9,0)),
    hive   (( 3.5,-9,0)),
    fox    (( 9, -9,0)),
]

# ---------- ground ----------
bpy.ops.mesh.primitive_plane_add(size=50, location=(0,0,0))
ground=bpy.context.object; ground.name="Preview_Ground"; ground.data.materials.append(mat("Ground",(0.055,0.065,0.075)))

# ---------- camera ----------
bpy.ops.object.camera_add(location=(0,29,17))
cam=bpy.context.object
cam.rotation_euler=(math.radians(66),0,0)
# point camera at center
target=Vector((0,-2,1.2))
direction=target-cam.location
cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
bpy.context.scene.camera=cam
cam.data.lens=48

# ---------- lighting ----------
bpy.ops.object.light_add(type='AREA', location=(-8,-10,18))
key=bpy.context.object; key.name="Key"; key.data.energy=1700; key.data.shape='DISK'; key.data.size=8
bpy.ops.object.light_add(type='AREA', location=(10,-4,10))
fill=bpy.context.object; fill.name="Fill"; fill.data.energy=1000; fill.data.size=7
bpy.ops.object.light_add(type='AREA', location=(0,10,12))
rim=bpy.context.object; rim.name="Rim"; rim.data.energy=1200; rim.data.size=6

# ---------- render ----------
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=24; scene.cycles.use_denoising=False
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath='//roblox_animal_pack_preview.png'
scene.world.color=(0.025,0.03,0.04)

# color management
scene.view_settings.look='AgX - Medium High Contrast'

# select roots
bpy.ops.object.select_all(action='DESELECT')
for o in animals:
    o.select_set(True)

# save
bpy.ops.wm.save_as_mainfile(filepath='//Roblox_Stylized_Animal_Pack.blend')
bpy.ops.render.render(write_still=True)
print("DONE: Roblox_Stylized_Animal_Pack.blend")
