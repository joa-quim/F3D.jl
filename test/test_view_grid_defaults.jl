# Regression guard for the view_grid wrapper DEFAULTS (examples/gmt_solids.jl).
#
# The user-facing `view_grid` turns several extras on by default — notably the Fledermaus
# scale-handle gizmo (compass/tilt rings + vertical cone). That default once silently
# regressed (the gizmo rings vanished) and NO test caught it, because the whole gmt_solids.jl
# wrapper layer was untested — only the low-level `f3d_ext_enable_scale_handle` C binding had
# coverage (test_f3d_ext.jl), and that kept passing.
#
# This asserts the SINGLE SOURCE OF TRUTH (`VIEW_GRID_DEFAULTS`) that view_grid applies via a
# get! loop, plus the applied result, so dropping `scale_handle` breaks the test.
#
# gmt_solids.jl needs GMT; skip cleanly when GMT isn't installed so the core C-API suite still
# runs standalone.

@testset "view_grid wrapper defaults (gizmo rings regression)" begin
    if Base.find_package("GMT") === nothing
        @info "GMT not installed — skipping view_grid defaults regression test"
        @test_skip true
    else
        include(joinpath(@__DIR__, "..", "examples", "gmt_solids.jl"))

        d = VIEW_GRID_DEFAULTS
        # The gizmo MUST default ON — this is the exact regression that slipped through.
        @test d.scale_handle === true
        @test d.cube_axes === true
        @test d.up == "+Z"

        # Applied result: empty kwargs must inherit scale_handle=true through the same get!
        # loop view_grid uses, so the test tracks behaviour, not just the constant.
        vkw = Dict{Symbol,Any}()
        for (k, v) in pairs(d)
            get!(vkw, k, v)
        end
        @test vkw[:scale_handle] === true

        # A caller override must still win (defaults never clobber an explicit kwarg).
        vkw2 = Dict{Symbol,Any}(:scale_handle => false)
        for (k, v) in pairs(d)
            get!(vkw2, k, v)
        end
        @test vkw2[:scale_handle] === false
    end
end
