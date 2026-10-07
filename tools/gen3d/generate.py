"""Batch image -> 3D with TRELLIS.2 (MIT licence) on one GPU.

    conda activate trellis2
    python generate.py IN_DIR OUT_DIR [--seeds 3] [--res 1024] [--gpu 0 --workers 2]

IN_DIR holds PNGs (ideally RGBA from prepare.py). For each image and each
seed it writes OUT_DIR/<name>/<name>_s<seed>.glb plus a preview video, so you
can pick the best of several tries. Finished files are skipped, so the run can
be stopped and restarted.

Two RTX 3090s: run one worker per card (run_all.sh does this):
    CUDA_VISIBLE_DEVICES=0 python generate.py IN OUT --worker 0 --workers 2
    CUDA_VISIBLE_DEVICES=1 python generate.py IN OUT --worker 1 --workers 2
Each worker takes every other image. The model needs about 24 GB, so one
model per card; it does not split one generation across two cards.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

PIPELINE_TYPES = {"512": "512", "1024": "1024_cascade", "1536": "1536_cascade"}


def parse():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--trellis", default=os.path.expanduser("~/gen3d/TRELLIS.2"), help="TRELLIS.2 checkout (for the preview HDRI)")
    ap.add_argument("--model", default="microsoft/TRELLIS.2-4B")
    ap.add_argument("--seeds", type=int, default=3, help="tries per image")
    ap.add_argument("--seed0", type=int, default=1)
    ap.add_argument("--res", choices=list(PIPELINE_TYPES), default="1024", help="512 is fastest; 1536 may not fit in 24 GB")
    ap.add_argument("--faces", type=int, default=200000, help="faces kept in the GLB (cleaned again for Roblox later)")
    ap.add_argument("--texture", type=int, default=2048)
    ap.add_argument("--worker", type=int, default=0)
    ap.add_argument("--workers", type=int, default=1)
    ap.add_argument("--no-video", action="store_true")
    ap.add_argument("--low-vram", action="store_true", help="move helper models off the GPU between steps")
    return ap.parse_args()


def export_glb(o_voxel, pipeline, mesh, path, faces, texture):
    common = dict(
        vertices=mesh.vertices,
        faces=mesh.faces,
        attr_volume=mesh.attrs,
        coords=mesh.coords,
        aabb=[[-0.5, -0.5, -0.5], [0.5, 0.5, 0.5]],
        decimation_target=faces,
        texture_size=texture,
        remesh=True,
        remesh_band=1,
        remesh_project=0,
    )
    try:  # signature used by the README / example.py
        glb = o_voxel.postprocess.to_glb(attr_layout=mesh.layout, voxel_size=mesh.voxel_size, verbose=False, **common)
    except (TypeError, AttributeError):  # signature used by app.py
        glb = o_voxel.postprocess.to_glb(attr_layout=pipeline.pbr_attr_layout, grid_size=mesh.coords.max().item() + 1, **common)
    # PNG textures (no WebP): Blender and Roblox read them without extensions
    glb.export(str(path), extension_webp=False)


def main():
    a = parse()
    sys.path.insert(0, a.trellis)
    import cv2
    import imageio
    import torch
    from PIL import Image

    import o_voxel
    from trellis2.pipelines import Trellis2ImageTo3DPipeline
    from trellis2.renderers import EnvMap
    from trellis2.utils import render_utils

    images = sorted(p for p in Path(a.inp).iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    images = images[a.worker::a.workers]
    if not images:
        print("nothing to do")
        return
    out = Path(a.out)
    print(f"worker {a.worker}/{a.workers} on {torch.cuda.get_device_name(0)}: {len(images)} images x {a.seeds} seeds")

    pipeline = Trellis2ImageTo3DPipeline.from_pretrained(a.model)
    if a.low_vram and hasattr(pipeline, "low_vram"):
        pipeline.low_vram = True
    pipeline.cuda()
    envmap = None
    hdri = Path(a.trellis) / "assets/hdri/forest.exr"
    if not a.no_video and hdri.exists():
        envmap = EnvMap(torch.tensor(cv2.cvtColor(cv2.imread(str(hdri), cv2.IMREAD_UNCHANGED), cv2.COLOR_BGR2RGB), dtype=torch.float32, device="cuda"))

    log_path = out / f"log_worker{a.worker}.jsonl"
    out.mkdir(parents=True, exist_ok=True)
    for img_path in images:
        image = Image.open(img_path)
        folder = out / img_path.stem
        folder.mkdir(parents=True, exist_ok=True)
        for seed in range(a.seed0, a.seed0 + a.seeds):
            glb_path = folder / f"{img_path.stem}_s{seed}.glb"
            if glb_path.exists():
                continue
            t0 = time.time()
            try:
                mesh = pipeline.run(image, seed=seed, pipeline_type=PIPELINE_TYPES[a.res])[0]
                mesh.simplify(16777216)  # nvdiffrast limit
                if envmap is not None:
                    frames = render_utils.make_pbr_vis_frames(render_utils.render_video(mesh, envmap=envmap))
                    imageio.mimsave(str(folder / f"{img_path.stem}_s{seed}.mp4"), frames, fps=15)
                export_glb(o_voxel, pipeline, mesh, glb_path, a.faces, a.texture)
                status = "ok"
            except torch.cuda.OutOfMemoryError:
                status = "out of memory: try --res 512 or --low-vram"
            except Exception as e:  # keep the batch going
                status = f"error: {e!r}"
            finally:
                torch.cuda.empty_cache()
            dt = time.time() - t0
            print(f"  {img_path.name} seed {seed}: {status} ({dt:.0f}s)", flush=True)
            with open(log_path, "a") as f:
                f.write(json.dumps({"image": img_path.name, "seed": seed, "status": status, "seconds": round(dt, 1)}) + "\n")


if __name__ == "__main__":
    main()
