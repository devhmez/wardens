# Generates every 3D model for WARDENS as .glb files.
# Run:  /Applications/Blender.app/Contents/MacOS/Blender --background --python blender/make_assets.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler, noise

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- helpers
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def hexcol(h):
    h = h.lstrip("#")
    return (lin(int(h[0:2], 16) / 255), lin(int(h[2:4], 16) / 255), lin(int(h[4:6], 16) / 255), 1.0)

_mats = {}
def mat(name, h):
    key = name + h
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    col = hexcol(h)
    m.diffuse_color = col
    try:
        m.use_nodes = True
    except Exception:
        pass
    if m.node_tree:
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = col
                n.inputs["Roughness"].default_value = 0.9
    _mats[key] = m
    return m

def wipe():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)

def export(name):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True,
                              export_apply=True, export_animations=False)
    print("exported", path)
    wipe()

class Part:
    """Accumulates primitives into one mesh with several material slots."""
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _finish(self, verts, m, center, rot):
        if rot:
            bmesh.ops.rotate(self.bm, verts=verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
        c = Vector(center)
        for v in verts:
            v.co += c
        mi = self._mi(m)
        faces = set()
        for v in verts:
            for f in v.link_faces:
                faces.add(f)
        for f in faces:
            f.material_index = mi
        return verts

    def sphere(self, m, center, scale, seg=14, rings=9, taper=0.0, rot=None):
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)
        verts = r["verts"]
        for v in verts:
            k = 1.0 + taper * v.co.z
            v.co.x *= scale[0] * k
            v.co.y *= scale[1] * k
            v.co.z *= scale[2]
        return self._finish(verts, m, center, rot)

    def cone(self, m, base, r1, r2, depth, seg=12, caps=True, rot=None):
        r = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg,
                                  radius1=r1, radius2=r2, depth=depth)
        verts = r["verts"]
        for v in verts:
            v.co.z += depth / 2
        return self._finish(verts, m, base, rot)

    def box(self, m, center, size, rot=None):
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = r["verts"]
        for v in verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
        return self._finish(verts, m, center, rot)

    def ico(self, m, center, scale, sub=2, jitter=0.0, seed=0, rot=None):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0)
        verts = r["verts"]
        for v in verts:
            if jitter:
                o = Vector((seed * 3.1, seed * 1.3, seed * 7.7))
                n = noise.noise(v.co * 1.7 + o) + 0.45 * noise.noise(v.co * 4.3 + o) + 0.2 * noise.noise(v.co * 9.1 + o)
                v.co *= 1.0 + n * jitter
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
        return self._finish(verts, m, center, rot)

    def delete(self, verts):
        bmesh.ops.delete(self.bm, geom=verts, context="VERTS")

    def build(self, parent=None, loc=(0, 0, 0), smooth=True, sharp=None):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        if sharp:
            me.set_sharp_from_angle(angle=math.radians(sharp))
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if parent:
            ob.parent = parent
        ob.location = loc
        return ob

