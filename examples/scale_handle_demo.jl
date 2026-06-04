# Demo: Fledermaus-style vertical-scale / tilt / azimuth gizmo at the focal point.
#
#   include("examples/scale_handle_demo.jl")
#   scale_handle_demo()                 # saves a PNG to tempdir() and prints the path
#   scale_handle_demo(interactive=true) # live window; drag the handles
#
# The gizmo is pinned to the camera focal point (the rotation centre). Left-drag:
#   * vertical arrowhead cone -> vertical scale (render.model_scale z); the shaft is a
#     fixed length, the cone stretches to show the exaggeration. Ctrl+left-drag also
#     scales anywhere.
#   * horizontal arrows -> tilt (camera elevation about the horizontal axis).
#   * compass ring -> azimuth (camera rotation about the vertical axis); red N marker.
#
#   f3d_ext_enable_scale_handle(window, options, sensitivity)   # <=0 -> default 0.01
#   f3d_ext_disable_scale_handle(window)
#
# f3d_ext build only; a stock DLL lacks the symbol (the demo checks and warns).

using F3D
using Libdl

_has_f3d_ext() =
    Libdl.dlsym(Libdl.dlopen(F3D.libf3d), :f3d_ext_enable_scale_handle; throw_error=false) !== nothing

function _grid(n=12)
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
    return pts, nrm, sd, fc
end

"""
    scale_handle_demo(; interactive=false, outdir=tempdir())

Show the focal-point interaction gizmo on a coarse terrain grid in an oblique view.
`interactive=false` renders offscreen and saves a PNG; `interactive=true` opens a live
window so the handles can be dragged.
"""
function scale_handle_demo(; interactive::Bool=false, outdir::AbstractString=tempdir())
    if !_has_f3d_ext()
        @warn "This libf3d has no f3d_ext_enable_scale_handle symbol (stock DLL)."
        return nothing
    end

    F3D.f3d_engine_autoload_plugins()
    e = F3D.f3d_engine_create(Cint(interactive ? 0 : 1))   # 0 = onscreen, 1 = hidden
    scene = F3D.f3d_engine_get_scene(e); window = F3D.f3d_engine_get_window(e)
    opts = F3D.f3d_engine_get_options(e)
    F3D.f3d_window_set_size(window, Cint(700), Cint(525))
    F3D.f3d_options_set_as_string_representation(opts, "scene.up_direction", "+Z")

    pts, nrm, sd, fc = _grid()
    GC.@preserve pts nrm sd fc begin
        mesh = Ref(F3D.f3d_mesh_t(
            pointer(pts), Csize_t(length(pts)), pointer(nrm), Csize_t(length(nrm)),
            C_NULL, Csize_t(0), pointer(sd), Csize_t(length(sd)), pointer(fc), Csize_t(length(fc))))
        @assert F3D.f3d_scene_add_mesh(scene, mesh) == 1

        cam = F3D.f3d_window_get_camera(window)
        F3D.f3d_camera_reset_to_bounds(cam, Cdouble(0.7))
        F3D.f3d_camera_azimuth(cam, Cdouble(-35))
        F3D.f3d_camera_elevation(cam, Cdouble(-25))
        F3D.f3d_window_render(window)               # first render: import data actors

        # gizmo needs the interactor; create it then enable after the first render
        interactor = F3D.f3d_engine_get_interactor(e)
        @assert F3D.f3d_ext_enable_scale_handle(window, opts, Cdouble(0.01)) == 1
        F3D.f3d_window_render(window)

        if interactive
            println("Opening window — drag the cone (vscale), arrows (tilt), ring (azimuth). q/Esc to close.")
            F3D.f3d_interactor_start(interactor, Cdouble(1.0 / 30))
            F3D.f3d_engine_delete(e)
            return nothing
        end

        img = F3D.f3d_window_render_to_image(window, Cint(0))
        out = joinpath(outdir, "scale_handle_demo.png")
        F3D.f3d_image_save(img, out, F3D.f3d_image_save_format_t(0))
        F3D.f3d_image_delete(img)
        F3D.f3d_engine_delete(e)
        println("saved ", out)
        return out
    end
end
