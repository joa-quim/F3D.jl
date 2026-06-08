# Tests for the extended F3D functionality added on top of the stock libf3d:
#   - render.model_scale          (anisotropic actor scale / vertical exaggeration)
#   - in-memory base color texture (gap #1, no temp file)
#   - per-point mesh colors        (gap #5)
#   - f3d_ext interactions: vertical-scale drag, coordinate readout,
#     rubber-band area pick (+ highlight), labelled cube axes (gap #2)
#
# These need a libf3d built with the model_scale option + the c/f3d_ext_*.cxx
# sources (see f3d_GIT/c/f3d_ext_REBUILD.md). On a stock DLL the symbols are
# absent, so the whole set is skipped — keeping CI green on the shipped binary.
#
# The helpers and per-feature blocks double as minimal usage examples for the docs.

using Test, F3D
using Libdl

# ----- capability probe: is this the extended build? --------------------------
function _has_f3d_ext()
    h = Libdl.dlopen(F3D.libf3d)
    Libdl.dlsym(h, :f3d_ext_enable_cube_axes; throw_error = false) !== nothing
end

# rubber-band pick callback: a plain (non-closure) cfunction + a global counter.
const _PICKED = Ref(0)
_pickcb(ids::Ptr{Csize_t}, count::Csize_t, ::Ptr{Cvoid})::Cvoid = (_PICKED[] = Int(count); nothing)

# ----- shared geometry builders (reused by the examples below) ----------------

# A bumpy grid surface (triangulated). Returns (points, normals, sides, faces).
function _grid_surface(n = 40)
    xs = range(-3, 3; length = n); ys = range(-3, 3; length = n)
    pts = Float32[]; nrm = Float32[]
    for j in 1:n, i in 1:n
        x = xs[i]; y = ys[j]; z = 2 * exp(-(x^2 + y^2) / 4) * cos(2x)
        append!(pts, (x, y, z)); append!(nrm, (0, 0, 1))
    end
    sd = UInt32[]; fc = UInt32[]; idx(i, j) = (j - 1) * n + (i - 1)
    for j in 1:n-1, i in 1:n-1
        a, b, c, d = idx(i, j), idx(i+1, j), idx(i+1, j+1), idx(i, j+1)
        append!(sd, (3, 3)); append!(fc, (a, b, c, a, c, d))
    end
    return pts, nrm, sd, fc
end

# A point cloud (same grid, no faces).
function _point_cloud(n = 30)
    xs = range(-3, 3; length = n); ys = range(-3, 3; length = n); pts = Float32[]
    for j in 1:n, i in 1:n
        x = xs[i]; y = ys[j]; z = 2 * exp(-(x^2 + y^2) / 4) * cos(2x); append!(pts, (x, y, z))
    end
    return pts
end

# Build engine/scene/window (offscreen) at a given size.
function _engine(w = 400, h = 400)
    F3D.f3d_engine_autoload_plugins()
    e = F3D.f3d_engine_create(Cint(1))
    F3D.f3d_window_set_size(F3D.f3d_engine_get_window(e), Cint(w), Cint(h))
    return e
end

# Vertical pixel span of the non-transparent object (render with transparent bg).
function _vspan(window)
    img = F3D.f3d_window_render_to_image(window, Cint(1))
    w = Int(F3D.f3d_image_get_width(img)); h = Int(F3D.f3d_image_get_height(img))
    ch = Int(F3D.f3d_image_get_channel_count(img))
    px = unsafe_wrap(Array, Ptr{UInt8}(F3D.f3d_image_get_content(img)), w*h*ch; own = false)
    rmin, rmax = h + 1, -1
    for r in 1:h, c in 1:w
        if px[((r-1)*w + (c-1))*ch + 4] > 0
            rmin = min(rmin, r); rmax = max(rmax, r)
        end
    end
    F3D.f3d_image_delete(img)
    return rmax < 0 ? 0 : rmax - rmin + 1
end

