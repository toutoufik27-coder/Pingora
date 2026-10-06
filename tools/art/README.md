# Art previews

Renders the animals from `src/shared/Art/AnimalShapes.luau` in Blender so the
designs can be checked without Roblox Studio. Needs the `bpy` Python package
(`pip install bpy`, Python 3.13) and the Luau runner from `scripts/check.sh`.

```sh
tools/luau-runner/target/release/luau-runner run tools/art/dump_shapes.luau > /tmp/parts.txt
mkdir -p /tmp/animals
python -I tools/art/render_animals.py /tmp/parts.txt /tmp/animals
python tools/art/montage.py /tmp/animals docs/animals-preview.png
```

`stylized_animal_pack.py` is the Blender scene script from the art pass (with
colours, eyes, legs and camera fixed). It builds the same animals as Blender
meshes, which can be exported to FBX and imported in Studio later.

The concept sheet the designs follow is `docs/art/animals-concept.png`.
