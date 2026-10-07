# نظام توليد المجسّمات 3D (Windows + جوج RTX 3090)

نظام كيحوّل **صورة** (من ChatGPT ولا من رسم ديالك) لـ **مجسّم 3D ملوّن** واجد للألعاب
(Roblox وغيرها): حيوانات، شخصيات، بنايات، أدوات، محاصيل…

```
صورة (ChatGPT)  ──►  prepare.py  ──►  generate.py (TRELLIS.2 على RTX)  ──►  roblox_prep.py (Blender)  ──►  Roblox Studio
  خلفية بيضاء       كيحيّد الخلفية      3 محاولات لكل صورة، GLB + فيديو        تصغير، اتجاه، حجم            Import 3D
```

- **النموذج:** [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) ديال Microsoft، 4 مليار معامل، **رخصة MIT**
  (تقدر تستعمل المجسّمات فلعبة تجارية). المجسّمات اللي كيخرج فيها ألوان كاملين (PBR).
- **فين كيخدم:** الكود الرسمي متجرّب غير على **Linux**، داكشي علاش كنخدمو بـ **WSL2**
  (Linux داخل Windows، وكيوصل للكارطات مباشرة). هادي هي الطريقة الأضمن على Windows.
- **الكارطات:** النموذج كيحتاج **24GB**، والـ 3090 فيها 24GB بالضبط. كل كارطة كتخدم بوحدها
  على صور مختلفين، يعني **جوج كارطات = الزربة مضاعفة**. نموذج واحد ما كيتقسمش على جوج كارطات.

> ⚠️ **بصراحة:** هاد السكريبتات كتبتهم على حساب الكود الرسمي ديال TRELLIS.2، ولكن
> **ما قدرتش نجرّب التوليد** حيت الجهاز ديالي ما فيهش GPU. جرّبت `prepare.py` و
> `roblox_prep.py` وخدامين. إيلا طلع شي خطأ فالتثبيت ولا فالتوليد، صيفط ليا النص ديال الخطأ
> ولا استعمل البرومت ديال Claude Code اللي فالأسفل.

---

## 1. التثبيت (مرة وحدة، تقريبا ساعة)

### أ. فـ Windows

