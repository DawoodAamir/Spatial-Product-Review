"""Create an original, self-contained USDZ desk lamp using only the standard library."""
from pathlib import Path
import struct
import zipfile

root = Path(__file__).resolve().parents[1]
parts = [
    ("Base", (0.24, 0.025, 0.18), (0, 0.0125, 0), "Metal"),
    ("Stem", (0.025, 0.33, 0.025), (0, 0.19, 0.025), "Metal"),
    ("Shade", (0.22, 0.075, 0.15), (0, 0.38, -0.025), "Metal"),
    ("Diffuser", (0.18, 0.006, 0.11), (0, 0.341, -0.025), "Diffuser"),
]
text = '''#usda 1.0
(defaultPrim = "DeskLamp"; metersPerUnit = 1; upAxis = "Y")
def Xform "DeskLamp" {
'''
for name, color, metallic in [("Metal", (0.24, 0.38, 0.39), 0.7), ("Diffuser", (0.91, 0.76, 0.49), 0)]:
    text += f'''def Material "{name}Material" {{
        token outputs:surface.connect = </DeskLamp/{name}Material/Surface.outputs:surface>
        def Shader "Surface" {{
            uniform token info:id = "UsdPreviewSurface"
            color3f inputs:diffuseColor = {color}
            float inputs:roughness = 0.4
            float inputs:metallic = {metallic}
            token outputs:surface
        }}
    }}
'''
for name, size, center, material in parts:
    x,y,z = [v / 2 for v in size]
    points = [(a+center[0], b+center[1], c+center[2]) for a,b,c in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
    text += f'''def Mesh "{name}" {{
        point3f[] points = [{", ".join(map(str, points))}]
        int[] faceVertexCounts = [4,4,4,4,4,4]
        int[] faceVertexIndices = [0,3,2,1,4,5,6,7,0,1,5,4,3,7,6,2,0,4,7,3,1,2,6,5]
        normal3f[] normals = [(0,0,-1),(0,0,1),(0,-1,0),(0,1,0),(-1,0,0),(1,0,0)] (interpolation = "uniform")
        uniform token subdivisionScheme = "none"
        rel material:binding = </DeskLamp/{material}Material>
    }}
'''
text += "}\n"
folder = root / "Resources/Samples"
folder.mkdir(parents=True, exist_ok=True)
name = "DeskLamp.usda"
info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
# USDZ requires uncompressed entries aligned to 64-byte boundaries.
padding = (-(30 + len(name.encode()) + 4)) % 64
info.extra = struct.pack("<HH", 0xFFFF, padding) + bytes(padding)
with zipfile.ZipFile(folder / "Desk Lamp.usdz", "w", compression=zipfile.ZIP_STORED) as archive:
    archive.writestr(info, text.encode())