# ---------------------------------------------------------------- characters
def character(name, pal, hair="short", build=1.0, extras=()):
    skin = mat("skin", pal["skin"])
    c1 = mat("cloth1", pal["c1"])
    c2 = mat("cloth2", pal["c2"])
    c3 = mat("trim", pal["trim"])
    hairm = mat("hair", pal["hair"])
    boot = mat("boot", pal["boot"])
    eye = mat("eyeglow" if "glow" in extras else "eye", pal.get("eye", "#1b1b22"))
    b = build

    # hips
    p = Part("Hips")
    p.sphere(c2, (0, 0, 0), (0.17 * b, 0.13 * b, 0.13))
    p.cone(c1, (0, 0, -0.17), 0.235 * b, 0.165 * b, 0.22, seg=14, caps=False)
    p.sphere(c3, (0, 0, 0.06), (0.185 * b, 0.145 * b, 0.045))          # belt
    if "sash" in extras:
        p.box(c3, (0.07 * b, -0.13 * b, -0.1), (0.07, 0.03, 0.26), rot=(0.1, 0, 0.06))
    hips = p.build(None, (0, 0, 0.93))

    # torso
    p = Part("Torso")
    p.sphere(c1, (0, 0, 0.2), (0.2 * b, 0.135 * b, 0.25), taper=0.28)
    p.sphere(c1, (0, 0, 0.37), (0.25 * b, 0.12 * b, 0.075))            # shoulders
    p.sphere(c2, (0, -0.02, 0.26), (0.13 * b, 0.125 * b, 0.17))        # chest wrap
    if "scarf" in extras:
        p.sphere(c3, (0, 0, 0.44), (0.17, 0.16, 0.07))
        p.box(c3, (-0.1, 0.15, 0.3), (0.09, 0.03, 0.34), rot=(-0.25, 0, 0.1))
    if "pads" in extras:
        for sx in (-1, 1):
            p.sphere(c3, (sx * 0.27 * b, 0, 0.41), (0.12, 0.11, 0.07), rot=(0, sx * 0.35, 0))
    if "spikes" in extras:
        for sx in (-1, 1):
            p.sphere(c3, (sx * 0.28 * b, 0, 0.42), (0.13, 0.12, 0.08), rot=(0, sx * 0.35, 0))
            p.cone(c3, (sx * 0.3 * b, 0, 0.44), 0.05, 0.0, 0.26, seg=6, rot=(0, sx * 0.7, 0))
    if "cape" in extras:
        p.box(c2, (0, 0.14, 0.02), (0.44 * b, 0.03, 0.8), rot=(-0.12, 0, 0))
    torso = p.build(hips, (0, 0, 0.05))

    # head
    p = Part("Head")
    hz = 0.2
    p.cone(skin, (0, 0, -0.03), 0.06, 0.06, 0.1, seg=10)               # neck
    if "mask" in extras:
        p.sphere(c1, (0, 0.01, hz), (0.2, 0.2, 0.21))                  # hood
        p.sphere(mat("mask", pal.get("mask", "#d9d2c0")), (0, -0.1, hz - 0.01), (0.15, 0.12, 0.18))
        for sx in (-1, 1):
            p.sphere(eye, (sx * 0.065, -0.205, hz + 0.02), (0.036, 0.02, 0.014), rot=(0, sx * 0.35, 0))
        if "horns" in extras:
            for sx in (-1, 1):
                p.cone(mat("mask", pal.get("mask", "#d9d2c0")), (sx * 0.13, -0.02, hz + 0.13),
                       0.045, 0.0, 0.3, seg=6, rot=(0, sx * 0.55, 0))
        if "crown" in extras:
            for i in range(5):
                a = -0.9 + i * 0.45
                p.cone(c3, (math.sin(a) * 0.15, -math.cos(a) * 0.12, hz + 0.15), 0.04, 0.0,
                       0.2 + (0.1 if i == 2 else 0), seg=5)
    else:
        p.sphere(skin, (0, 0, hz), (0.19, 0.19, 0.2))
        for sx in (-1, 1):
            p.sphere(eye, (sx * 0.075, -0.172, hz + 0.01), (0.027, 0.016, 0.042))
            p.sphere(mat("white", "#ffffff"), (sx * 0.068, -0.186, hz + 0.028), (0.008, 0.005, 0.01))
            p.box(hairm, (sx * 0.078, -0.178, hz + 0.075), (0.07, 0.014, 0.016), rot=(0, sx * -0.22, 0))
            p.sphere(skin, (sx * 0.19, 0, hz), (0.03, 0.04, 0.05))     # ears
        if hair != "hood":
            cap = p.sphere(hairm, (0, 0.012, hz + 0.012), (0.207, 0.212, 0.215), seg=16, rings=10)
            kill = [v for v in cap if v.co.y < -0.06 and v.co.z < hz + 0.085]
            p.delete(kill)
        if hair == "short":
            for i, (x, y, z, rx, ry) in enumerate([(0, -0.1, 0.19, -0.9, 0), (0.09, -0.07, 0.17, -0.7, 0.5),
                                                  (-0.09, -0.07, 0.17, -0.7, -0.5), (0, 0.03, 0.2, 0.2, 0),
                                                  (0.1, 0.06, 0.16, 0.5, 0.7), (-0.1, 0.06, 0.16, 0.5, -0.7)]):
                p.cone(hairm, (x, y, hz + z - 0.03), 0.07, 0.0, 0.16, seg=6, rot=(rx, ry, 0))
            p.sphere(c3, (0, 0.012, hz + 0.1), (0.212, 0.216, 0.03))   # headband
        elif hair == "topknot":
            p.sphere(hairm, (0, 0.04, hz + 0.27), (0.075, 0.075, 0.085))
            p.cone(c3, (0, 0.04, hz + 0.19), 0.05, 0.05, 0.035, seg=10)
            p.cone(hairm, (0, -0.15, hz + 0.1), 0.05, 0.0, 0.14, seg=5, rot=(-2.3, 0, 0.2))
        elif hair == "braid":
            for i in range(6):
                p.sphere(hairm, (0, 0.2 + i * 0.012, hz - 0.02 - i * 0.105), (0.06 - i * 0.006, 0.055 - i * 0.005, 0.07))
            p.sphere(c3, (0, 0.265, hz - 0.6), (0.035, 0.035, 0.04))
            p.sphere(hairm, (0.12, -0.13, hz + 0.02), (0.035, 0.03, 0.13))
            p.sphere(hairm, (-0.12, -0.13, hz + 0.02), (0.035, 0.03, 0.13))
        elif hair == "ponytail":
            p.sphere(hairm, (0, 0.2, hz + 0.12), (0.06, 0.07, 0.06))
            p.sphere(hairm, (0, 0.3, hz - 0.02), (0.05, 0.06, 0.2), taper=-0.5, rot=(0.5, 0, 0))
            p.cone(hairm, (0.05, -0.16, hz + 0.1), 0.06, 0.0, 0.15, seg=5, rot=(-2.2, 0.3, 0))
        elif hair == "hood":
            hood = p.sphere(c2, (0, 0.02, hz + 0.01), (0.225, 0.235, 0.235), seg=16, rings=10)
            kill = [v for v in hood if v.co.y < -0.1 and abs(v.co.z - hz) < 0.15 and abs(v.co.x) < 0.17]
            p.delete(kill)
            p.cone(c2, (0, 0.17, hz + 0.12), 0.1, 0.0, 0.22, seg=7, rot=(1.9, 0, 0))
            p.cone(hairm, (0.04, -0.15, hz + 0.1), 0.06, 0.0, 0.13, seg=5, rot=(-2.2, 0.3, 0))
    head = p.build(torso, (0, 0, 0.44))

    # arms
    for side, sx in (("L", 1), ("R", -1)):
        p = Part("UpperArm" + side)
        p.sphere(c1, (0, 0, -0.14), (0.068 * b, 0.068 * b, 0.17), taper=-0.15)
        ua = p.build(torso, (sx * 0.265 * b, 0, 0.36))
        p = Part("LowerArm" + side)
        p.sphere(skin, (0, 0, -0.13), (0.055 * b, 0.055 * b, 0.16), taper=-0.2)
        p.cone(c3, (0, 0, -0.24), 0.056 * b, 0.064 * b, 0.13, seg=10)   # bracer
        p.sphere(skin, (0, 0, -0.3), (0.058 * b, 0.05 * b, 0.065))      # hand
        p.build(ua, (0, 0, -0.28))

    # legs
    for side, sx in (("L", 1), ("R", -1)):
        p = Part("UpperLeg" + side)
        p.sphere(c2, (0, 0, -0.2), (0.092 * b, 0.092 * b, 0.25), taper=-0.2)
        ul = p.build(hips, (sx * 0.1 * b, 0, -0.06))
        p = Part("LowerLeg" + side)
        p.sphere(c2, (0, 0, -0.17), (0.074 * b, 0.074 * b, 0.21), taper=-0.2)
        p.cone(boot, (0, 0, -0.4), 0.062 * b, 0.08 * b, 0.24, seg=10)
        p.sphere(boot, (0, -0.05, -0.4), (0.075 * b, 0.14, 0.055))
        p.build(ul, (0, 0, -0.42))
    export(name)