1. **ثبّت آخر Driver ديال NVIDIA** من nvidia.com (Game Ready ولا Studio).
2. افتح **PowerShell كمسؤول (Run as Administrator)**، وروح للمجلد `tools\gen3d`:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\install_wsl.ps1
   ```
3. عاود تشغيل الحاسوب إيلا طلب منك، ومن بعد افتح **Ubuntu 22.04** من قائمة Start،
   وصاوب المستعمل ديال Linux (سمية وكلمة سر).

> **مهم:** ما تثبّتش Driver ديال NVIDIA داخل Ubuntu، Windows كيشاركو مع WSL.
> السكريبت كيكتب `%USERPROFILE%\.wslconfig` فيه 24GB ديال الذاكرة. بدّلها على حساب الـ RAM ديالك
> (تقريبا 3/4 منها).

### ب. داخل Ubuntu (WSL)

```bash
# جيب المشروع (ولا نسخ مجلد tools/gen3d بوحدو)
git clone -b ccr-3fd94141-uhrjvi https://github.com/toutoufik27-coder/Pingora.git ~/Pingora
bash ~/Pingora/tools/gen3d/setup_ubuntu.sh
```

السكريبت كيثبّت:
- **CUDA 12.4** (النسخة ديال WSL).
- **Miniconda.**
- **TRELLIS.2** فـ `~/gen3d/TRELLIS.2`، مع كاع الإضافات ديالو: flash-attn، nvdiffrast، CuMesh، o-voxel…

البيئة كتكون سميتها **`trellis2`**. البناء كياخد **30 حتى 90 دقيقة**، وفي اللخر كيطبع
`TRELLIS.2 imports OK` والكارطات اللي لقى.

**أول مرة كتشغّل التوليد**، كيتحمّلو الأوزان ديال النموذج من Hugging Face (بزاف ديال GB).
إيلا طلب منك الدخول (401 / gated)، دير هاكا:
```bash
conda activate trellis2
huggingface-cli login      # حط Token من huggingface.co/settings/tokens
```
وقبل الشروط فالصفحة ديال داك النموذج على Hugging Face.

---

## 2. الاستعمال اليومي

### الخطوة 1: الصور

حط الصور فمجلد، مثلا `~/concepts/animals/`. **صورة وحدة لكل مجسّم**، والسمية بالإنجليزية:
`Chicken.png`، `Cow.png`… شوف البرومتات فالقسم 4.

إيلا كانت عندك أوراق فيها بزاف ديال الزوايا فسطر واحد، بحال الدجاجة والبطة،
`prepare.py` كيقدر يقطعهم (`--split`). **TRELLIS.2 كياخد صورة وحدة**، والأحسن تكون
**زاوية ثلاثة أرباع (3/4)** ولا من القدام.

### الخطوة 2: التوليد على جوج الكارطات

```bash
conda activate trellis2
cd ~/Pingora/tools/gen3d
bash run_all.sh ~/concepts/animals ~/work/animals --seeds 3 --res 1024
# ورقة بزاف ديال الزوايا: خود غير الزاوية الأولى (القدام)
SPLIT_VIEW=0 bash run_all.sh ~/concepts/sheets ~/work/sheets --seeds 3
```

- `run_all.sh` كينظف الصور (`inputs/`)، ومن بعد كيطلق **worker على كل كارطة**.
- النتيجة فـ `~/work/animals/raw/<Name>/`:
  - `Name_s1.glb`، `Name_s2.glb`، `Name_s3.glb`: 3 محاولات بـ 3 seeds مختلفين.
  - `Name_s1.mp4`…: فيديو كيدور بالمجسّم، باش تختار الأحسن بلا ما تحلّ Blender.
- **إيلا وقفتيه وعاودتيه**، كيكمّل من فين وقف (اللي تصاوب ما كيتعاودش).
- **تتبّع:** `tail -f ~/work/animals/gpu0.log`

**من Windows** تقدر تحلّ الملفات من Explorer: `\\wsl$\Ubuntu-22.04\home\<USER>\work`

| الإعداد | الشرح | النصيحة |
| --- | --- | --- |
| `--res 512` | الأسرع، تفاصيل أقل | للتجربة والزينة الصغيرة |
| `--res 1024` | التوازن (الافتراضي) | **للحيوانات والشخصيات** |
| `--res 1536` | أعلى جودة | غالبا كيتعدّى 24GB فـ 3090، جرّبو وإلا ما خدمش رجع لـ 1024 |
| `--seeds N` | شحال من محاولة لكل صورة | 3 حتى 4، ومن بعد تختار |
| `--low-vram` | كيحيّد النماذج المساعدة من الكارطة | إيلا طلع *out of memory* |
| `--faces` / `--texture` | حجم الـ GLB الخام | خليهم، التصغير الحقيقي فالخطوة 3 |

**الوقت:** على H100 الرسميين كيقولو 17 ثانية فـ 1024. على 3090 غادي يكون **أبطأ بزاف**،
تقريبا دقيقة حتى جوج لكل محاولة، ولكن ما قستوش بنفسي.

### الخطوة 3: التنظيف لـ Roblox (Blender)

ثبّت **Blender** على Windows (مجاني، blender.org). من بعد من PowerShell
(بدّل `4.5` بالنسخة اللي ثبّتي):

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" -b -P roblox_prep.py -- `
    Chicken_s2.glb Chicken_roblox.glb --tris 8000 --texture 1024 --height 2.4 --preview Chicken.png