# Count pixels matching a predicate over the RGB(A) buffer (no_background=0).
function _count_px(window, pred)
    img = F3D.f3d_window_render_to_image(window, Cint(0))
    w = Int(F3D.f3d_image_get_width(img)); h = Int(F3D.f3d_image_get_height(img))
    ch = Int(F3D.f3d_image_get_channel_count(img))
    px = unsafe_wrap(Array, Ptr{UInt8}(F3D.f3d_image_get_content(img)), w*h*ch; own = false)
    n = 0
    for k in 1:w*h
        i = (k-1)*ch + 1
        pred(px[i], px[i+1], px[i+2]) && (n += 1)
    end
    F3D.f3d_image_delete(img)
    return n
end

_set_cam!(window, pos, foc, up) = begin
    cam = F3D.f3d_window_get_camera(window)
    p = Cdouble.(collect(pos)); f = Cdouble.(collect(foc)); u = Cdouble.(collect(up))
    GC.@preserve p f u begin
        F3D.f3d_camera_set_position(cam, pointer(p))
        F3D.f3d_camera_set_focal_point(cam, pointer(f))
        F3D.f3d_camera_set_view_up(cam, pointer(u))
    end
    cam
end

_mesh_ref(p, nm, s, f) = Ref(F3D.f3d_mesh_t(
    isempty(p) ? C_NULL : pointer(p),  Csize_t(length(p)),
    isempty(nm) ? C_NULL : pointer(nm), Csize_t(length(nm)),
    C_NULL, Csize_t(0),
    isempty(s) ? C_NULL : pointer(s),  Csize_t(length(s)),
    isempty(f) ? C_NULL : pointer(f),  Csize_t(length(f)),
))

# =============================================================================