CHARS = {
    "warden_earth": (dict(skin="#c98e62", c1="#4f7a3a", c2="#d8c690", trim="#8a5a2b", hair="#2a1d14", boot="#5b3a22"),
                     "short", 1.14, ("pads", "sash")),
    "warden_fire": (dict(skin="#e0a476", c1="#b3261e", c2="#2b2326", trim="#e9b03c", hair="#17110f", boot="#2b2326"),
                    "topknot", 1.0, ("pads",)),
    "warden_water": (dict(skin="#b97b55", c1="#2f6fb5", c2="#e8f1f7", trim="#8fd3e8", hair="#3a2618", boot="#27425f"),
                     "braid", 0.94, ("sash",)),
    "warden_air": (dict(skin="#f0c9a0", c1="#f2efe6", c2="#2f8f83", trim="#7fe0c8", hair="#dfe6ea", boot="#5a4a3a"),
                   "hood", 0.92, ("scarf",)),
    "ashen_grunt": (dict(skin="#6b6470", c1="#33303b", c2="#4a3f5c", trim="#7b4bd1", hair="#111111", boot="#1d1b22",
                         eye="#c070ff", mask="#d9d2c0"), "none", 1.0, ("mask", "glow")),
    "ashen_caster": (dict(skin="#6b6470", c1="#3d2a5c", c2="#2a2433", trim="#b06cff", hair="#111111", boot="#1d1b22",
                          eye="#ff70d0", mask="#cfc3e6"), "none", 0.9, ("mask", "glow", "scarf")),
    "ashen_brute": (dict(skin="#6b6470", c1="#2b2a30", c2="#51343a", trim="#c8472f", hair="#111111", boot="#1d1b22",
                         eye="#ff8a3c", mask="#b9b0a0"), "none", 1.32, ("mask", "glow", "horns", "spikes")),
    "ashen_king": (dict(skin="#6b6470", c1="#1c1a22", c2="#5a1f2c", trim="#d9a441", hair="#111111", boot="#141318",
                        eye="#ff3355", mask="#e8e0cf"), "none", 1.22, ("mask", "glow", "horns", "crown", "spikes", "cape")),
}