```

- كيجمع المجسّم، كيصلح الوجوه، **كينقص المثلثات** (`--tris`)، **كيصغّر الصور** (`--texture`).
- كيوقفو على الأرض فالوسط، **وجهو لقدام**، وبالطول اللي بغيتي (`--height` بالـ studs).
- كيصاوب `Chicken_front.png` و `Chicken_side.png`: **الحيوان خاصو يشوف فيك فالصورة ديال front**.
  إيلا كان معطيك الظهر ولا الجنب، عاود بـ `--yaw 180` ولا `--yaw 90` ولا `--yaw -90`.

**عدد المثلثات المقترح:** حيوان صغير 5–8k، حيوان كبير ولا شخصية 8–12k، زينة 1–3k.
تأكد من الحد الأقصى الحالي ديال Roblox لكل Mesh فالـ Creator Docs.

### الخطوة 4: Roblox Studio

1. **File → Import 3D** (ولا Avatar → Import 3D)، واختار `Chicken_roblox.glb`.
2. شوف المعاينة: الألوان، الاتجاه، الحجم. ومن بعد **Import**.
3. المجسّم كيترفع **باسم الحساب ديالك**. حطو فـ `ReplicatedStorage/Assets/Animals/Chicken`.
4. إيلا كان الحجم ماشي هو هداك، بدّلو فالـ Properties ولا بـ `Model:ScaleTo()`.

**الحركة:**
- **الحيوانات:** النظام ديالنا فاللعبة (`Animator.luau`) غادي يتربط بهاد المجسّمات من بعد،
  ونزيدو ليهم العظام (الراس، الرجلين، الذيل…).
- **الشخصيات البشرية:** Studio فيه أدوات كتزيد العظام أوتوماتيكيا للشخصيات اللي كتشبه
  الإنسان. صاوب الشخصية **واقفة ويديها مفتوحين شوية (A-pose)** باش تخدم مزيان.

---

## 3. نصائح للجودة

- **الصورة هي كلشي.** حيوان واحد، الجسم كامل باين، **خلفية بيضاء صافية**، ضو مستوي **بلا ظلال**،
  **بلا نص**، والرجلين متفرقين.
- **زاوية 3/4** كتعطي أحسن حجم من صورة القدام بوحدها.
- **ولّد 3 حتى 4 seeds** واختار الأحسن، هادي أرخص طريقة للجودة.
- **الأجزاء الرقيقة** (الريش، الشعر، الودنين الطوال) كتطلع أحسن ملي يكونو **غلاض شوية** فالصورة.
- **باش تبقى اللعبة متناسقة:** استعمل نفس الجملة ديال الستيل فكاع البرومتات (القسم 4).
- **خلي الملفات داخل Linux** (`~/work`)، ماشي فـ `/mnt/c/...`: القراءة من C: بطيئة بزاف.

---

## 4. البرومتات

### أ. صورة لـ TRELLIS.2 (ChatGPT، صورة وحدة لكل مجسّم)

بدّل `[...]`، وخلي جملة الستيل كيف ما هي فكاع المجسّمات:

```
A single [SUBJECT DESCRIPTION], cute stylized 3D cartoon game asset in the style of a premium
mobile farm game: soft rounded clay-like shapes, smooth clean surfaces, big friendly eyes,
saturated but soft colors.

View: three-quarter view from the front-right, camera at the subject's eye level,
whole subject fully visible and centered, filling about 80% of the image height.

Pose: neutral standing idle pose, mouth closed, legs straight and clearly separated with gaps,
tail, ears and wings clearly separated from the body, nothing crossing in front of the body.

