module F3D

# Define library path - should eventually be managed by a JLL package
const F3D_BIN_DIR = "C:/programs/compa_libs/F3D/bin"
#const F3D_BIN_DIR = "C:/programs/compa_libs/f3d-superbuild/build/install/bin"

# Add bin directory to PATH so dependent DLLs can be found (Windows only)
if Sys.iswindows()
    ENV["PATH"] = F3D_BIN_DIR * ";" * get(ENV, "PATH", "")
end

const libf3d = joinpath(F3D_BIN_DIR, "f3d_c_api.dll")

include("libf3d.jl")

end