# ---------------------------------------------------------------- props
def rocks():
    stone = mat("rock", "#8d8478")
    for i in range(4):
        p = Part("Rock")
        p.ico(stone, (0, 0, 0), (0.5, 0.5, 0.5 * (0.8 + 0.1 * i)), sub=3, jitter=0.3, seed=i + 1)
        p.build(smooth=True, sharp=55)
        export("rock_%d" % i)
    # pillar raised by earth bending, origin at base
    p = Part("Pillar")
    vs = p.cone(stone, (0, 0, 0), 0.8, 0.6, 3.2, seg=7)
    for v in vs:
        n = noise.noise(v.co * 0.9)
        v.co.x += n * 0.22
        v.co.y += noise.noise(v.co * 0.9 + Vector((5, 1, 2))) * 0.22
        if v.co.z > 1.0:
            v.co.z += noise.noise(v.co * 2.0) * 0.5
    p.ico(stone, (0.5, 0.2, 0.3), (0.5, 0.45, 0.5), sub=1, jitter=0.4, seed=9)
    p.ico(stone, (-0.5, -0.3, 0.2), (0.45, 0.4, 0.4), sub=1, jitter=0.4, seed=4)
    p.build(smooth=False)
    export("pillar")
    p = Part("Spike")
    vs = p.cone(stone, (0, 0, 0), 0.55, 0.0, 2.6, seg=6)
    for v in vs:
        v.co.x += noise.noise(v.co * 1.3) * 0.16
        v.co.y += noise.noise(v.co * 1.3 + Vector((3, 3, 3))) * 0.16
    p.cone(stone, (0.35, 0.1, 0), 0.3, 0.0, 1.3, seg=5, rot=(0.1, 0.35, 0))
    p.cone(stone, (-0.3, -0.2, 0), 0.28, 0.0, 1.1, seg=5, rot=(0.2, -0.4, 0))
    p.build(smooth=False)
    export("spike")
    # big scenery boulders
    for i in range(3):
        p = Part("Boulder")
        p.ico(mat("rock", "#7f786f"), (0, 0, 0.5), (1.3, 1.0 + 0.2 * i, 0.9 + 0.25 * i), sub=4, jitter=0.36, seed=20 + i)
        if i == 2:
            p.ico(mat("rock", "#7f786f"), (1.1, 0.4, 0.2), (0.7, 0.6, 0.6), sub=3, jitter=0.36, seed=31)
        p.build(smooth=True, sharp=60)
        export("boulder_%d" % i)

def ice():
    icem = mat("ice", "#bfeaff")
    p = Part("Shard")
    p.cone(icem, (0, 0, 0), 0.11, 0.0, 0.75, seg=5)
    p.cone(icem, (0, 0, 0), 0.11, 0.0, 0.3, seg=5, rot=(math.pi, 0, 0))
    p.build(smooth=False)
    export("ice_shard")

