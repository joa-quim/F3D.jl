include("../src/F3D.jl")
using .F3D: ensure_f3d

try
    lib_dir = ensure_f3d()
    @info "F3D build complete. Library directory: $lib_dir"
catch e
    @error "F3D build failed" exception = (e, catch_backtrace())
    rethrow()
end
