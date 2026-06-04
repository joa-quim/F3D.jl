# Demo: per-actor and per-cell edge (wireframe) control — gap #6.
#
#   include("examples/edges_demo.jl")
#   edges_demo()                      # saves 3 PNGs to tempdir() and prints the paths
#   edges_demo(interactive=true)      # opens a live window with the magenta wireframe
#   edges_demo(subset=true, interactive=true)   # only a subset of faces, in green
#
# Stock libf3d's `render.show_edges` is global (all actors or none). The f3d_ext
# build adds per-actor / per-cell control, each drawing a separate flat-shaded
# (LightingOff) wireframe overlay through the renderer hatch — f3d renders the
# coloring actors as PBR, whose native edge pass ignores the edge colour, so a
# dedicated overlay is used to get a crisp, caller-chosen colour:
#
#   f3d_ext_set_edge_visibility(window, actor_index, on; r, g, b, width)
#       actor_index = 0-based into the imported coloring actors; -1 = all actors.
#       on != 0 shows a coloured wireframe; on = 0 hides it.
#
#   f3d_ext_add_cell_edges(window, actor_index, cell_ids; r, g, b, width) -> id
#   f3d_ext_remove_cell_edges(window, id)  /  f3d_ext_clear_cell_edges(window)
#       outline only the listed faces (cell ids) of one actor.
#
# These symbols exist only in the extended f3d_ext build; on a stock DLL they are
# absent (the demo checks and warns).

using F3D
using Libdl

# Is this the extended f3d_ext build?
_has_f3d_ext() =
    Libdl.dlsym(Libdl.dlopen(F3D.libf3d), :f3d_ext_set_edge_visibility; throw_error = false) !== nothing

# A coarse bumpy grid surface (10x10) — coarse on purpose so individual wireframe
# cells are clearly visible (a dense grid renders the wireframe as a solid fill).
function _grid(n = 10)
    xs = range(-3, 3; length = n)
    pts = Float32[]; nrm = Float32[]
    for j in 1:n, i in 1:n
        x = xs[i]; y = xs[j]; z = 1.5f0 * exp(-(x^2 + y^2) / 5) * cos(1.3x)
        append!(pts, (x, y, z)); append!(nrm, (0, 0, 1))
    end
    sd = UInt32[]; fc = UInt32[]; idx(i, j) = (j - 1) * n + (i - 1)
    for j in 1:n-1, i in 1:n-1
        a, b, c, d = idx(i, j), idx(i+1, j), idx(i+1, j+1), idx(i, j+1)
        append!(sd, (3, 3)); append!(fc, (a, b, c, a, c, d))
    end
    return pts, nrm, sd, fc, 2 * (n - 1) * (n - 1)   # last = number of triangle cells
end

"""
    edges_demo(; interactive=false, subset=false, outdir=tempdir())

Show gap #6 edge control on a coarse terrain grid in an oblique 3-D view.

- `subset=false`: a full magenta wireframe over the whole surface (per-actor).
- `subset=true`:  a green wireframe on only the first third of the faces (per-cell).
- `interactive=false`: render offscreen and save PNG(s) to `outdir`, returning the paths.
- `interactive=true`:  open a live window (orbit with the mouse; press `q`/Esc to close).
"""
function edges_demo(; interactive::Bool = false, subset::Bool = false, outdir::AbstractString = tempdir())
    if !_has_f3d_ext()
        @warn "This libf3d has no f3d_ext edge symbols (stock DLL) — nothing to show."
        return nothing
    end

    F3D.f3d_engine_autoload_plugins()
    e = F3D.f3d_engine_create(Cint(interactive ? 0 : 1))   # 0 = onscreen, 1 = hidden
    scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
    opts = F3D.f3d_engine_get_options(e)
    F3D.f3d_window_set_size(window, Cint(600), Cint(450))
    # terrain look: Z is up, X/Y on the floor
    F3D.f3d_options_set_as_string_representation(opts, "scene.up_direction", "+Z")

    pts, nrm, sd, fc, ncell = _grid()
    # GC.@preserve must span every render that touches the mesh, so keep it open
    # across the whole body (f3d reads the buffers lazily on each render).
    GC.@preserve pts nrm sd fc begin
        mesh = Ref(F3D.f3d_mesh_t(
            pointer(pts), Csize_t(length(pts)), pointer(nrm), Csize_t(length(nrm)),
            C_NULL, Csize_t(0), pointer(sd), Csize_t(length(sd)), pointer(fc), Csize_t(length(fc))))
        @assert F3D.f3d_scene_add_mesh(scene, mesh) == 1

        cam = F3D.f3d_window_get_camera(window)
        F3D.f3d_camera_reset_to_bounds(cam, Cdouble(0.85))
        F3D.f3d_camera_azimuth(cam, Cdouble(-35))      # orbit for an oblique 3-D view
        F3D.f3d_camera_elevation(cam, Cdouble(-25))

        if subset
            # outline only the first third of the faces, in green
            ids = collect(0:(ncell ÷ 3))
            F3D.f3d_ext_add_cell_edges(window, 0, ids; r = 0.0, g = 1.0, b = 0.0, width = 3.0)
        else
            # full wireframe for actor 0, in magenta
            F3D.f3d_ext_set_edge_visibility(window, 0, 1; r = 1.0, g = 0.0, b = 1.0, width = 2.0)
        end

        F3D.f3d_window_render(window)

        if interactive
            println("Opening window — orbit with the mouse, press q/Esc to close.")
            F3D.f3d_interactor_start(F3D.f3d_engine_get_interactor(e))
            F3D.f3d_engine_delete(e)
            return nothing
        end

        # offscreen: save the framed result
        function _save(name)
            img = F3D.f3d_window_render_to_image(window, Cint(0))
            F3D.f3d_image_save(img, name, F3D.f3d_image_save_format_t(0))
            F3D.f3d_image_delete(img)
            return name
        end
        out = _save(joinpath(outdir, subset ? "edges_demo_subset.png" : "edges_demo_wireframe.png"))
        F3D.f3d_engine_delete(e)
        println("saved ", out)
        return out
    end
end
