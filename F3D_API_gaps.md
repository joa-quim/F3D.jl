# F3D API gaps

Limitations encountered while building a GMT-grid → F3D 3D viewer / map-draping &
export workflow (via the `F3D.jl` binding over the libf3d C API, DLL 3.5.0-103).
Each item is something VTK itself can do, but which the *stock* libf3d C API does
not expose.

Many of these were closed in the **extended build** (`f3d_ext` sources +
patched `f3d_mesh_t`; see `f3d_GIT/c/f3d_ext_REBUILD.md`). On a stock DLL the
`f3d_ext_*` symbols are absent and `test/test_f3d_ext.jl` skips. Status below is
verified against `src/libf3d.jl` + `test/test_f3d_ext.jl` (2026-06-04).

## Status summary

| # | Gap | Status |
|---|-----|--------|
| 1 | In-memory texture input | **Addressed** (`f3d_window_set_color_texture`) |
| 2 | Renderer access / cube-axes | **Addressed** (`f3d_ext_enable_cube_axes` + image_axes + colorbar) |
| 3 | GeoTIFF / metadata image write | Open |
| 4 | Segfault on unknown option key | Open (CONFIRMED real this session) |
| 5 | Per-cell / per-point colour & scalars on mesh | **Addressed** (`f3d_mesh_t` scalar/colour arrays) |
| 6 | Per-actor / per-cell edges | **Addressed** (`f3d_ext_set_edge_visibility`, `f3d_ext_add_cell_edges`) |
| 7 | Camera fit-2D-extent | Mostly addressed — ortho + scale work; only fit-to-XY missing, worked around |
| 8 | Mouse-move / pick / custom text overlay | **Addressed** (`f3d_ext_enable_coord_readout`, `f3d_ext_enable_focus_pick`) |
| 9 | Coloured point sprites | **Addressed** (`f3d_ext_color_point_sprites` + struct point_colors) |
| 10 | Rubber-band area point selection | **Addressed** (`f3d_ext_enable_rubber_band_pick`, `f3d_ext_area_pick_points`) |

---

## 1. Textures are path-only — no in-memory image input

`model.color.texture` / `model.emissive.texture` accept a **file path string**
only. There is no way to bind an in-memory `f3d_image` (or a raw RGBA buffer) as a
model texture. `f3d_image_set_content` fills an image object, but that image cannot
be used as a model input texture.

- **Impact:** every textured / draped render must write a temporary PNG to disk and
  delete it again.
- **Wanted:** a mesh/options path that accepts an `f3d_image*` or a raw buffer as a
  texture.

> **Addressed (`f3d_ext`).** `f3d_window_set_color_texture(window, image)` binds an
> in-memory `f3d_image` (filled via `f3d_image_set_content`) as the model base-colour
> texture — no temp file. Covered by test "in-memory base color texture (gap #1)".

## 2. No access to the `vtkRenderer` → can't add custom actors (e.g. `vtkCubeAxesActor`)

The C API exposes `engine` / `scene` / `window` / `camera` handles but **no
underlying `vtkRenderer`**. So labeled, numbered bounding-box axes (lon / lat /
elevation tick labels) — trivial with `vtkCubeAxesActor` — are impossible. The
`ui.axis` gizmo is orientation-only; the floor grid (`render.grid.*`) has no
per-tick data labels.

- **Wanted:** either a built-in labeled cube-axes feature, or an escape hatch to
  attach arbitrary VTK actors.

> **Addressed (`f3d_ext`).** The ext sources reach the `vtkRenderer` through the
> meta-importer hatch and add:
> - `f3d_ext_enable_cube_axes(window; edges, floor, grid, zlabels)` — labelled
>   `vtkCubeAxesActor` (X/Y tick labels, optional floor, wall gridlines, Z labels).
> - `f3d_ext_enable_image_axes(window, xfmt, yfmt)` — 2D map-style axes.
> - `f3d_ext_enable_colorbar(window, rgb, ncolors, vmin, vmax, ...)`.
> - `f3d_ext_add_lines(...)` / `remove_lines` / `clear_lines` — polyline overlays.
> The same renderer hatch underpins #8, #9 and #10. Covered by test
> "labelled cube axes (gap #2)" and "polyline overlays".

## 3. Image writers can't georeference (no GeoTIFF / metadata)

`f3d_image_save` is limited to PNG / JPG / TIF / BMP via VTK writers; the TIF branch
is a plain `vtkTIFFWriter` (no GeoKeys). `f3d_image_set_metadata` exists, but the
writers do not serialize it.

