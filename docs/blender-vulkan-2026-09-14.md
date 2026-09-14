# Original Blender Vulkan verification, 2026-09-14

The installed arlinux-arch APK passes the tested original Blender 5.2.1 LTS
Vulkan workflow on OnePlus 13 and Redmi. The Blender executable matches the
original signed package; the fixes are in Mesa and anlabwc.

| Check | Redmi / Adreno 650 | OnePlus 13 / Adreno 830v1 |
| --- | --- | --- |
| Model, save, fullscreen, restore, reopen | All five events passed | All five events passed |
| Fresh process reopen | 17 meshes, 3808 vertices, 2937 faces, 6 materials | Same |
| Eevee | Correct PNG, normal exit; 11.1 seconds | Correct PNG, normal exit; 8.8 seconds |
| Workbench | Correct PNG, normal exit; 7.2 seconds | Correct PNG, normal exit; 6.9 seconds |
| Compute push constant regression | All three cases passed | All three cases passed |

The durations cover process startup through normal exit. Both render engines
used explicit Vulkan with the APK's default ICD and no diagnostic driver
override or push constant debug option. Process maps confirm the packaged
driver. All four PNGs and both final viewport screenshots were inspected.
The workflow process stays open by design; after its five events and screenshot,
the test harness terminated that owned process to run independent renders.
The render and independent reopen processes exited zero without timeout.

## Fixes and diagnosis

OnePlus's modern Android buffers require verified layout metadata. anlabwc
`f92692d8` advertises `android_wlegl` version 3 and obtains linear layout data
through Android's stable IMapper interface. The captured protocol includes the
layout event previously missing from the version-2 server.

Redmi's Eevee GPU fault was caused by graphics state disabling shared constants
after the compute pipeline was bound. Mesa `9aee2bbb23a` restores the compute
shader's shared constant mode before dispatch loads constants. A standalone
test reproduces the old driver's wrong value after an intervening graphics
draw; compute-only and explicit-rebind controls pass. The fix passes all three.
Repeating that comparison with Khronos validation loaded reports no API errors.

The core now includes a bounded process observer, GDB fixture verification,
Turnip breadcrumb collection, KGSL submission/fault logging, and the standalone
Vulkan regression. A healthy-context `EINVAL` does not establish whether fault
address reporting works. No OnePlus GPU fault was observed, so returned fault
addresses were not validated there.

## Build identity and evidence

The APK was built from product `8a19f0d`, clean core `fb5b21903baaf`, Mesa
`9aee2bbb23acc` and anlabwc `f92692d8b7c6`. Later product documentation commits
record this existing build. APK, compositor, runtime, driver and original
Blender hashes match between devices; full hashes, device identities, process
results and workflow reports are in the [machine-readable record](blender-vulkan-2026-09-14.json).

APK SHA-256:
`c08d9e7ef9c04ad2a9bffa0c3a3ccb456830dccebf7cdaab1f0519a2938c62c2`.
The local artifact is `build/arlinux-arch-debug.apk`; raw logs, process maps,
scene files and images are retained under the core's
`build/blender-arch-diagnostic/packaged-final/`.

| Evidence | Redmi | OnePlus 13 |
| --- | --- | --- |
| Viewport | [Screenshot](blender-vulkan-2026-09-14/redmi-workflow.png) | [Screenshot](blender-vulkan-2026-09-14/oneplus13-workflow.png) |
| Eevee | [PNG](blender-vulkan-2026-09-14/redmi-blender_eevee.png) | [PNG](blender-vulkan-2026-09-14/oneplus13-blender_eevee.png) |
| Workbench | [PNG](blender-vulkan-2026-09-14/redmi-blender_workbench.png) | [PNG](blender-vulkan-2026-09-14/oneplus13-blender_workbench.png) |

To reproduce, launch the core's `tests/blender/workflow.py`, `render.py` and
`reopen.py` from the actual desktop terminal, using `--gpu-backend vulkan`.
Their READMEs describe the output and engine environment variables. Build
`tests/vulkan-shared-constants/build.sh` for the independent regression.
These are bounded scene checks, not general Blender feature coverage,
long-session stability, or an OpenGL acceptance result.