@testset "F3D extensions (model_scale + f3d_ext)" begin
    if !_has_f3d_ext()
        @info "Extended libf3d not detected (stock DLL) — skipping f3d_ext tests"
        @test_skip true
    else
        @testset "render.model_scale exaggerates Z" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            opts = F3D.f3d_engine_get_options(e)
            # wall quad in x-z plane; camera on +Y so z maps to screen vertical
            pts = Float32[0,0,0, 1,0,0, 0,0,1, 1,0,1]; nrm = Float32[0,1,0,0,1,0,0,1,0,0,1,0]
            sd = UInt32[3,3]; fc = UInt32[0,1,2,1,3,2]
            GC.@preserve pts nrm sd fc begin
                @test F3D.f3d_scene_add_mesh(scene, _mesh_ref(pts, nrm, sd, fc)) == 1
            end
            _set_cam!(window, (0.5,30,0.5), (0.5,0,0.5), (0,0,1))
            setz(z) = (v = Cdouble[1,1,z]; GC.@preserve v F3D.f3d_options_set_as_double_vector(opts, "render.model_scale", pointer(v), Csize_t(3)))
            setz(8.0); F3D.f3d_window_render(window); s8 = _vspan(window)
            setz(1.0); F3D.f3d_window_render(window); s1 = _vspan(window)
            @test s8 > s1 * 3
            F3D.f3d_engine_delete(e)
        end

        @testset "in-memory base color texture (gap #1)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            F3D.f3d_options_set_as_bool(F3D.f3d_engine_get_options(e), "model.unlit", true)  # full-strength texels
            texels = UInt8[255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,0,255]  # 2x2 RGBA
            img = F3D.f3d_image_new_params(Cuint(2), Cuint(2), Cuint(4), F3D.f3d_image_channel_type_t(0))
            pts = Float32[0,0,0, 1,0,0, 0,1,0, 1,1,0]; nrm = Float32[0,0,1,0,0,1,0,0,1,0,0,1]
            tex = Float32[0,0, 1,0, 0,1, 1,1]; sd = UInt32[3,3]; fc = UInt32[0,1,2,1,3,2]
            GC.@preserve texels pts nrm tex sd fc begin
                F3D.f3d_image_set_content(img, pointer(texels))
                F3D.f3d_window_set_color_texture(window, img)
                mesh = Ref(F3D.f3d_mesh_t(pointer(pts),Csize_t(12),pointer(nrm),Csize_t(12),pointer(tex),Csize_t(8),pointer(sd),Csize_t(2),pointer(fc),Csize_t(6)))
                @test F3D.f3d_scene_add_mesh(scene, mesh) == 1
            end
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.9))
            F3D.f3d_window_render(window)
            reds = _count_px(window, (r,g,b) -> r > 150 && g < 120 && b < 120)
            blues = _count_px(window, (r,g,b) -> b > 150 && r < 120 && g < 120)
            @test reds > 50 && blues > 50      # texture colors present, no temp file
            F3D.f3d_image_delete(img); F3D.f3d_engine_delete(e)
        end

        @testset "vertical-scale drag (Ctrl+left)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            opts = F3D.f3d_engine_get_options(e)
            pts = Float32[0,0,0, 1,0,0, 0,0,1, 1,0,1]; nrm = Float32[0,1,0,0,1,0,0,1,0,0,1,0]
            sd = UInt32[3,3]; fc = UInt32[0,1,2,1,3,2]
            GC.@preserve pts nrm sd fc F3D.f3d_scene_add_mesh(scene, _mesh_ref(pts, nrm, sd, fc))
            _set_cam!(window, (0.5,30,0.5), (0.5,0,0.5), (0,0,1))
            @test F3D.f3d_ext_enable_vertical_scale_drag(window, opts, Cdouble(0.02)) == 1
            it = F3D.f3d_engine_get_interactor(e); F3D.f3d_interactor_init_commands(it); F3D.f3d_interactor_init_bindings(it)
            F3D.f3d_window_render(window); before = _vspan(window)
            # synthetic Ctrl+left-drag up (set Ctrl right before press; moves keep the drag flag)
            F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(200), Cdouble(350))
            F3D.f3d_interactor_trigger_mod_update(it, F3D.F3D_INTERACTOR_INPUT_CTRL)
            F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_PRESS, F3D.F3D_INTERACTOR_MOUSE_LEFT)
            for y in (250, 150, 50); F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(200), Cdouble(y)); end
            F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_RELEASE, F3D.F3D_INTERACTOR_MOUSE_LEFT)
            F3D.f3d_window_render(window); after = _vspan(window)
            @test after > before * 1.5
            F3D.f3d_engine_delete(e)
        end

        @testset "scale-handle gizmo (Fledermaus)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            opts = F3D.f3d_engine_get_options(e)
            pts = Float32[0,0,0, 1,0,0, 0,0,1, 1,0,1]; nrm = Float32[0,1,0,0,1,0,0,1,0,0,1,0]
            sd = UInt32[3,3]; fc = UInt32[0,1,2,1,3,2]
            GC.@preserve pts nrm sd fc F3D.f3d_scene_add_mesh(scene, _mesh_ref(pts, nrm, sd, fc))
            _set_cam!(window, (0.5,30,0.5), (0.5,0,0.5), (0,0,1))
            it = F3D.f3d_engine_get_interactor(e); F3D.f3d_interactor_init_commands(it); F3D.f3d_interactor_init_bindings(it)
            F3D.f3d_window_render(window)
            @test F3D.f3d_ext_enable_scale_handle(window, opts, Cdouble(0.02)) == 1
            F3D.f3d_window_render(window)
            # the gizmo keeps Ctrl+left-drag = vertical scale; test that pixel-free path.
            # (the gizmo's own props pollute a vspan metric, so assert the model_scale
            # option the gesture drives instead.)
            F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(200), Cdouble(350))
            F3D.f3d_interactor_trigger_mod_update(it, F3D.F3D_INTERACTOR_INPUT_CTRL)
            F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_PRESS, F3D.F3D_INTERACTOR_MOUSE_LEFT)
            for y in (250, 150, 50); F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(200), Cdouble(y)); end
            F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_RELEASE, F3D.F3D_INTERACTOR_MOUSE_LEFT)
            ms = unsafe_string(F3D.f3d_options_get_as_string_representation(opts, "render.model_scale"))
            zfac = parse(Float64, split(ms, ",")[end])
            @test zfac > 1.5            # drag-up exaggerated the vertical scale
            F3D.f3d_ext_disable_scale_handle(window)
            F3D.f3d_engine_delete(e)
        end

        @testset "coordinate readout (gap #8)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            p, nm, s, f = _grid_surface()
            GC.@preserve p nm s f F3D.f3d_scene_add_mesh(scene, _mesh_ref(p, nm, s, f))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.9))
            it = F3D.f3d_engine_get_interactor(e); F3D.f3d_interactor_init_commands(it); F3D.f3d_interactor_init_bindings(it)
            @test F3D.f3d_ext_enable_coord_readout(window) == 1
            F3D.f3d_window_render(window)
            white(r,g,b) = r > 180 && g > 180 && b > 180
            F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(200), Cdouble(200))
            F3D.f3d_window_render(window)
            @test _count_px(window, white) > 20      # readout text drawn
            F3D.f3d_engine_delete(e)
        end

        @testset "rubber-band area pick + highlight" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            opts = F3D.f3d_engine_get_options(e)
            F3D.f3d_options_set_as_double(opts, "render.point_size", Cdouble(6))
            cloud = _point_cloud()
            _PICKED[] = 0
            cb = @cfunction(_pickcb, Cvoid, (Ptr{Csize_t}, Csize_t, Ptr{Cvoid}))
            GC.@preserve cloud F3D.f3d_scene_add_mesh(scene, _mesh_ref(cloud, Float32[], UInt32[], UInt32[]))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.9))
            it = F3D.f3d_engine_get_interactor(e); F3D.f3d_interactor_init_commands(it); F3D.f3d_interactor_init_bindings(it)
            # highlight colour is caller-set; use red so the redpx() checks below match
            @test F3D.f3d_ext_enable_rubber_band_pick(window, cb, C_NULL, 1.0, 0.0, 0.0) == 1
            F3D.f3d_window_render(window)
            redpx() = _count_px(window, (r,g,b) -> r > 200 && g < 80 && b < 80)
            # box-select fires only on Ctrl+right-drag (Ctrl checked at button press;
            # trigger_mouse_position resets the modifier, so set it right before press).
            function dragbox(ctrl::Bool)
                F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(60), Cdouble(60))
                ctrl && F3D.f3d_interactor_trigger_mod_update(it, F3D.F3D_INTERACTOR_INPUT_CTRL)
                F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_PRESS, F3D.F3D_INTERACTOR_MOUSE_RIGHT)
                F3D.f3d_interactor_trigger_mod_update(it, F3D.F3D_INTERACTOR_INPUT_NONE)
                for p in ((180,180),(320,320)); F3D.f3d_interactor_trigger_mouse_position(it, Cdouble(p[1]), Cdouble(p[2])); end
                F3D.f3d_interactor_trigger_mouse_button(it, F3D.F3D_INTERACTOR_INPUT_RELEASE, F3D.F3D_INTERACTOR_MOUSE_RIGHT)
                F3D.f3d_window_render(window)
            end
            npts = length(cloud) ÷ 3
            dragbox(false)                     # plain right-drag -> normal nav, no selection
            @test _PICKED[] == 0
            dragbox(true)                      # Ctrl+right-drag -> select
            @test _PICKED[] > 0                # ids returned to Julia
            @test _PICKED[] < npts             # a SUBSET, not all points (regression guard)
            @test redpx() > 30                 # red highlight on
            dragbox(true)                      # same box again -> toggle off
            @test _PICKED[] == 0               # deselected
            @test redpx() < 10                 # highlight cleared
            F3D.f3d_engine_delete(e)
        end

        @testset "coloured point sprites (gap #9)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            opts = F3D.f3d_engine_get_options(e)
            # round sprites (vtkPointGaussianMapper) — ignores texcoords, so per-point
            # colour must be baked via f3d_ext_color_point_sprites.
            F3D.f3d_options_set_as_bool(opts, "model.point_sprites.enable", true)
            F3D.f3d_options_set_as_string(opts, "model.point_sprites.type", "sphere")
            F3D.f3d_options_set_as_double(opts, "model.point_sprites.size", Cdouble(30))
            cloud = _point_cloud()                       # 30x30 = 900 points
            np = length(cloud) ÷ 3
            GC.@preserve cloud F3D.f3d_scene_add_mesh(scene, _mesh_ref(cloud, Float32[], UInt32[], UInt32[]))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.9))
            F3D.f3d_window_render(window)                # sprite actor built here
            # before colouring: uniform grey material -> no strong red/blue
            redpx(w)  = _count_px(w, (r,g,b) -> r > 120 && g < 80 && b < 80)
            bluepx(w) = _count_px(w, (r,g,b) -> b > 120 && r < 80 && g < 80)
            @test redpx(window) < 10 && bluepx(window) < 10
            # half the points red, half blue
            rgb = Vector{UInt8}(undef, 3np)
            @inbounds for i in 1:np
                if i <= np ÷ 2
                    rgb[3i-2] = 0xff; rgb[3i-1] = 0x00; rgb[3i] = 0x00
                else
                    rgb[3i-2] = 0x00; rgb[3i-1] = 0x00; rgb[3i] = 0xff
                end
            end
            GC.@preserve rgb begin
                @test F3D.f3d_ext_color_point_sprites(window, pointer(rgb), Csize_t(np), Cint(3)) == 1
            end
            F3D.f3d_window_render(window)
            @test redpx(window) > 30 && bluepx(window) > 30   # both per-point colours show
            F3D.f3d_engine_delete(e)
        end

        @testset "labelled cube axes (gap #2)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            p, nm, s, f = _grid_surface()
            GC.@preserve p nm s f F3D.f3d_scene_add_mesh(scene, _mesh_ref(p, nm, s, f))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.7))
            F3D.f3d_window_render(window)
            @test F3D.f3d_ext_enable_cube_axes(window) == 1   # minimal default (edges + floor)
            F3D.f3d_window_render(window)
            # re-enable with walls + Z labels (flag path), then floor-only, then disable
            @test F3D.f3d_ext_enable_cube_axes(window; grid = true, zlabels = true) == 1
            F3D.f3d_window_render(window)
            @test F3D.f3d_ext_enable_cube_axes(window; edges = false, floor = true) == 1
            F3D.f3d_window_render(window)
            @test F3D.f3d_ext_enable_cube_axes(window, F3D.F3D_EXT_CUBE_AXES_DEFAULT) == 1
            F3D.f3d_window_render(window)
            F3D.f3d_ext_disable_cube_axes(window)
            F3D.f3d_window_render(window)
            F3D.f3d_engine_delete(e)
        end

        @testset "polyline overlays (f3d_ext_add_lines)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            p, nm, s, f = _grid_surface()
            GC.@preserve p nm s f F3D.f3d_scene_add_mesh(scene, _mesh_ref(p, nm, s, f))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.7))
            F3D.f3d_window_render(window)
            redpx() = _count_px(window, (r,g,b) -> r > 200 && g < 80 && b < 80)
            @test redpx() < 10                       # no red before the line

            # a thick red polyline riding above the surface (z=3 > surface max ~2)
            n = 20
            pts = Cdouble[]
            for i in 1:n
                x = -3 + 6 * (i - 1) / (n - 1); append!(pts, (x, 0.0, 3.0))
            end
            npts = length(pts) ÷ 3
            id = F3D.f3d_ext_add_lines(window, pts, npts, nothing, 0,
                                       Cdouble[1.0, 0.0, 0.0], nothing, 6.0, 1)
            @test id >= 1                            # got a line-set id
            F3D.f3d_window_render(window)
            @test redpx() > 30                       # red line drawn on top

            F3D.f3d_ext_remove_lines(window, id)     # remove that set by id
            F3D.f3d_window_render(window)
            @test redpx() < 10

            # two polylines in ONE call via line_sizes; per-vertex (green) colour
            pts2 = Cdouble[]
            for i in 1:n; x = -3 + 6*(i-1)/(n-1); append!(pts2, (x, -1.0, 3.0)); end
            for i in 1:n; x = -3 + 6*(i-1)/(n-1); append!(pts2, (x,  1.0, 3.0)); end
            np2 = length(pts2) ÷ 3
            sizes = Cuint[n, n]
            vrgb = fill(0x00, 3 * np2); @inbounds for i in 1:np2; vrgb[3i-1] = 0xff; end  # green
            id2 = F3D.f3d_ext_add_lines(window, pts2, np2, sizes, 2, nothing, vrgb, 6.0, 1)
            @test id2 >= 1
            F3D.f3d_window_render(window)
            greenpx() = _count_px(window, (r,g,b) -> g > 200 && r < 80 && b < 80)
            @test greenpx() > 30                     # per-vertex coloured lines drawn

            F3D.f3d_ext_clear_lines(window)          # remove ALL line sets
            F3D.f3d_window_render(window)
            @test greenpx() < 10
            F3D.f3d_engine_delete(e)
        end

        @testset "per-actor + per-cell edges (gap #6)" begin
            e = _engine(); scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
            n = 40
            p, nm, s, f = _grid_surface(n)
            GC.@preserve p nm s f F3D.f3d_scene_add_mesh(scene, _mesh_ref(p, nm, s, f))
            F3D.f3d_camera_reset_to_bounds(F3D.f3d_window_get_camera(window), Cdouble(0.7))
            F3D.f3d_window_render(window)
            # NOTE: leave render.show_edges UNSET so f3d's per-render push can't clobber the
            # per-actor state (the whole point of gap #6).
            magenta() = _count_px(window, (r,g,b) -> r > 180 && g < 80 && b > 180)
            green()   = _count_px(window, (r,g,b) -> g > 160 && r < 100 && b < 100)
            @test magenta() < 10                                  # no edges yet

            # --- per-actor: turn edges on for actor 0 in magenta ---
            @test F3D.f3d_ext_set_edge_visibility(window, 0, 1; r=1.0, g=0.0, b=1.0, width=2.0) == 1
            F3D.f3d_window_render(window)
            @test magenta() > 30                                  # wireframe drawn
            # survives a re-render (persists across f3d's per-render option push)
            F3D.f3d_window_render(window)
            @test magenta() > 30
            # turn back off
            @test F3D.f3d_ext_set_edge_visibility(window, 0, 0) == 1
            F3D.f3d_window_render(window)
            @test magenta() < 10
            # -1 = all actors
            @test F3D.f3d_ext_set_edge_visibility(window, -1, 1; r=1.0, g=0.0, b=1.0, width=2.0) == 1
            F3D.f3d_window_render(window)
            @test magenta() > 30
            @test F3D.f3d_ext_set_edge_visibility(window, -1, 0) == 1
            F3D.f3d_window_render(window)
            @test magenta() < 10
            # out-of-range index -> 0 (no actor changed)
            @test F3D.f3d_ext_set_edge_visibility(window, 99, 1) == 0

            # --- per-cell: wireframe a SUBSET of faces (first 200 cells) in green ---
            ncell = 2 * (n - 1) * (n - 1)                         # two tris per quad
            subset = collect(0:199)
            @test green() < 10
            id = F3D.f3d_ext_add_cell_edges(window, 0, subset; r=0.0, g=1.0, b=0.0, width=2.0)
            @test id >= 1
            F3D.f3d_window_render(window)
            @test green() > 30                                    # subset wireframe shown
            # remove it -> gone
            F3D.f3d_ext_remove_cell_edges(window, id)
            F3D.f3d_window_render(window)
            @test green() < 10
            # add two sets, clear all
            id1 = F3D.f3d_ext_add_cell_edges(window, 0, subset; r=0.0, g=1.0, b=0.0)
            id2 = F3D.f3d_ext_add_cell_edges(window, 0, collect(200:399); r=0.0, g=1.0, b=0.0)
            @test id1 >= 1 && id2 >= 1 && id2 != id1
            F3D.f3d_window_render(window)
            @test green() > 30
            F3D.f3d_ext_clear_cell_edges(window)
            F3D.f3d_window_render(window)
            @test green() < 10
            F3D.f3d_engine_delete(e)
        end
    end
end
