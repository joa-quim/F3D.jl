# F3D

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://joa-quim.github.io/F3D.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://joa-quim.github.io/F3D.jl/dev)
[![Test workflow status](https://github.com/joa-quim/F3D.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/joa-quim/F3D.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/joa-quim/F3D.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/joa-quim/F3D.jl)
[![Docs workflow Status](https://github.com/joa-quim/F3D.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/joa-quim/F3D.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

Julia wrapper for the [f3d](https://f3d.app/docs/next/libf3d/OVERVIEW) library

Warning, this is a experimental package.

To install do:

```
] add https://github.com/joa-quim/F3D.jl
```

The tests run fine locally (all pass on Windows and two fail on Linux) but the CI runs crash???.

The `test/test_mesh.jl` example shows _how to display a cow_ (the `cow.vtp` lives in the tests directory too).
To run it do:

```
using F3D
include(joinpath(pkgdir(F3D), "test", "test_mesh.jl"))
test_mesh()
```