- **Impact:** GeoTIFF export must be done entirely outside f3d (GDAL / GMT).
- **Wanted:** georef/metadata-aware TIFF write, or at least metadata persisted by the
  TIFF writer.

> **Open.** `f3d_image_save` / `f3d_image_save_buffer` still take only the format
> enum; no GeoKeys / metadata serialization. GeoTIFF export stays in GDAL/GMT.

## 4. Setting (or getting) an unregistered option key SEGFAULTS

`f3d_options_set_as_*`, and even `f3d_options_get_as_bool`, on an unknown key crash
the process — no error or exception. We had to enumerate
`f3d_options_get_all_names` defensively before touching any non-core option.

- **Wanted:** return an error code instead of segfaulting on unknown keys.

> **Open (unverified on current build).** No code-level guard added in the binding;
> not re-tested against the current DLL. Keep enumerating
> `f3d_options_get_all_names` defensively.

## 5. No per-cell / per-face colour in the mesh struct

`f3d_mesh_t` has points / normals / texcoords / indices but **no per-cell colour
(cell-data) array**. Per-face colour has to be faked via a 1-pixel palette texture +
per-vertex UVs + vertex splitting.

- **Wanted:** an optional cell-data scalar / colour array on the mesh.

> **Addressed.** `f3d_mesh_t` now carries four optional arrays:
> `point_scalars`, `cell_scalars`, `point_colors`, `cell_colors` (with counts;
> see `src/libf3d.jl`). A back-compat constructor keeps geometry-only callers
> working. This also resolves the struct-level half of #9.

## 6. `render.show_edges` is global

Edges are all-or-nothing for the whole scene; there is no way to restrict the
wireframe to a subset of faces or to a single actor.

- **Wanted:** per-actor (or per-cell) edge visibility.

> **Addressed (`f3d_ext`).** Two functions, both drawing a separate flat-shaded
> (LightingOff) wireframe overlay through the renderer / meta-importer hatch:
> - `f3d_ext_set_edge_visibility(window, actor_index, on; r,g,b, width)` — show/hide a
>   coloured wireframe for one imported actor (index into the coloring-actor list) or
>   all (`actor_index = -1`).
> - `f3d_ext_add_cell_edges(window, actor_index, cell_ids; r,g,b, width)` — wireframe a
>   SUBSET of one actor's faces; `f3d_ext_remove_cell_edges` / `clear_cell_edges` undo.
>
> A dedicated overlay is used rather than the actor's native `EdgeVisibility` because
> f3d renders the coloring actors as PBR, whose edge pass ignores `EdgeColor` (native
> edges come out a dim, uncoloured grey). The overlay gives a crisp caller-chosen colour,
> persists across renders, and mirrors the source actor's transform at call time (lines
> up with a `render.model_scale` exaggeration; re-call after the scale changes). Covered
> by test "per-actor + per-cell edges (gap #6)" — suite 131/131.

## 7. No explicit orthographic / parallel-scale camera control

`f3d_camera_state_t` has only position / focal_point / view_up / **view_angle** —
no parallel-scale field. In `scene.camera.orthographic` mode you cannot set an exact
parallel scale; it has to be hacked via `f3d_camera_zoom()`. Worse,
`f3d_camera_reset_to_bounds` fits the bounding **sphere** (which includes the Z
relief), so a top-down map letterboxes — there is no "fit the XY extent only"
option. Producing an exact, border-free, georeferenced top-down export required an
empirical calibration render (render on a sentinel background, measure the data
bbox, then zoom to fill).

- **Wanted:** parallel-scale in the camera state; a "reset to bounds in the current
  view plane" / fit-to-2D-extent option.

> **Mostly addressed.** Re-checked against code (gmt_solids.jl + headers):
> - **Orthographic projection IS exposed** — `scene.camera.orthographic` bool option
>   (`options.h:356`), set for the top-down / mapexport path. The original "no ortho
>   control" claim was wrong.
> - **Parallel scale IS reachable** — `f3d_camera_zoom` adjusts the parallel scale in
>   parallel mode (`camera.h:81`). There is still no `parallel_scale` *field* in
>   `f3d_camera_state_t`, but zoom controls it, so exact scaling is achievable.
> - **Vertical exaggeration** solved separately: `render.model_scale` +
>   `f3d_ext_enable_vertical_scale_drag` (Ctrl+left-drag).
>
> **Residual (real but worked around):** no fit-to-XY-extent reset.
> `f3d_camera_reset_to_bounds` fits the bounding **sphere**, so Z relief inflates the
> radius and a top-down frame letterboxes. Worked around in gmt_solids.jl (~714-754):
> render once on a magenta sentinel background, scan the framebuffer for the data
> bbox, `f = min(cw/dx, ch/dy)`, `f3d_camera_zoom(f)` to fill exactly (min ⇒ never
> crops), restore bg, re-render. Output is correct and georeferenceable today; what's
> missing is a clean "reset to bounds in the current view plane" API to retire the
> calibration render.

