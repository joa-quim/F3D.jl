# Use Clang.jl to wrap the F3d C API.

using Clang
using Clang.Generators
using MacroTools
using Logging

const output_dir = joinpath(@__DIR__, "..", "src")

# set up a global logger to log.txt to store the large amount of logging
loghandle = open(joinpath(@__DIR__, "log.txt"), "w")
logger = SimpleLogger(loghandle)
global_logger(logger)

# several functions for building docstrings
#include(joinpath(@__DIR__, "doc.jl"))

#includedir = joinpath("C:/programs/compa_libs/f3d-superbuild/build/install/include/f3d", "include")
#includedir = "C:/programs/compa_libs/f3d-superbuild/build/install/include/f3d"
includedir = "C:/programs/compa_libs/F3D/include/f3d"
headas = ["camera_c_api.h", "context_c_api.h", "engine_c_api.h", "image_c_api.h", "interactor_c_api.h", "log_c_api.h",
          "options_c_api.h", "scene_c_api.h", "types_c_api.h", "utils_c_api.h", "window_c_api.h"]
headerfiles = joinpath.(includedir, headas)

for headerfile in headerfiles
    if !isfile(headerfile)
        error("Header file missing `($headerfile)")
    end
end

"""
Custom rewriter for Clang.jl's C wrapper

Gets called with all expressions in a header file, or all expressions in a common file.
If available, it adds docstrings before every expression, such that Clang.jl prints them
on top of the expression. The expressions themselves get sent to `rewriter(::Expr)`` for
further treatment.
"""
function rewriter(xs::Vector)
    rewritten = Any[]
    for x in xs
        # Clang.jl inserts strings like "# Skipping MacroDefinition: X"
        # keep these to get a sense of what we are missing
        if x isa String
            push!(rewritten, x)
            continue
        end
        @assert x isa Expr

        name = cname(x)
        node = findnode(name, doc)
        docstr = node === nothing ? "" : build_docstring(node)
        isempty(docstr) || push!(rewritten, addquotes(docstr))
        x2 = rewriter(x)
        push!(rewritten, x2)
    end
    rewritten
end

"Rewrite expressions in the ways listed at the top of this file."
function rewriter(x::Expr)
    if @capture(x, function f_(fargs__) ccall(fname_, rettype_, argtypes_, argvalues__) end)
        # it is a function wrapper around a ccall

        # lowercase the function name
        #f2 = Symbol(lowercase(String(f)))
        f2 = Symbol(String(f))

        # replace Ptr{Cvoid} with Any for callbacks, so Functions are converted by Julia
        # https://julialang.org/blog/2013/05/callback/#passing_closures_via_pass-through_pointers
        # The callback always follows the GDALProgressFunc type
        i = findfirst(==(:GDALProgressFunc), argtypes.args)
        if !isnothing(i) && argtypes.args[i+1] == :(Ptr{Cvoid})
            argtypes.args[i+1] = :Any
        end

        # bind the ccall such that we can easily wrap it
        cc = :(ccall($fname, $rettype, $argtypes, $(argvalues...)))

        # stitch the modified function expression back together
        :(function $f2($(fargs...))
            $cc
        end) |> prettify
    else
        # do not modify expressions that are no ccall function wrappers
        x
    end
end

# custom function that prevents overwriting GDAL.jl by mapping gdal.h to gdal_h.jl
function header_outputfile(h)
    stem = splitext(basename(h))[1]
    if stem == "leptonica"
        joinpath(output_dir, "leptonica_h.jl")
    else
        joinpath(output_dir, stem * ".jl")
    end
end


function rewriter(dag::Clang.ExprDAG)
    for node in get_nodes(dag)
        # Macros are not generated, so no need to skip
        map!(rewriter, node.exprs, node.exprs)
    end
end


# do not wrap, handled in prologue.jl
@add_def stat
@add_def _stat64
@add_def time_t

options = load_options(joinpath(@__DIR__, "generator.toml"))

# add compiler flags, e.g. "-DXXXXXXXXX"
args = get_default_args()
push!(args, "-I$includedir")

# create context
ctx = create_context(headerfiles, args, options)

# run generator
build!(ctx, BUILDSTAGE_NO_PRINTING)
rewriter(ctx.dag)
build!(ctx, BUILDSTAGE_PRINTING_ONLY)

#add_doc(joinpath(@__DIR__, "..", "src", "libf3d.jl"))

#format(joinpath(@__DIR__, ".."))

close(loghandle)