def wave():
    # cross-section profile swept along X; wave travels toward -Y (Godot +Z)
    prof = [(0.95, 0.0), (0.55, 0.42), (0.18, 0.92), (-0.2, 1.28), (-0.55, 1.34), (-0.82, 1.12),
            (-0.86, 0.86), (-0.62, 0.74), (-0.38, 0.58), (-0.42, 0.28), (-0.7, 0.0)]
    bm = bmesh.new()
    N = 14
    rows = []
    for i in range(N + 1):
        t = i / N
        x = (t - 0.5) * 2.0
        k = max(math.cos(x * math.pi / 2), 0.0) ** 0.22
        row = [bm.verts.new((x, y * k - (1 - k) * -0.35, z * k)) for (y, z) in prof]
        rows.append(row)
    uvl = bm.loops.layers.uv.new("UVMap")
    M = len(prof) - 1
    for i in range(N):
        for j in range(M):
            f = bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            for lp, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uvl].uv = (ii / N, jj / M)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("Wave")
    bm.to_mesh(me); bm.free()
    for pp in me.polygons:
        pp.use_smooth = True
    me.materials.append(mat("water", "#3fa7e0"))
    ob = bpy.data.objects.new("Wave", me)
    bpy.context.scene.collection.objects.link(ob)
    export("wave")

def trees():
    bark = mat("bark", "#6b4a32")
    for i, (leafa, leafb) in enumerate([("#4f9a48", "#6fbf55"), ("#3f8a55", "#5fb070"), ("#f29bb4", "#f8c4d2")]):
        la, lb = mat("leafa", leafa), mat("leafb", leafb)
        p = Part("Tree")
        vs = p.cone(bark, (0, 0, 0), 0.34, 0.16, 3.2, seg=8)
        for v in vs:
            v.co.x += math.sin(v.co.z * 0.9 + i) * 0.14
        p.cone(bark, (0.05, 0, 1.9), 0.11, 0.05, 1.5, seg=6, rot=(0, 0.8, 0.3 + i))
        p.cone(bark, (0, 0, 2.1), 0.1, 0.05, 1.3, seg=6, rot=(0, -0.7, 1.9 + i))
        random.seed(40 + i)
        blobs = [(0, 0, 4.0, 1.7), (1.2, 0.3, 3.3, 1.2), (-1.1, -0.4, 3.4, 1.25), (0.2, 1.1, 3.5, 1.1),
                 (-0.2, -1.1, 3.6, 1.1), (0.5, -0.3, 4.9, 1.05)]
        for j, (x, y, z, r) in enumerate(blobs):
            p.ico(la if j % 2 == 0 else lb, (x, y, z), (r, r, r * 0.8), sub=3, jitter=0.3, seed=50 + i * 7 + j)
        p.build(smooth=True, sharp=62)
        export("tree_%d" % i)
    # pine
    p = Part("Pine")
    p.cone(bark, (0, 0, 0), 0.25, 0.1, 2.4, seg=7)
    pa, pb = mat("leafa", "#2f6f4a"), mat("leafb", "#3d8558")
    for j in range(4):
        p.cone(pa if j % 2 == 0 else pb, (0, 0, 1.3 + j * 1.15), 1.7 - j * 0.36, 0.0, 2.0, seg=8,
               rot=(0.04 * j, 0.03, j * 0.5))
    p.build(smooth=True, sharp=62)
    export("tree_3")
    # bush
    p = Part("Bush")
    for j, (x, y, z, r) in enumerate([(0, 0, 0.4, 0.7), (0.6, 0.2, 0.3, 0.5), (-0.5, -0.2, 0.3, 0.55)]):
        p.ico(mat("leafa", "#4f9a48") if j != 1 else mat("leafb", "#6fbf55"), (x, y, z), (r, r, r * 0.75),
              sub=3, jitter=0.3, seed=70 + j)
    p.build(smooth=True, sharp=62)
    export("bush")

