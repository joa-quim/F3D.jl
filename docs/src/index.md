```@meta
CurrentModule = F3D
```

# F3D.jl

Julia bindings for the [F3D](https://f3d-app.github.io/f3d/) 3D viewer library, providing access to the full F3D C API via `ccall`.

F3D is a fast and minimalist 3D viewer that supports many file formats (VTK, glTF, STL, OBJ, PLY, and more). This package wraps the F3D C API, enabling you to:

- Load and display 3D models from files or programmatic meshes
- Control camera position, orientation and movement
- Render scenes to images (PNG, JPG, TIF, BMP)
- Configure rendering options (colors, lighting, raytracing, etc.)
- Handle interactive input events (keyboard, mouse)
- Run animations

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/joa-quim/F3D.jl")
```

On first use, the package automatically downloads the F3D nightly raytracing binaries for your platform.

## Quick Start

```julia
using F3D

# Create an offscreen engine
engine = F3D.f3d_engine_create(1)

# Load a 3D file
scene = F3D.f3d_engine_get_scene(engine)
F3D.f3d_scene_add(scene, "model.stl")

# Render to an image
window = F3D.f3d_engine_get_window(engine)
F3D.f3d_window_set_size(window, 800, 600)
img = F3D.f3d_window_render_to_image(window, 0)
F3D.f3d_image_save(img, "output.png", F3D.PNG)

# Clean up
F3D.f3d_image_delete(img)
F3D.f3d_engine_delete(engine)
```

## Contents

```@contents
Pages = ["20-manual.md", "95-reference.md"]
Depth = 2
```
