module F3D

# Define library path - should eventually be managed by a JLL package
const F3D_BIN_DIR = "C:/programs/compa_libs/F3D/bin"
#const F3D_BIN_DIR = "C:/programs/compa_libs/f3d-superbuild/build/install/bin"

# Add bin directory to PATH so dependent DLLs/Shared libs can be found
ENV["PATH"] = F3D_BIN_DIR * ";" * get(ENV, "PATH", "")

# This for windows. For other SOs, change the extension accordingly
const libf3d = joinpath(F3D_BIN_DIR, "f3d_c_api.dll")

include("libf3d.jl")

end