def shrine():
    stone = mat("stone", "#b9b2a4")
    dark = mat("stonedark", "#8a8478")
    gold = mat("gold", "#e2b24a")
    # round platform
    p = Part("Platform")
    p.cone(dark, (0, 0, -1.5), 11.5, 11.0, 1.5, seg=28)
    p.cone(stone, (0, 0, 0), 10.2, 10.0, 0.25, seg=28)
    p.cone(dark, (0, 0, 0.25), 4.0, 3.9, 0.12, seg=24)
    p.cone(gold, (0, 0, 0.37), 1.2, 1.15, 0.05, seg=20)
    p.build(smooth=False)
    export("shrine_platform")
    # standing stone with element crystal
    for el, h in (("earth", "#63c463"), ("fire", "#ff6a3c"), ("water", "#4fb6ff"), ("air", "#e9fff8")):
        p = Part("Stone")
        vs = p.cone(stone, (0, 0, 0), 0.75, 0.5, 4.2, seg=6)
        for v in vs:
            v.co.x += noise.noise(v.co * 0.8) * 0.12
        p.box(dark, (0, 0, 1.2), (1.25, 1.25, 0.18), rot=(0, 0, 0.5))
        p.box(dark, (0, 0, 3.1), (1.0, 1.0, 0.14), rot=(0, 0, 0.5))
        p.cone(mat("crystal_" + el, h), (0, 0, 4.45), 0.34, 0.0, 0.8, seg=5)
        p.cone(mat("crystal_" + el, h), (0, 0, 4.45), 0.34, 0.0, 0.4, seg=5, rot=(math.pi, 0, 0))
        p.build(smooth=False)
        export("shrine_stone_" + el)
    # arch
    p = Part("Arch")
    for sx in (-1, 1):
        p.cone(stone, (sx * 2.6, 0, 0), 0.6, 0.45, 5.0, seg=8)
        p.box(dark, (sx * 2.6, 0, 0.2), (1.5, 1.5, 0.4))
    p.box(dark, (0, 0, 5.2), (7.4, 0.9, 0.5))
    p.box(stone, (0, 0, 5.7), (8.4, 1.1, 0.35))
    for sx in (-1, 1):
        p.box(stone, (sx * 4.3, 0, 5.95), (0.9, 1.1, 0.5), rot=(0, sx * -0.4, 0))
    p.cone(gold, (0, 0, 4.2), 0.3, 0.0, 0.7, seg=4, rot=(math.pi, 0, 0))
    p.cone(gold, (0, 0, 4.2), 0.3, 0.0, 0.35, seg=4)
    p.build(smooth=False)
    export("arch")
    # training totem
    wood = mat("wood", "#9a6b3f")
    p = Part("Totem")
    p.cone(wood, (0, 0, 0), 0.3, 0.26, 2.0, seg=10)
    p.cone(mat("paint_red", "#c83a2e"), (0, 0, 1.25), 0.33, 0.33, 0.14, seg=10)
    p.cone(mat("paint_white", "#efe6d2"), (0, 0, 0.75), 0.33, 0.33, 0.1, seg=10)
    p.sphere(mat("straw", "#dcc27a"), (0, 0, 2.3), (0.42, 0.42, 0.42))
    p.box(wood, (0, 0, 1.6), (1.5, 0.14, 0.14))
    p.cone(mat("paint_red", "#c83a2e"), (0, -0.4, 2.3), 0.18, 0.18, 0.04, seg=12, rot=(math.pi / 2, 0, 0))
    p.build(smooth=False)
    export("totem")
    # lantern post
    p = Part("Lantern")
    p.cone(dark, (0, 0, 0), 0.22, 0.14, 1.9, seg=6)
    p.box(dark, (0, 0, 1.95), (0.7, 0.7, 0.1))
    p.box(mat("lampglow", "#ffd78a"), (0, 0, 2.25), (0.42, 0.42, 0.5))
    p.cone(dark, (0, 0, 2.5), 0.55, 0.0, 0.4, seg=4, rot=(0, 0, math.pi / 4))
    p.build(smooth=False)
    export("lantern")

