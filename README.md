# F3D

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://joa-quim.github.io/F3D.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://joa-quim.github.io/F3D.jl/dev)
[![Test workflow status](https://github.com/joa-quim/F3D.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/joa-quim/F3D.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/joa-quim/F3D.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/joa-quim/F3D.jl)
[![Docs workflow Status](https://github.com/joa-quim/F3D.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/joa-quim/F3D.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

Julia wrapper for the [f3d](https://f3d.app/docs/next/libf3d/OVERVIEW) library

Warning, this is a prototype package. It needs a few manual steps to make it usable:

- Clone this repository
- Install `f3d`
- Edit src/F3D.jl and set the `f3d` path in the `F3D_BIN_DIR` variable.
- replace `"f3d_c_api.dll"` in the `libf3d` variable by `"f3d_c_api.so"` or `"f3d_c_api.dylib"` if you
  are on MacOS or Linux respectively.
- Do, in the Julia REPL, `] dev /path/to/F3D.jl`

All this should be much improved when a formal `F3D.jl` package is created, but I need first find out
how to create a `F3D_jll` artifact that uses the readily available precompiled binaries.