## 8. No live mouse-coordinate readout (no move events, no pick, no custom text)

A common interactive-map feature is a small on-screen box that shows the data
coordinates under the cursor and updates as the mouse moves. Three separate pieces
are all missing:

- **Mouse-move events:** the interactor exposes only discrete commands / bindings
  (`f3d_interactor_add_command` / `add_binding` — keys, mouse *buttons*, wheel).
  There is no continuous mouse-move / hover callback.
- **Pixel → world conversion:** there is no `display_from_world` /
  `world_from_display` (unproject / pick) function, so a cursor pixel cannot be
  turned into a world (grid x/y/z) coordinate.
- **Custom text overlay:** only predefined `ui.*` overlays exist (filename,
  metadata, fps, ...). There is no API to set/update an arbitrary on-screen text
  box.

In VTK this is routine: a `MouseMoveEvent` observer + `vtkCoordinate` /
`vtkPropPicker` + a `vtkTextActor`. None of it is reachable through libf3d.

- **Wanted:** a mouse-move callback, a display↔world coordinate conversion (and/or
  a pick), and a settable custom text overlay.

> **Addressed (`f3d_ext`).** `f3d_ext_enable_coord_readout(window)` installs the
> mouse-move observer + pixel→world pick + on-screen text box (the three missing
> pieces, bundled). `f3d_ext_enable_focus_pick(window)` adds click-to-focus picking.
> Covered by test "coordinate readout (gap #8)".

## 9. Point sprites ignore texture coords → no per-point colour for splats

A point cloud (mesh with empty `face_sides` / `face_indices`) renders fine, and
the plain `GL_POINTS` path honours `model.color.texture` + per-point texcoords
(our 1×N palette trick), so colour-by-value works. But enabling
`model.point_sprites` switches to `vtkPointGaussianMapper`, which does **not**
sample texture coordinates — every splat falls back to the flat grey material.

- **Wanted:** a per-point scalar / colour array on the mesh (see #5) that the
  point-sprite mapper colours by, or texcoord support in the sprite mapper.

> **Addressed (`f3d_ext`).** `f3d_ext_color_point_sprites(window, rgb, n_points,
> n_comp)` bakes a per-point RGB(A) `vtkUnsignedCharArray` onto the point-sprite
> polydata and switches the `vtkPointGaussianMapper` to direct scalar colours. The
> splat SHAPE is a stock option: `model.point_sprites.type`
> ("sphere"/"circle"/"gaussian"). `view_points(...; sprites=true)` wires both
> (kwarg `splat=`). The struct-level per-point colour array now also exists (see #5:
> `f3d_mesh_t.point_colors`). Covered by test "coloured point sprites (gap #9)".

## 10. No interactive area / rubber-band point selection

Drag-a-rectangle to select the points inside it — a staple of point-cloud / LIDAR
tools — was impossible: stock libf3d exposes no custom interactor style, no
press-move-release drag stream, no renderer/picker access, and no selected-id
readback.

- **Wanted:** an area/frustum pick (returning point/cell ids) plus the drag events
  and renderer access it needs — or a high-level "selection" callback.

> **Addressed (`f3d_ext`).** `f3d_ext_enable_rubber_band_pick(window, callback,
> user_data, r, g, b)` installs a Ctrl+right-drag rubber-band selection that
> highlights the picked points (caller-set colour) and returns the selected point
> ids to the callback; `f3d_ext_set_rubber_band_armed` / `get_rubber_band_armed`
> gate it. `f3d_ext_area_pick_points(window, x0, y0, x1, y1, count)` is the
> direct (non-interactive) area pick, returning an id array freed by
> `f3d_ext_free_ids`. Covered by test "rubber-band area pick + highlight".

---

## Remaining open

- **#3** GeoTIFF / metadata-aware image write.
- **#4** segfault on unknown option key — CONFIRMED real (2026-06-04): a build whose
  `render.model_scale` registration was missing crashed the process the moment that key
  was set, with no error. Still no guard in the C API.
- **#7 (camera)** only a clean fit-to-XY-extent reset is missing (sphere-fit
  letterboxes top-down; currently worked around by the sentinel-calibration render).
  Ortho projection, parallel scale (via zoom), and vertical exaggeration are done.