def village():
    wall = mat("plaster", "#eadfc6")
    wood = mat("wood", "#7d5636")
    for i, roofc in enumerate(("#2f7f8f", "#b8483a", "#6a8f3f")):
        roof = mat("roof", roofc)
        p = Part("Hut")
        r = 3.0 + i * 0.4
        p.cone(mat("stonedark", "#8a8478"), (0, 0, -1.0), r + 0.4, r + 0.3, 1.2, seg=12)
        p.cone(wall, (0, 0, 0.2), r, r * 0.96, 2.6, seg=12)
        p.cone(roof, (0, 0, 2.7), r + 0.9, 0.3, 2.6, seg=12)
        p.cone(mat("gold", "#e2b24a"), (0, 0, 5.2), 0.25, 0.0, 0.7, seg=6)
        p.box(wood, (0, -r + 0.05, 1.1), (1.2, 0.3, 2.0))
        for a in (1.2, -1.2, 2.6):
            p.box(mat("lampglow", "#ffd78a"), (math.sin(a) * (r - 0.05), -math.cos(a) * (r - 0.05), 1.6),
                  (0.7, 0.2, 0.7), rot=(0, 0, a))
        for k in range(12):
            a = k / 12 * math.tau
            p.box(wood, (math.sin(a) * (r + 0.05), -math.cos(a) * (r + 0.05), 1.5), (0.16, 0.16, 2.7))
        p.build(smooth=False)
        export("hut_%d" % i)
    # dock
    p = Part("Dock")
    for k in range(9):
        p.box(wood, (0, k * 0.72, 0), (2.6, 0.62, 0.14))
    for k in (0, 4, 8):
        for sx in (-1, 1):
            p.cone(wood, (sx * 1.2, k * 0.72, -2.4), 0.14, 0.14, 3.0, seg=6)
    p.build(smooth=False)
    export("dock")
    # crate + barrel cluster
    p = Part("Crates")
    p.box(wood, (0, 0, 0.45), (0.9, 0.9, 0.9))
    p.box(mat("wood2", "#96693f"), (0.95, 0.2, 0.35), (0.7, 0.7, 0.7), rot=(0, 0, 0.4))
    p.cone(mat("wood2", "#96693f"), (-0.9, 0.1, 0), 0.38, 0.38, 0.95, seg=10)
    p.build(smooth=False)
    export("crates")

def fort():
    log = mat("log", "#5a4336")
    dark = mat("iron", "#2f2c33")
    p = Part("Palisade")
    random.seed(5)
    for k in range(8):
        h = 4.2 + random.random() * 0.9
        p.cone(log, (-3.5 + k, 0, -0.8), 0.5, 0.46, h + 0.8, seg=6)
        p.cone(log, (-3.5 + k, 0, h), 0.46, 0.0, 0.9, seg=6)
    p.box(dark, (0, -0.42, 2.4), (8.0, 0.12, 0.3))
    p.build(smooth=False)
    export("palisade")
    p = Part("Tower")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cone(log, (sx * 1.6, sy * 1.6, -0.8), 0.3, 0.26, 8.3, seg=6)
    p.box(log, (0, 0, 6.2), (4.2, 4.2, 0.3))
    for sx in (-1, 1):
        p.box(log, (sx * 2.0, 0, 6.9), (0.2, 4.2, 1.1))
        p.box(log, (0, sx * 2.0, 6.9), (4.2, 0.2, 1.1))
    p.cone(mat("roofdark", "#3a2630"), (0, 0, 8.4), 3.6, 0.2, 2.2, seg=4, rot=(0, 0, math.pi / 4))
    p.build(smooth=False)
    export("tower")
    p = Part("Banner")
    p.cone(log, (0, 0, 0), 0.12, 0.09, 6.0, seg=6)
    p.box(log, (0.7, 0, 5.6), (1.6, 0.1, 0.1))
    p.box(mat("banner", "#6a2bb0"), (0.75, 0, 4.3), (1.3, 0.05, 2.5))
    p.cone(mat("mask", "#d9d2c0"), (0.75, -0.05, 4.5), 0.35, 0.35, 0.04, seg=10, rot=(math.pi / 2, 0, 0))
    p.build(smooth=False)
    export("banner")
    # corruption crystal
    cry = mat("corrupt", "#9a3cff")
    p = Part("Crystal")
    random.seed(11)
    p.ico(mat("iron", "#2f2c33"), (0, 0, 0.1), (1.3, 1.3, 0.5), sub=2, jitter=0.4, seed=3)
    for k in range(7):
        a = k / 7 * math.tau
        r = 0.0 if k == 0 else 0.55
        h = 2.6 if k == 0 else 1.2 + random.random() * 0.9
        p.cone(cry, (math.cos(a) * r, math.sin(a) * r, 0.2), 0.34 if k else 0.5, 0.0, h, seg=5,
               rot=(0 if k == 0 else math.sin(a) * -0.45, 0 if k == 0 else math.cos(a) * 0.45, a))
    p.build(smooth=False)
    export("crystal")

wipe()
for nm, (pal, hair, build, extras) in CHARS.items():
    character(nm, pal, hair, build, extras)
rocks(); ice(); wave(); trees(); shrine(); village(); fort()
print("ALL DONE")
