# Regression guard for the rotation-centre gizmo (Fledermaus scale handle: compass/tilt rings
# + vertical cone) default in examples/gmt_solids.jl.
#
# The gizmo default once silently regressed — view_grid's wrapper stopped flipping it on and
# the rings vanished — and NO test caught it, because the gmt_solids.jl wrapper layer (the
# functions users actually call) had zero coverage; only the low-level
# f3d_ext_enable_scale_handle C binding was tested (test_f3d_ext.jl), and it kept passing.
#
# Both viewers now bind their `scale_handle` kwarg default to the single const
# SHOW_ROTATION_RINGS, so the rings are enabled by the EXACT same procedure and cannot desync.
# This asserts that const is on AND that both viewer signatures actually reference it (a source
# check: catches someone flipping the const, or hardcoding a different per-viewer default).
#
# gmt_solids.jl needs GMT; skip cleanly when GMT isn't installed so the core C-API suite still
# runs standalone.

@testset "rotation-ring gizmo default (view_grid + view_points)" begin
    if Base.find_package("GMT") === nothing
        @info "GMT not installed — skipping rotation-ring gizmo default test"
        @test_skip true
    else
        gmt_solids = joinpath(@__DIR__, "..", "examples", "gmt_solids.jl")
        include(gmt_solids)

        # Single source of truth: the gizmo (rotation rings) is ON by default.
        @test SHOW_ROTATION_RINGS === true

        # Both viewers must take their scale_handle default FROM that const — identical
        # procedure, no per-viewer divergence. Verified against the source signatures.
        src = read(gmt_solids, String)
        @test occursin(r"function\s+_view_fv_impl\b"s, src)
        @test occursin(r"function\s+view_points\b"s, src)
        # Each signature binds scale_handle to the shared const (whitespace-tolerant).
        @test occursin(r"scale_handle::Bool\s*=\s*SHOW_ROTATION_RINGS", src)
        # ...and there must be NO viewer hardcoding scale_handle to a literal true/false
        # (that would reintroduce the desync that caused the original regression).
        @test !occursin(r"scale_handle::Bool\s*=\s*(true|false)\b", src)
    end
end