Rendering: flat even studio lighting, no cast shadows, no ground shadow, no reflections,
matte materials, plain pure white background (#FFFFFF), no floor, no props, no text,
no watermark, only one subject in the image.
```

| النوع | مثال ديال `[SUBJECT DESCRIPTION]` |
| --- | --- |
| حيوان | `plump white hen with a red five-lobed comb, red wattles, small orange beak, short thick orange legs` |
| شخصية | `young farmer character with a straw hat, green overalls and boots, standing in A-pose with arms slightly away from the body, chibi proportions with a big head` |
| بناية | `small wooden farm market stall with a striped red and white awning and two crates of vegetables, isometric-friendly simple shapes` |
| أداة | `cartoon watering can, light blue metal with a long spout, standing upright` |
| محصول | `ripe orange pumpkin with a short curly green stem and two leaves` |

**للمحاصيل اللي كتكبر:** دير 3 صور لكل محصول: `seedling` (نبتة صغيرة)، `growing` (كتكبر)،
`ripe` (ناضجة)، بنفس الستيل.

### ب. برومت لـ Claude Code على الحاسوب ديالك (إيلا بغيتي AI يثبّت ويصلح بلاصتك)

ثبّت Claude Code داخل Ubuntu (WSL)، وحلّو فمجلد `~/Pingora`، ومن بعد صيفط ليه هادشي:

```
You are setting up a local image-to-3D generation system on this machine.
Environment: Windows 11 + WSL2 Ubuntu 22.04, two NVIDIA RTX 3090 (24 GB each), the NVIDIA
driver is installed on Windows only (do not install a Linux driver inside WSL).

Goal: run Microsoft TRELLIS.2 (MIT licence, https://github.com/microsoft/TRELLIS.2) to turn
concept images into textured GLB models for a Roblox game, using both GPUs in parallel.

The scripts are already written in tools/gen3d/ of this repo:
  install_wsl.ps1 (done), setup_ubuntu.sh, prepare.py, generate.py, run_all.sh, roblox_prep.py,
  and README.md explains the whole flow. Read README.md and every script first.

Do this step by step, and after each step show me the command output:
1. Check `nvidia-smi` shows both GPUs inside WSL.
2. Run tools/gen3d/setup_ubuntu.sh. If an extension fails to build (flash-attn, nvdiffrast,
   CuMesh, FlexGEMM, o-voxel), read the error, fix the cause (CUDA_HOME, TORCH_CUDA_ARCH_LIST=8.6,
   MAX_JOBS for RAM, missing apt packages) and rerun only that part with the matching
   setup.sh flag. Never skip a component silently.
3. Generate one test model: put docs/art/ref/chicken-turnaround.png in a folder and run
   `SPLIT_VIEW=0 bash tools/gen3d/run_all.sh <folder> ~/work/test --seeds 1 --res 512`.
   If generate.py fails because the TRELLIS.2 API differs from what it expects
   (pipeline.run arguments, o_voxel.postprocess.to_glb arguments), compare with the current
   example.py and app.py in the TRELLIS.2 repo and fix generate.py minimally.
4. If it runs out of memory, try --low-vram, then --res 512, and tell me which worked.
5. Run the same test with --res 1024 on both GPUs at once and report the time per model.
6. Summarise: what you changed, the exact commands I use from now on, and any warnings.
Do not change files outside tools/gen3d and ~/gen3d without asking me.
```

---

## 5. المشاكل الشائعة

| المشكل | الحل |
| --- | --- |
| `nvidia-smi` ما خدامش فـ Ubuntu | حدّث Driver ديال Windows، ومن بعد `wsl --update`، وعاود تشغيل الحاسوب |
| البناء ديال flash-attn كيطيح ولا كيوقف الحاسوب | نقّص `MAX_JOBS=2`، وزيد `memory`/`swap` فـ `.wslconfig` |
| `nvcc not found` / النسخة غالطة | `export CUDA_HOME=/usr/local/cuda-12.4` (السكريبت كيزيدها لـ `.bashrc`) |
| `CUDA out of memory` | `--low-vram`، ولا `--res 512`، وسدّ البرامج اللي كتستعمل الكارطة (الألعاب، Chrome) |
| 401 / gated من Hugging Face | `huggingface-cli login`، وقبول الشروط فالصفحة ديال داك النموذج |
| المجسّم ما عندوش ظهر ولا فيه ثقوب | صورة 3/4 أحسن، ولا seed آخر، ولا `--res 1024` |
| الحيوان معطيك الظهر فـ Roblox | `roblox_prep.py ... --yaw 180` |
| بطء كبير فالقراءة والكتابة | خلي الملفات فـ `~/` داخل Linux، ماشي فـ `/mnt/c` |

## 6. الرخص

- **TRELLIS.2:** الكود والأوزان برخصة **MIT**.
- **النماذج المساعدة:** كيتحمّلو أوتوماتيكيا مع TRELLIS.2، بحال النموذج اللي كيحيّد الخلفية
  والنموذج اللي كيقرا الصورة. عندهم رخص ديالهم، شوف `pipeline.json` فالصفحة ديال
  TRELLIS.2 على Hugging Face. حيت `prepare.py` كيعطي صور فيها الشفافية،
  **نموذج تحييد الخلفية ما كيتستعملش** أثناء التوليد.
- **الصور ديالك من ChatGPT** وشروط الاستعمال ديالها مسؤوليتك. كيفما كانت، تأكد قبل ما تنشر اللعبة.
