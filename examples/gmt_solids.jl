# Example: build a solid with GMT.jl's Faces-Vertices (GMTfv) generators
# (icosahedron, cube, sphere, torus, cylinder, ...) and hand the mesh to F3D
# through memory (no file on disk), then open the interactive viewer.
#
# Run with:
#   julia examples/gmt_solids.jl                 # default solid (coloured)
#   julia examples/gmt_solids.jl torus           # pick one by name
#
# Close the F3D window to end the script.
#
# COLOUR — the GMTfv carries per-face colours as GMT `-G` strings in `fv.color`
# (e.g. "-G#aabbcc", "-G180", "-Gred", "-G100/150/200"). The F3D C API mesh
# struct only has points / normals / texcoords / sides / indices — no per-cell
# colour array — so we render face colours through a texture: build a 1-pixel
# tall colourmap (one texel per distinct colour), give every face's vertices a
# u-coordinate pointing at its texel, and set that image as `model.color.texture`.
# Per-face colour needs unshared vertices, so faces are split (each face gets its
# own copy of its corner vertices).
#
# ILLUMINATION — smooth per-vertex normals are computed (Newell's method) and
# passed to F3D, and lights are configurable via the `lights` keyword of
# view_fv / main (SCENE / camera / headlight; direction, colour, intensity).

using F3D
using GMT
using Libdl     # dlopen/dlsym — probe for optional f3d_ext symbols (rubber-band pick)

# ---------------------------------------------------------------------------
# GMT "-G" colour string -> (r,g,b) UInt8
# ---------------------------------------------------------------------------
const _NAMED = Dict(
	"red"=>(0xff,0x00,0x00), "green"=>(0x00,0x80,0x00), "blue"=>(0x00,0x00,0xff),
	"white"=>(0xff,0xff,0xff), "black"=>(0x00,0x00,0x00), "yellow"=>(0xff,0xff,0x00),
	"cyan"=>(0x00,0xff,0xff), "magenta"=>(0xff,0x00,0xff), "orange"=>(0xff,0xa5,0x00),
	"gray"=>(0x80,0x80,0x80), "grey"=>(0x80,0x80,0x80),
	"darkgreen"=>(0x00,0x64,0x00), "lightgreen"=>(0x90,0xee,0x90),
)

function parse_gmt_color(s::AbstractString)::NTuple{3,UInt8}
	c = strip(s)
	startswith(c, "-G") && (c = c[3:end])
	isempty(c) && return (0x80, 0x80, 0x80)
	if startswith(c, "#")                       # #rrggbb
		h = c[2:end]
		return (parse(UInt8, h[1:2], base=16), parse(UInt8, h[3:4], base=16), parse(UInt8, h[5:6], base=16))
	elseif occursin('/', c)                     # r/g/b
		p = split(c, '/')
		return (UInt8(clamp(parse(Int, p[1]),0,255)), UInt8(clamp(parse(Int, p[2]),0,255)), UInt8(clamp(parse(Int, p[3]),0,255)))
	elseif all(isdigit, c)                       # single number => gray
		g = UInt8(clamp(parse(Int, c), 0, 255));  return (g, g, g)
	else                                         # named
		return get(_NAMED, lowercase(c), (0x80, 0x80, 0x80))
	end
end

# ---------------------------------------------------------------------------
# Per-face colour access straight off the GMTfv (no flattened face-list copy).
# `fv.faces` is a Vector of Mx(verts-per-face) Int matrices; `fv.color` holds an
# aligned Vector of "-G" strings per group. We iterate those matrices directly
# with row indices, so no per-face Vector{Int} is ever allocated.
# ---------------------------------------------------------------------------
have_color(fv::GMT.GMTfv) = !isempty(fv.color) && any(!isempty, fv.color)

# Total (faces, corners) across all groups — for exact array preallocation.
function count_faces_corners(fv::GMT.GMTfv)
	nfaces = ncorners = 0
	for Fm in fv.faces
		isempty(Fm) && continue
		nf, npf = size(Fm)
		nfaces   += nf
		ncorners += nf * npf
	end
	return nfaces, ncorners
end

@inline function face_color(fv::GMT.GMTfv, g::Int, r::Int)
	(g <= length(fv.color) && r <= length(fv.color[g])) ? fv.color[g][r] : ""
end

"""
	compute_vertex_normals(V, faces) -> Matrix{Float32}  (nv x 3)

Smooth per-vertex normals: each face's normal (Newell's method, robust for
non-planar polygons) accumulated onto its vertices, then normalised. Iterates
the FV face matrices (`fv.faces`) directly — no per-face allocation. Float32 is
ample for shading normals and halves the buffer vs Float64.
"""
function compute_vertex_normals(V::AbstractMatrix, faces)
	nv = size(V, 1)
	N  = zeros(Float32, nv, 3)
	for Fm in faces
		isempty(Fm) && continue
		nf, npf = size(Fm)
		for r in 1:nf
			nx = ny = nz = 0.0f0
			for a in 1:npf                       # Newell: sum over the face's edges
				i = Fm[r, a]
				j = Fm[r, a == npf ? 1 : a + 1]
				nx += Float32(V[i,2] - V[j,2]) * Float32(V[i,3] + V[j,3])
				ny += Float32(V[i,3] - V[j,3]) * Float32(V[i,1] + V[j,1])
				nz += Float32(V[i,1] - V[j,1]) * Float32(V[i,2] + V[j,2])
			end
			for a in 1:npf
				vi = Fm[r, a]
				N[vi,1] += nx;  N[vi,2] += ny;  N[vi,3] += nz
			end
		end
	end
	@inbounds for i in 1:nv
		n = sqrt(N[i,1]^2 + N[i,2]^2 + N[i,3]^2)
		n < 1f-12 && (n = 1f0)
		N[i,1] /= n;  N[i,2] /= n;  N[i,3] /= n
	end
	return N
end

# Single normalised face normal (Newell) for one face row — used for flat shading.
@inline function newell_normal(V::AbstractMatrix, Fm, r::Int, npf::Int)
	nx = ny = nz = 0.0f0
	for a in 1:npf
		i = Fm[r, a]
		j = Fm[r, a == npf ? 1 : a + 1]
		nx += Float32(V[i,2] - V[j,2]) * Float32(V[i,3] + V[j,3])
		ny += Float32(V[i,3] - V[j,3]) * Float32(V[i,1] + V[j,1])
		nz += Float32(V[i,1] - V[j,1]) * Float32(V[i,2] + V[j,2])
	end
	n = sqrt(nx^2 + ny^2 + nz^2);  n < 1f-12 && (n = 1f0)
	return (nx / n, ny / n, nz / n)
end

"""
	fv_to_mesh(fv; flat=false) -> NamedTuple

Convert a `GMTfv` to the flat arrays an `f3d_mesh_t` expects, with `normals` for
illumination. `flat=false` (default) gives smooth shading: one averaged normal
per shared vertex. `flat=true` gives flat shading: each face's own Newell normal
applied to all its corners (faceted look) — this needs split vertices, so a flat
mesh is always vertex-split. When the FV has per-face colours, vertices are also
split and `texcoords` index into `palette` (RGB triplets, `ncolors` texels).
Vertices stay shared only for the smooth + uncoloured case. Reads in place.
"""
function fv_to_mesh(fv::GMT.GMTfv; flat::Bool=false, drape::Bool=false)
	V  = fv.verts
	coloured = !drape && have_color(fv)         # drape overrides per-face colour

	# Drape UV: stretch the image over the FULL x,y extent of the surface (image
	# coordinates ignored). u = (x-xmin)/dx; v = (y-ymin)/dy. No V flip: the grid
	# origin is lower-left and gmtwrite's PNG / VTK texture sampling already put
	# the image's top row at max-y (north), so flipping would turn it upside down.
	# Per-vertex, so it folds into both the shared- and split-vertex paths below.
	local drape_uv
	if drape
		xmn, xmx = extrema(@view V[:, 1]);  dx = xmx - xmn;  dx <= 0 && (dx = 1.0)
		ymn, ymx = extrema(@view V[:, 2]);  dy = ymx - ymn;  dy <= 0 && (dy = 1.0)
		drape_uv = vi -> (Float32((V[vi,1]-xmn)/dx), Float32((V[vi,2]-ymn)/dy))
	end

	if !flat && !coloured                       # smooth + plain: shared vertices
		VN = compute_vertex_normals(V, fv.faces)
		nv = size(V, 1)
		points  = Vector{Float32}(undef, 3nv)
		normals = Vector{Float32}(undef, 3nv)
		@inbounds for i in 1:nv
			points[3i-2],  points[3i-1],  points[3i]  = V[i,1],  V[i,2],  V[i,3]
			normals[3i-2], normals[3i-1], normals[3i] = VN[i,1], VN[i,2], VN[i,3]
		end
		nfaces, ncorners = count_faces_corners(fv)
		sides   = UInt32[];  sizehint!(sides, nfaces)
		indices = UInt32[];  sizehint!(indices, ncorners)
		for Fm in fv.faces
			isempty(Fm) && continue
			nf, npf = size(Fm)
			for r in 1:nf
				push!(sides, UInt32(npf))
				for a in 1:npf
					push!(indices, UInt32(Fm[r,a] - 1))
				end
			end
		end
		tc = Float32[]
		if drape
			tc = Vector{Float32}(undef, 2nv)
			@inbounds for i in 1:nv
				u, v = drape_uv(i);  tc[2i-1] = u;  tc[2i] = v
			end
		end
		return (; points, normals, texcoords = tc, sides, indices, palette = UInt8[], ncolors = 0)
	end

	# Split-vertex path: required for flat shading and/or per-face colour.
	# Smooth normals (if not flat) come from the shared-vertex normals.
	VN = flat ? nothing : compute_vertex_normals(V, fv.faces)
	nfaces, ncorners = count_faces_corners(fv)

	# Colour bookkeeping: distinct-colour palette + one colour index per face.
	ncol    = 0
	cidx    = UInt32[]
	palette = UInt8[]
	if coloured
		idxof = Dict{NTuple{3,UInt8},Int}()
		uniq  = NTuple{3,UInt8}[]
		cidx  = Vector{UInt32}(undef, nfaces)
		fc = 0
		for (g, Fm) in enumerate(fv.faces)
			isempty(Fm) && continue
			for r in 1:size(Fm, 1)
				c = parse_gmt_color(face_color(fv, g, r))
				k = get!(idxof, c) do
					push!(uniq, c); length(uniq)
				end
				cidx[fc += 1] = k
			end
		end
		ncol = length(uniq)
		sizehint!(palette, 3ncol)
		for c in uniq
			push!(palette, c[1], c[2], c[3])
		end
	end

	points    = Float32[];  sizehint!(points,  3ncorners)
	normals   = Float32[];  sizehint!(normals, 3ncorners)
	texcoords = Float32[];  (coloured || drape) && sizehint!(texcoords, 2ncorners)
	sides     = UInt32[];   sizehint!(sides,   nfaces)
	indices   = UInt32[];   sizehint!(indices, ncorners)
	vid = 0
	fi  = 0
	for Fm in fv.faces
		isempty(Fm) && continue
		nf, npf = size(Fm)
		for r in 1:nf
			fi += 1
			fn = flat ? newell_normal(V, Fm, r, npf) : (0f0, 0f0, 0f0)
			u  = coloured ? (cidx[fi] - 0.5f0) / ncol : 0f0   # texel centre
			push!(sides, UInt32(npf))
			for a in 1:npf
				vi = Fm[r, a]
				push!(points, V[vi,1], V[vi,2], V[vi,3])
				if flat
					push!(normals, fn[1], fn[2], fn[3])
				else
					push!(normals, VN[vi,1], VN[vi,2], VN[vi,3])
				end
				if coloured
					push!(texcoords, u, 0.5f0)
				elseif drape
					uu, vv = drape_uv(vi);  push!(texcoords, uu, vv)
				end
				push!(indices, UInt32(vid));  vid += 1
			end
		end
	end

	return (; points, normals, texcoords, sides, indices, palette, ncolors = ncol)
end

# Collapse a path the way libf3d wants. The shipped DLL auto-collapses any path
# given to a `*.texture` option and logs "Collapsing path inside the libf3d is now
# deprecated, use utils::collapsePath manually." Pre-collapsing here (normalised,
# forward slashes) makes the DLL skip its own collapse -> no warning. Textures are
# path-only in this API (F3D_API_gaps #1), so every texture we set goes through here.
function collapse_path(p::AbstractString)
	cp = F3D.f3d_utils_collapse_path(String(p), "")
	return cp == C_NULL ? String(p) : unsafe_string(cp)
end

# ---------------------------------------------------------------------------
# Write the palette as a 1 x ncolors RGB PNG via F3D's own image API and return
# the (collapsed) temp file path (so we need no extra image dependency).
# ---------------------------------------------------------------------------
function write_palette_png(palette::Vector{UInt8}, ncolors::Int)
	img = F3D.f3d_image_new_params(Cuint(ncolors), Cuint(1), Cuint(3), F3D.BYTE)
	img == C_NULL && error("failed to create palette image")
	path = joinpath(tempdir(), "f3d_palette_$(getpid()).png")
	GC.@preserve palette begin
		F3D.f3d_image_set_content(img, pointer(palette))
		F3D.f3d_image_save(img, path, F3D.PNG)
	end
	F3D.f3d_image_delete(img)
	return collapse_path(path)
end

# ---------------------------------------------------------------------------
# Georeferenced drape, NO gdal: place `I` onto the [x0,x1]×[y0,y1] bbox at its TRUE
# geographic position, with an ALPHA band that is 0 outside the image footprint, by
# index copy at the image's own increment (same transpose/orientation as `drape_pad`).
# Sampling this canvas with the bbox UV paints only the grid ∩ image overlap; the rest
# stays transparent. Used by the drape_clip path (outside=:transparent / view_fv clip).
# ---------------------------------------------------------------------------
function drape_to_bbox(I::GMT.GMTimage, x0, x1, y0, y1)
	ox0, ox1 = max(x0, I.range[1]), min(x1, I.range[2])
	oy0, oy1 = max(y0, I.range[3]), min(y1, I.range[4])
	Ic = GMT.crop(I, region=(ox0, ox1, oy0, oy1))[1]
	dx, dy = abs(Ic.inc[1]), abs(Ic.inc[2])
	nx = clamp(round(Int, (x1 - x0) / dx), 16, 8192)
	ny = clamp(round(Int, (y1 - y0) / dy), 16, 8192)
	S = Ic.image;  inx, iny = size(S, 1), size(S, 2)
	xoff = round(Int, (Ic.range[1] - x0) / dx)
	yoff = round(Int, (y1 - Ic.range[4]) / dy)
	rgba = zeros(UInt8, ny, nx, 4)                        # RGB 0 + alpha 0 (transparent) outside
	@inbounds for jy in 1:iny, ix in 1:inx
		r = yoff + jy;  c = xoff + ix                     # rows = lat (north->down), cols = lon
		(1 <= r <= ny && 1 <= c <= nx) || continue
		rgba[r, c, 1] = S[ix, jy, 1];  rgba[r, c, 2] = S[ix, jy, 2]
		rgba[r, c, 3] = S[ix, jy, 3];  rgba[r, c, 4] = 0xff
	end
	return GMT.mat2img(rgba; x=[x0, x1], y=[y0, y1])
end

# Pad an image onto a larger bbox WITHOUT gdal/resample: copy the image block into a
# canvas covering [x0,x1]×[y0,y1] at the image's OWN increment, leaving `fill` everywhere
# the image is absent. Returns two GMTimages over the bbox — `col` (image + `fill` outside)
# and `emis` (image + BLACK outside) — for the colour and emissive textures of `:shade`.
# Pure index translation in the image's native layout, so no resampling and no flip.
# Expand a user color into a 3-band UInt8 RGB tuple. Accepts:
#   grey 0-255 Int/Real            -> (g,g,g)
#   (r,g,b) tuple/vector 0-255     -> as-is
#   (r,g,b) floats in 0-1          -> scaled to 0-255
_rgb3(c::Real) = (u = UInt8(clamp(round(Int, c), 0, 255)); (u, u, u))
function _rgb3(c)
	length(c) == 3 || error("color must be a grey value or an (r,g,b); got $(c)")
	# floats all in [0,1] are interpreted as fractions -> scale to 0-255; otherwise 0-255.
	scl = all(v -> isa(v, AbstractFloat) && 0 <= v <= 1, c) ? 255 : 1
	ntuple(i -> UInt8(clamp(round(Int, c[i] * scl), 0, 255)), 3)
end

function drape_pad(I::GMT.GMTimage, x0, x1, y0, y1; fill=170)
	# Crop to the part of the image inside the canvas FIRST: `GMT.crop` returns a clean
	# band-planar, top-origin "TRBa" image (the native layout reconstructs reliably; the
	# raw image may be pixel-interleaved "BRPa", which a fresh planar array can't mimic).
	ox0, ox1 = max(x0, I.range[1]), min(x1, I.range[2])
	oy0, oy1 = max(y0, I.range[3]), min(y1, I.range[4])
	Ic = GMT.crop(I, region=(ox0, ox1, oy0, oy1))[1]
	dx, dy = abs(Ic.inc[1]), abs(Ic.inc[2])
	nx = clamp(round(Int, (x1 - x0) / dx), 16, 8192)
	ny = clamp(round(Int, (y1 - y0) / dy), 16, 8192)
	S = Ic.image
	inx, iny = size(S, 1), size(S, 2)                     # Ic.image: dim1 = lon, dim2 = lat (TRBa, jy=1 north)
	xoff = round(Int, (Ic.range[1] - x0) / dx)            # cols from canvas west to image west
	yoff = round(Int, (y1 - Ic.range[4]) / dy)            # rows from canvas north down to image top
	rgb  = _rgb3(fill)
	# canvas is standard raster order (rows = lat from NORTH, cols = lon from WEST) so
	# mat2img's default reads it upright; the source is indexed [lon, lat] so the copy
	# transposes it into [lat, lon] (this is the 90° fix).
	col  = Array{UInt8}(undef, ny, nx, 3)
	for b in 1:3; fill!(view(col, :, :, b), rgb[b]); end
	emis = zeros(UInt8, ny, nx, 3)
	@inbounds for b in 1:3, jy in 1:iny, ix in 1:inx
		r = yoff + jy;  c = xoff + ix                     # row = lat (north->down), col = lon (west->east)
		(1 <= r <= ny && 1 <= c <= nx) || continue
		v = S[ix, jy, b];  col[r, c, b] = v;  emis[r, c, b] = v
	end
	return GMT.mat2img(col;  x=[x0, x1], y=[y0, y1]),
		   GMT.mat2img(emis; x=[x0, x1], y=[y0, y1])
end

# ---------------------------------------------------------------------------
# Light control. Each light is a NamedTuple; sensible defaults fill the rest:
#   (; type=:scene, direction=(-1,-1,-1), intensity=1.2, color=(1,1,1))
# type    : :head (at camera, follows view) | :camera | :scene (fixed in world)
# direction: for a directional scene light (ignored when positional)
# position : world point when `positional=true`
# A SCENE light with a direction is the usual "sun from over there" source.
# Pass `lights=[...]` to view_fv; with none, F3D's default headlight is used.
# ---------------------------------------------------------------------------
const _LIGHT_TYPES = Dict(
	:head   => F3D.F3D_LIGHT_TYPE_HEADLIGHT,
	:camera => F3D.F3D_LIGHT_TYPE_CAMERA_LIGHT,
	:scene  => F3D.F3D_LIGHT_TYPE_SCENE_LIGHT,
)

function add_lights!(scene, lights)
	for L in lights
		typ = _LIGHT_TYPES[get(L, :type, :scene)]
		pos = get(L, :position,  (0.0, 0.0, 0.0))
		col = get(L, :color,     (1.0, 1.0, 1.0))
		dir = get(L, :direction, (0.0, 0.0, -1.0))
		st = Ref(F3D.f3d_light_state_t(
			typ,
			(Cdouble(pos[1]), Cdouble(pos[2]), Cdouble(pos[3])),
			F3D.f3d_color_t((Cdouble(col[1]), Cdouble(col[2]), Cdouble(col[3]))),
			(Cdouble(dir[1]), Cdouble(dir[2]), Cdouble(dir[3])),
			Cint(get(L, :positional, false) ? 1 : 0),
			Cdouble(get(L, :intensity, 1.0)),
			Cint(get(L, :on, true) ? 1 : 0),
		))
		GC.@preserve st F3D.f3d_scene_add_light(scene, st)
	end
end

# Image save format from a file name's extension (default PNG when none). F3D
# supports PNG / JPG / TIF / BMP. Returns (path_with_ext, format_enum).
function _img_target(fname::AbstractString)
	ext = lowercase(splitext(fname)[2])
	isempty(ext)            && return string(fname, ".png"), F3D.PNG
	(ext in (".png",))      && return String(fname), F3D.PNG
	(ext in (".jpg",".jpeg")) && return String(fname), F3D.JPG
	(ext in (".tif",".tiff")) && return String(fname), F3D.TIF
	(ext == ".bmp")         && return String(fname), F3D.BMP
	error("unsupported image format \"$ext\"; use png, jpg, tif or bmp")
end

# Handle returned by `async=true` viewers. Holds the worker Task and the interactor
# pointer so the window can be closed from the REPL with `close!(h)`.
mutable struct ViewHandle
	task::Task
	interactor::Ptr{Cvoid}
	open::Bool
	sel::Ref{Any}            # latest rubber-band selection (set by view_points when pick=true)
end
ViewHandle(t, i, o) = ViewHandle(t, i, o, Ref{Any}(nothing))

"""
	selection(h::ViewHandle)

Return the rubber-band-selected points of a `view_points` window as a `GMTdataset`,
or `nothing` if nothing is selected. The raw rows are stored from the viewer's worker
thread; the `GMTdataset` is built HERE (on the calling/main thread) because GMT is not
thread-safe — never call GMT from the async worker.
"""
function selection(h::ViewHandle)
	m = h.sel[]
	return m === nothing ? nothing : GMT.mat2ds(m)
end

"""Close an async viewer window from the REPL: `close!(h)`. Cross-thread request_stop
makes the worker's native event loop exit, then it deletes the engine."""
function close!(h::ViewHandle)
	# If the worker task is already done the user closed the window (X button) and the
	# engine/interactor are ALREADY freed — calling request_stop on that dangling pointer
	# is a use-after-free that crashes the whole process. Only stop a still-running window.
	if istaskdone(h.task) || !h.open || h.interactor == C_NULL
		h.open = false
		return h
	end
	F3D.f3d_interactor_request_stop(h.interactor)
	h.open = false
	return h
end
Base.isopen(h::ViewHandle) = h.open && !istaskdone(h.task)
function Base.show(io::IO, h::ViewHandle)
	st = istaskfailed(h.task) ? "failed" : istaskdone(h.task) ? "closed" : "open"
	print(io, "ViewHandle($st)")
end

# Blocking interactor loop, run GC-SAFE. `f3d_interactor_start` is a long ccall that never
# reaches a Julia safepoint; on a worker thread it would block GC's stop-the-world (any
# allocation in the REPL → whole process hangs). `jl_gc_safe_enter` marks this thread
# collectable for the duration (it only touches VTK, no Julia heap). The @cfunction picks
# callbacks (onpick) auto re-enter gc-unsafe on entry, so they stay safe.
function _interactor_start_gcsafe(interactor, dt)
	gc_state = ccall(:jl_gc_safe_enter, Int8, ())
	try
		F3D.f3d_interactor_start(interactor, dt)
	finally
		ccall(:jl_gc_safe_leave, Cvoid, (Int8,), gc_state)
	end
end

# Run the blocking viewer `impl(ch)` on a worker thread; VTK's GL context AND the platform
# message pump must live on ONE thread, so the WHOLE engine/window/interactor lifecycle
# runs there. `impl` publishes its interactor pointer into `ch` once initialised, letting
# the REPL get a ViewHandle (→ `close!`) while the window stays interactive.
function _async_view(impl; sel::Ref{Any}=Ref{Any}(nothing))
	ch = Channel{Ptr{Cvoid}}(1)
	h = ViewHandle(@task(nothing), C_NULL, true, sel)   # placeholder task; filled below
	h.task = Threads.@spawn try
		impl(ch)
	catch e
		@error "async view failed" exception=(e, catch_backtrace())
		rethrow()
	finally
		close(ch)                       # unblock take! if impl returned/errored before publishing
		# Window is gone and the engine/interactor freed by impl. Drop the now-dangling
		# pointer + mark closed so NOTHING in the REPL can touch freed memory later (the
		# delayed-crash-after-close). Must run on every exit path (close!, X button, error).
		h.interactor = C_NULL
		h.open = false
	end
	try
		h.interactor = take!(ch)        # the live interactor, published once impl inits it
	catch                               # channel closed before publish (offscreen, or error)
		istaskfailed(h.task) && fetch(h.task)   # surface the real error
	end
	return h
end

"""
	view_fv(fv; kwargs...)

Open an interactive F3D viewer showing a `GMTfv` (faces-vertices solid), using its
per-face colours when present. Blocks until the window is closed, unless `async`
(then it returns a `ViewHandle` at once) or `offscreen`.

# Window & threading
- `title="F3D — GMT solid"`: window title bar text.
- `size=(1600,1200)`: window size in pixels `(w, h)`.
- `bg=(0.1,0.1,0.15)`: background colour, RGB in `0-1`.
- `async=true`: run the viewer on a worker thread and hand the REPL back a
  `ViewHandle` immediately (window stays interactive; `close!(h)` to shut it).
  `async=false` blocks until the window closes. Forced off when `offscreen`.

# Lighting & material (`nothing`/`NaN` keeps f3d's defaults)
- `lights=()`: vector of light NamedTuples (see `add_lights!`); empty = f3d's
  default headlight.
- `metallic=NaN`: PBR metalness, scalar `0-1`.
- `roughness=NaN`: PBR roughness, scalar `0-1`.
- `emissive=nothing`: self-illumination factor — scalar grey or `(r,g,b)` (`0-1`).

# Shading & decoration
- `flat=false`: flat (faceted) shading instead of smooth normals.
- `edges=false`: draw the mesh wireframe edges.
- `linewidth=1.0`: edge line width in pixels (with `edges=true`).
- `trihedron=false`: add an XYZ trihedron to the mesh (incompatible with `drape`).
- `axes=true`: show the corner orientation gizmo (forced off under `topdown`).
- `grid=true`: show f3d's floor grid at the bbox bottom = cube-axes floor (forced
  off under `topdown`).

# Camera
- `azimuth=-40.0`, `elevation=25.0`: initial orbit / tilt of the camera (degrees).
- `topdown=false`: orthographic straight-down, north-up view (georeferenceable).
- `up="+Z"`: scene up-direction (`"+Z"` lays z-up data flat with X,Y on the floor).

# Image draping (`drape::GMTimage` overrides per-face colours)
- `drape=GMTimage()`: image to drape over the surface as a texture.
- `drape_clip=false`: `false` stretches the image to the full x,y extent, ignoring
  its georeferencing; `true` honours the image's geographic coords — warps it onto
  the surface bbox so only the grid ∩ image overlap is painted, rest transparent.
  Use for a referenced GeoTIFF over a DEM sharing a coordinate system.
- `drape_light=1.0`: emissive factor for the drape (`1.0` = full image colour,
  lower keeps more relief shading).
- `drape_emis=GMTimage()`: separate emissive image; when given it is the glow layer
  while `drape` stays the lit colour (relief shading + glowing overlay).
- `drape_unlit=false`: kill diffuse lighting so the surface shows ONLY the image at
  full colour (no relief shading).

# Export
- `mapexport=""`: one-shot georeferenceable map — forces orthographic top-down +
  offscreen and saves to this file (format from extension, default PNG; `.tiff`
  writes a GeoTIFF when `georef` is set).
- `savepng=""`: save the current frame to a file (format from extension) without
  forcing top-down.
- `offscreen=false`: render without opening a window (no interaction; extras off).
- `georef=nothing`: `(x0,x1,y0,y1,proj)` tuple stamped onto a `.tiff` export to make
  it a GeoTIFF; usually filled in for you by `view_grid`.

# Colour bar & extended interactions (need an f3d built with `c/f3d_ext_*.cxx`)
- `colorbar=nothing`: NamedTuple `(rgb, n, vmin, vmax[, title, fmt])` drawing a
  colour scale on the right edge; `nothing` = none.
- `cube_axes=true`: labelled bounding-box (X/Y/Z tick) axes with coords.
- `coord_readout=true`: live world X/Y/Z under the cursor (bottom-left).
- `vscale_drag=true`: Ctrl+left-drag to exaggerate / flatten the relief.
- `vscale_step=0.01`: vertical-scale change per dragged pixel (with `vscale_drag`).
- `scale_handle=false`: show a Fledermaus-style gizmo at the rotation centre — drag the
  vertical arrowhead to exaggerate the relief (the cone stretches to show the factor),
  the horizontal arrows to tilt, the compass ring to spin azimuth (Ctrl+left-drag also
  still scales). Supersedes `vscale_drag` when on.
"""
view_fv(fv::GMT.GMTfv; async::Bool=true, kwargs...) =
	(async && !get(kwargs, :offscreen, false)) ?   # offscreen has no window -> nothing to hand back
		_async_view(ch -> _view_fv_impl(fv; _handle_chan=ch, kwargs...)) : _view_fv_impl(fv; kwargs...)

function _view_fv_impl(fv::GMT.GMTfv; _handle_chan=nothing, title::AbstractString="F3D — GMT solid",
				 size::Tuple{Int,Int}=(1600, 1200), bg=(0.1, 0.1, 0.15),
				 lights=(), flat::Bool=false, axes::Bool=true,
				 grid::Bool=true, trihedron::Bool=false, edges::Bool=false,
				 offscreen::Bool=false, savepng::AbstractString="", mapexport::AbstractString="",
				 azimuth::Real=-40.0, elevation::Real=25.0, topdown::Bool=false,
				 up="+Z", cube_axes::Bool=true, coord_readout::Bool=true,
				 vscale_drag::Bool=true, vscale_step::Real=0.01, scale_handle::Bool=false,
				 drape::GMT.GMTimage=GMT.GMTimage(), drape_clip::Bool=false,
				 drape_emis::GMT.GMTimage=GMT.GMTimage(),
				 drape_light::Real=1.0, drape_unlit::Bool=false, linewidth::Real=1.0,
				 metallic=NaN, roughness=NaN, emissive=nothing, georef=nothing, colorbar=nothing,
				 lines=nothing, line_color=nothing, line_width::Real=2.0, line_zfac::Real=1.0, L=nothing)
	lines = L === nothing ? lines : L          # `L` = GMT-style short alias for `lines`
	savefmt = F3D.PNG
	if (!isempty(mapexport))
		topdown = true;  offscreen = true
		savepng, savefmt = _img_target(mapexport)
	elseif !isempty(savepng)
		savepng, savefmt = _img_target(savepng)
	end

	do_drape = !isempty(drape)
	fvm = trihedron ? add_trihedron!(deepcopy(fv)) : fv   # copy: don't mutate caller's fv
	m = fv_to_mesh(fvm; flat = flat, drape = do_drape)

	F3D.f3d_engine_autoload_plugins()
	engine = F3D.f3d_engine_create(Cint(offscreen ? 1 : 0))
	engine == C_NULL && error("failed to create F3D engine")

	scene  = F3D.f3d_engine_get_scene(engine)
	window = F3D.f3d_engine_get_window(engine)
	win = size
	if topdown                                   # match window aspect to xy data bounds
		xmn = xmx = m.points[1];  ymn = ymx = m.points[2]
		@inbounds for i in 1:(length(m.points) ÷ 3)
			x = m.points[3i-2];  y = m.points[3i-1]
			x < xmn && (xmn = x);  x > xmx && (xmx = x)
			y < ymn && (ymn = y);  y > ymx && (ymx = y)
		end
		ar   = (xmx - xmn) / max(ymx - ymn, eps(Float32))         # Δx/Δy
		long = max(size[1], size[2])
		win  = ar >= 1 ? (long, max(round(Int, long / ar), 1)) : (max(round(Int, long * ar), 1), long)
	end
	F3D.f3d_window_set_size(window, Cint(win[1]), Cint(win[2]))
	F3D.f3d_window_set_window_name(window, title)

	opts = F3D.f3d_engine_get_options(engine)
	# `up`: scene up-direction ("+Z", "+Y", ...). Grids are z=f(x,y) so +Z lays them
	# flat (X,Y on the floor, Z vertical); use set_as_string_representation — plain
	# set_as_string CRASHES on the `direction` option type.
	up === nothing || F3D.f3d_options_set_as_string_representation(opts, "scene.up_direction", string(up))
	F3D.f3d_options_set_as_bool(opts, "render.show_edges", Cint(edges ? 1 : 0))
	edges && F3D.f3d_options_set_as_double(opts, "render.line_width", Cdouble(linewidth))
	F3D.f3d_options_set_as_bool(opts, "ui.scalar_bar", Cint(0))
	(axes && !topdown) && F3D.f3d_options_set_as_bool(opts, "ui.axis", Cint(1))  # gizmo; off for map export
	if (grid && !topdown)								# grid at the model's bbox bottom
		F3D.f3d_options_set_as_bool(opts, "render.grid.enable", Cint(1))   # (z=zmin) = the cube
		F3D.f3d_options_set_as_bool(opts, "render.grid.absolute", Cint(0)) # axes floor, NOT z=0
	end

	# NOTE: render.axes_grid (labeled coord ticks) is an UNREGISTERED key in this
	# DLL (3.5.0-103, predates the option). f3d_options_set_as_* SEGFAULTS on any
	# unknown key (not just this one) — never set keys this DLL doesn't know.
	# Origin grid + gizmo give orientation and object-vs-origin offset instead.
	bgc = Cdouble[bg[1], bg[2], bg[3]]
	F3D.f3d_options_set_as_double_vector(opts, "render.background.color", bgc, Csize_t(3))
	# PBR material / self-illumination (only set when given, else f3d defaults stand).
	# metallic, roughness: scalars 0-1. emissive: scalar grey or (r,g,b) factor (0-1).
	isnan(metallic) || F3D.f3d_options_set_as_double(opts, "model.material.metallic",  Cdouble(metallic))
	isnan(roughness) || F3D.f3d_options_set_as_double(opts, "model.material.roughness", Cdouble(roughness))
	if emissive !== nothing
		ef = emissive isa Real ? Cdouble[emissive, emissive, emissive] :
								 Cdouble[emissive[1], emissive[2], emissive[3]]
		F3D.f3d_options_set_as_double_vector(opts, "model.emissive.factor", ef, Csize_t(3))
	end

	# Temp textures to delete when the window CLOSES — NOT after the first render. f3d
	# re-reads model.color/emissive.texture on every option re-push (e.g. the Ctrl-drag
	# vertical-scale changing render.model_scale); deleting early -> "Texture file does
	# not exist" spam + lost texture. The per-face palette goes fully in-memory (gap #1).
	tmp_files = String[]
	if do_drape                                 # external image draped over surface
		palette_path = joinpath(tempdir(), "f3d_drape_$(getpid()).png")
		if drape_clip                           # honour image coords: paint only the overlap
			gx0, gx1 = extrema(@view fvm.verts[:, 1])
			gy0, gy1 = extrema(@view fvm.verts[:, 2])
			GMT.gmtwrite(palette_path, drape_to_bbox(drape, gx0, gx1, gy0, gy1))
			# warped canvas has an alpha band (0 outside the image) — enable blending
			# so the non-overlap area reads as transparent, not opaque black.
			F3D.f3d_options_set_as_bool(opts, "render.effect.blending.enable", Cint(1))
		else                                    # stretch image over the whole surface
			GMT.gmtwrite(palette_path, drape)   # GMTimage -> PNG (bands/layout handled)
		end
		F3D.f3d_options_set_as_string(opts, "model.color.texture", collapse_path(palette_path))
		push!(tmp_files, palette_path)
		# A single headlight leaves draped imagery dim; make the image emissive so it
		# shows near true-colour. `drape_light` is the emissive factor (1.0 = full image
		# colour, lower keeps more relief shading). When `drape_emis` is given it is the
		# emissive texture instead of the colour one — used by outside=:mesh so the grey
		# (lit, edge-bearing) fill emits nothing while the image still glows.
		emis_path = palette_path
		if (!isempty(drape_emis))
			emis_path = joinpath(tempdir(), "f3d_drape_emis_$(getpid()).png")
			GMT.gmtwrite(emis_path, drape_emis)
			push!(tmp_files, emis_path)
		end
		F3D.f3d_options_set_as_string(opts, "model.emissive.texture", collapse_path(emis_path))
		ef = Cdouble(drape_light)
		F3D.f3d_options_set_as_double_vector(opts, "model.emissive.factor", Cdouble[ef, ef, ef], Csize_t(3))
		# `drape_unlit`: kill diffuse lighting so the surface shows ONLY the (full)
		# emissive texture -> dead-flat, NO relief shading. Used by outside=:mesh, whose
		# baked canvas is already flat fill + lines; any headlight would re-introduce the
		# grey shading the user does not want.
		drape_unlit && F3D.f3d_options_set_as_double(opts, "render.light.intensity", Cdouble(0.0))
	elseif m.ncolors > 0                        # per-face colour palette
		if _has_inmem_texture()                 # in-memory (gap #1): no temp PNG, survives re-render
			palimg = F3D.f3d_image_new_params(Cuint(m.ncolors), Cuint(1), Cuint(3), F3D.BYTE)
			GC.@preserve m F3D.f3d_image_set_content(palimg, pointer(m.palette))
			F3D.f3d_window_set_color_texture(window, palimg)   # copies content into the renderer
			F3D.f3d_image_delete(palimg)
		else
			pp = write_palette_png(m.palette, m.ncolors)
			F3D.f3d_options_set_as_string(opts, "model.color.texture", pp)
			push!(tmp_files, pp)
		end
	end

	GC.@preserve m begin
		nrm = isempty(m.normals)   ? C_NULL : pointer(m.normals)
		tex = isempty(m.texcoords) ? C_NULL : pointer(m.texcoords)
		mesh = Ref(F3D.f3d_mesh_t(pointer(m.points), Csize_t(length(m.points)),
		                          nrm,               Csize_t(length(m.normals)),       # per-vertex normals
		                          tex,               Csize_t(length(m.texcoords)),     # texcoords -> colour
		                          pointer(m.sides),  Csize_t(length(m.sides)),
		                          pointer(m.indices),Csize_t(length(m.indices))
		                          ))

		err = Ref{Cstring}(C_NULL)
		if (F3D.f3d_mesh_is_valid(mesh, err) != 1)
			msg = err[] == C_NULL ? "unknown" : unsafe_string(err[])
			err[] != C_NULL && F3D.f3d_utils_string_free(err[])
			F3D.f3d_engine_delete(engine)
			error("generated mesh is invalid: $msg")
		end
		(err[] != C_NULL) && F3D.f3d_utils_string_free(err[])

		F3D.f3d_scene_add_mesh(scene, mesh) == 1 || error("f3d_scene_add_mesh failed")
	end

	isempty(lights) || add_lights!(scene, lights)

	println(title, ": ", length(m.points) ÷ 3, " vertices, ", length(m.sides),
			" faces, ", m.ncolors, " colours, ", length(lights), " lights")

	# Top-down map view: parallel (orthographic) projection + camera straight above,
	# north (+Y) up. No perspective distortion, so the saved frame maps linearly onto
	# the grid x/y range -> can be georeferenced back in GMT (mat2img with the range).
	topdown && F3D.f3d_options_set_as_bool(opts, "scene.camera.orthographic", Cint(1))

	camera = F3D.f3d_window_get_camera(window)
	F3D.f3d_camera_reset_to_bounds(camera, topdown ? 1.0 : 0.9)
	if topdown
		fp = zeros(Cdouble, 3);  F3D.f3d_camera_get_focal_point(camera, fp)
		ps = zeros(Cdouble, 3);  F3D.f3d_camera_get_position(camera, ps)
		d  = hypot(ps[1]-fp[1], ps[2]-fp[2], ps[3]-fp[3])
		F3D.f3d_camera_set_position(camera, [fp[1], fp[2], fp[3] + d])   # straight above
		F3D.f3d_camera_set_view_up(camera, [0.0, 1.0, 0.0])             # north up
		F3D.f3d_camera_reset_to_bounds(camera, 1.0)                     # reframe top-down
		# reset_to_bounds fits the bounding SPHERE (Z relief inflates its radius) -> data
		# smaller than frame -> black border. Calibrate empirically: render once on a magenta
		# sentinel bg, measure how far the data falls short of each edge, then zoom IN by that
		# factor so the data fills the frame exactly (no border, no crop). min() over both
		# axes guarantees we never over-zoom into a crop.
		F3D.f3d_options_set_as_double_vector(opts, "render.background.color",
											 Cdouble[1.0, 0.0, 1.0], Csize_t(3))
		F3D.f3d_window_render(window)
		cimg = F3D.f3d_window_render_to_image(window, Cint(0))
		cw = Int(F3D.f3d_image_get_width(cimg));  ch = Int(F3D.f3d_image_get_height(cimg))
		nc = Int(F3D.f3d_image_get_channel_count(cimg))
		buf = unsafe_wrap(Array, Ptr{UInt8}(F3D.f3d_image_get_content(cimg)), cw * ch * nc)
		issent(x, y) = (p = ((y * cw + x) * nc) + 1;                    # row-major from origin
						buf[p] > 240 && buf[p+1] < 15 && buf[p+2] > 240)
		x0 = cw; x1 = -1; y0 = ch; y1 = -1
		@inbounds for y in 0:ch-1, x in 0:cw-1
			issent(x, y) && continue
			x < x0 && (x0 = x);  x > x1 && (x1 = x);  y < y0 && (y0 = y);  y > y1 && (y1 = y)
		end
		F3D.f3d_image_delete(cimg)
		if x1 >= x0 && y1 >= y0
			f = min(cw / (x1 - x0 + 1), ch / (y1 - y0 + 1))            # fill factor, no crop
			f > 1.0001 && F3D.f3d_camera_zoom(camera, Cdouble(f))
		end
		bgc2 = Cdouble[bg[1], bg[2], bg[3]]                            # restore real background
		F3D.f3d_options_set_as_double_vector(opts, "render.background.color", bgc2, Csize_t(3))
	end
	azimuth   == 0 || F3D.f3d_camera_azimuth(camera, Cdouble(azimuth))      # orbit horizontally
	elevation == 0 || F3D.f3d_camera_elevation(camera, Cdouble(elevation))  # tilt for oblique view
	F3D.f3d_window_render(window)            # first render

	# Labelled cube axes with coordinates in EVERY figure — incl. offscreen / savepng
	# exports (enabled here, before the frame grab, not only on the interactive path).
	# Needs the f3d_ext DLL; on a stock binary it is silently skipped.
	if (cube_axes && _has_f3d_ext())
		F3D.f3d_ext_enable_cube_axes(window)
		F3D.f3d_window_render(window)
	end

	# Colour scale (right edge): `colorbar` is a NamedTuple (rgb, n, vmin, vmax[, title,
	# fmt]) built by the caller from the colouring palette + value range. In every
	# figure incl. offscreen exports. Needs the f3d_ext DLL.
	if (colorbar !== nothing && _has_f3d_ext())
		F3D.f3d_ext_enable_colorbar(window, colorbar.rgb, colorbar.n, colorbar.vmin,
			colorbar.vmax, get(colorbar, :title, ""), get(colorbar, :fmt, "%.1f"))
		F3D.f3d_window_render(window)
	end

	# Line overlays drawn ON TOP (coastlines/tracks/contours). In every figure incl.
	# offscreen exports. `line_zfac` matches the surface's vertical scale. Needs f3d_ext.
	_draw_lines(window, lines, line_color, line_width, line_zfac)

	if !isempty(savepng)                        # grab the rendered frame to a file
		img = F3D.f3d_window_render_to_image(window, Cint(0))
		if georef !== nothing && lowercase(splitext(savepng)[2]) == ".tiff"
			# GeoTIFF: build a georeferenced GMTimage from the IN-MEMORY frame and gmtwrite it
			# (GDAL GTiff). We never gmtread the output -> no Windows file lock. VTK's frame
			# origin is bottom-left, so flip rows to north-up; pixels are RGB(A)-interleaved.
			cw = Int(F3D.f3d_image_get_width(img));  ch = Int(F3D.f3d_image_get_height(img))
			nc = Int(F3D.f3d_image_get_channel_count(img))
			buf = unsafe_wrap(Array, Ptr{UInt8}(F3D.f3d_image_get_content(img)), cw * ch * nc)
			A = Array{UInt8}(undef, ch, cw, 3)   # (rows=lat north->south, cols=lon west->east)
			@inbounds for j in 1:ch, i in 1:cw
				base = ((ch - j) * cw + (i - 1)) * nc      # VTK row (ch-j) = north when j=1
				A[j, i, 1] = buf[base + 1];  A[j, i, 2] = buf[base + 2];  A[j, i, 3] = buf[base + 3]
			end
			Inew = GMT.mat2img(A; x=[Float64(georef[1]), Float64(georef[2])], y=[Float64(georef[3]), Float64(georef[4])])
			pj = String(georef[5])
			isempty(pj) || (occursin("+", pj) ? (Inew.proj4 = pj) : (Inew.wkt = pj))
			GMT.gmtwrite(savepng, Inew)
			println("saved GeoTIFF ", savepng)
		else
			F3D.f3d_image_save(img, savepng, savefmt)
			println("saved ", savepng)
		end
	end

	if offscreen
		for f in tmp_files; rm(f; force=true); end   # drape temp PNGs (none if in-memory palette)
		F3D.f3d_engine_delete(engine)
		return nothing
	end

	interactor = F3D.f3d_engine_get_interactor(engine)
	F3D.f3d_interactor_init_commands(interactor)
	F3D.f3d_interactor_init_bindings(interactor)
	# Extended interactions (need a rebuilt f3d_ext DLL): labelled cube axes,
	# coordinate readout, Ctrl+left-drag vertical exaggeration. Enabled after the
	# render above so the cube axes can capture the data bounds.
	disable_extras = _enable_extras(window, opts; cube_axes=cube_axes,   # re-assert (idempotent)
									coord_readout=coord_readout, vscale_drag=vscale_drag,
									vscale_step=vscale_step, scale_handle=scale_handle,
									colorbar=colorbar)   # swap the static bar for a draggable one
	_handle_chan === nothing || put!(_handle_chan, interactor)   # async: let the REPL close! us
	_interactor_start_gcsafe(interactor, 1.0 / 30.0)    # blocks until window closed (GC-safe)

	# f3d's start() registers a repeating Win32 timer but does NOT kill it when the loop
	# exits (only stop() does) -> a stray WM_TIMER can hit vtkWin32RenderWindowInteractor::
	# OnTimer on a half-torn-down interactor => EXCEPTION_ACCESS_VIOLATION on close. Stop
	# the interactor first (DestroyTimer) before tearing the scene/engine down.
	F3D.f3d_interactor_stop(interactor)
	disable_extras()
	colorbar !== nothing && _has_f3d_ext() && F3D.f3d_ext_disable_colorbar(window)
	lines === nothing || !_has_f3d_ext() || F3D.f3d_ext_clear_lines(window)
	for f in tmp_files; rm(f; force=true); end   # delete drape temp PNGs only now (window closed)
	F3D.f3d_scene_clear(scene)        # drop actors before GL teardown -> avoids close-time AV in engine_delete
	F3D.f3d_engine_delete(engine)
	return nothing
end

# ---------------------------------------------------------------------------
# Demo helper: colour a solid's faces with a hue ramp keyed on face-centroid z,
# filling `fv.color` with GMT "-G#rrggbb" strings so view_fv has colours to show.
# ---------------------------------------------------------------------------
function colorize_by_z!(fv::GMT.GMTfv)
	V = fv.verts
	zmin, zmax = extrema(@view V[:, 3])
	span = (zmax > zmin) ? (zmax - zmin) : 1.0
	fv.color = Vector{Vector{String}}(undef, length(fv.faces))
	for (g, Fm) in enumerate(fv.faces)
		if isempty(Fm)
			fv.color[g] = String[];  continue
		end
		nf, npf = size(Fm)
		cols = Vector{String}(undef, nf)
		for r in 1:nf
			zc = sum(V[Fm[r, c], 3] for c in 1:npf) / npf
			t  = (zc - zmin) / span
			# simple blue -> red ramp
			rr = round(Int, 255 * t);  bb = round(Int, 255 * (1 - t));  gg = round(Int, 80 + 100 * (1 - abs(2t - 1)))
			cols[r] = string("-G#", lpad(string(rr, base=16), 2, '0'),
									lpad(string(gg, base=16), 2, '0'),
									lpad(string(bb, base=16), 2, '0'))
		end
		fv.color[g] = cols
	end
	return fv
end

# ---------------------------------------------------------------------------
# Origin trihedron as real geometry: three colour-coded arrows along +X (red),
# +Y (green), +Z (blue) starting at (0,0,0) — a thin box shaft + a cone tip.
# Appended to the FV as extra colour-groups (one of quads for the shafts, one of
# triangles for the cones) so the existing fv_to_mesh colour path folds the three
# axis colours into the same palette/texture — no separate mesh, no extra texture.
# Lets you see the object's position/scale/orientation relative to the origin.
# ---------------------------------------------------------------------------
function _box(x0, x1, y0, y1, z0, z1)
	V = Float64[x0 y0 z0; x1 y0 z0; x1 y1 z0; x0 y1 z0;
				x0 y0 z1; x1 y0 z1; x1 y1 z1; x0 y1 z1]
	F = Int[1 4 3 2; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8]  # CCW outward
	return V, F
end

# Cone along axis `a` (1=X,2=Y,3=Z): base ring (radius cr) at coord `base`,
# apex at `tip`. Returns verts ((nseg+2)×3) and triangle faces ((2*nseg)×3),
# face indices local 1-based: ring 1..nseg, apex nseg+1, base centre nseg+2.
function _cone(a::Int, base::Float64, tip::Float64, cr::Float64, nseg::Int)
	p1, p2 = ((2, 3), (3, 1), (1, 2))[a]               # the two axes ⊥ to `a`
	ncv = nseg + 2
	V = zeros(Float64, ncv, 3)
	for k in 1:nseg
		θ = 2π * (k - 1) / nseg
		V[k, a]  = base
		V[k, p1] = cr * cos(θ)
		V[k, p2] = cr * sin(θ)
	end
	V[nseg+1, a] = tip                                  # apex
	V[nseg+2, a] = base                                 # base centre
	F = Matrix{Int}(undef, 2nseg, 3)
	for k in 1:nseg
		kn = k % nseg + 1
		F[k, 1], F[k, 2], F[k, 3]                = nseg + 1, k,  kn   # side (apex,k,k+1)
		F[nseg+k, 1], F[nseg+k, 2], F[nseg+k, 3] = nseg + 2, kn, k    # base cap (centre,k+1,k)
	end
	return V, F
end

function add_trihedron!(fv::GMT.GMTfv; len=nothing, lenfrac=(1.05, 1.05, 1.10),
						rad=nothing, headlen=nothing, nseg::Int=16,
						anchor=nothing, colors=("#ff3030", "#30c030", "#3060ff"))
	V = fv.verts
	vmin = vec(minimum(V, dims = 1))
	vmax = vec(maximum(V, dims = 1))
	ext = vmax .- vmin                                        # (dx, dy, dz) model extents
	S = maximum(ext);  (S <= 0 || !isfinite(S)) && (S = 1.0)  # characteristic model size
	# Where the arrows sit. Default = the model's min corner (so the trihedron
	# rides on the data); for geographic/offset grids the true world origin
	# (0,0,0) is far away and would push the axes off-screen. `anchor` overrides
	# (pass (0,0,0) for the real origin).
	o = anchor === nothing ? vmin : Float64[anchor[1], anchor[2], anchor[3]]
	# Each arrow spans `lenfrac[a]` of THAT axis' own (already z-scaled) extent,
	# so the axes run the full data and poke a little past the edge. Default:
	# X,Y = 1.05x (5% overshoot) of their horizontal fig dimension; Z = 1.10x of
	# its z extent — which already carries `vexag`, so Z tracks the vertical
	# exaggeration.
	Laxis = len === nothing ? ntuple(a -> lenfrac[a] * ext[a], 3) :
			len isa Number   ? ntuple(_ -> float(len), 3) :
							   ntuple(a -> float(len[a]), 3)
	r  = rad === nothing ? 0.0015 * S : float(rad)      # thin shafts (keyed to model size)
	cr = 4.0 * r                                        # cone base radius
	hl = headlen === nothing ? 0.04 * S : float(headlen) # arrowhead length, SAME for all axes

	# --- shafts: 3 boxes, quads --- full length `Laxis`; arrowhead added ON TOP
	bars = (_box(0.0, Laxis[1], -r, r, -r, r),          # X
			_box(-r, r, 0.0, Laxis[2], -r, r),          # Y
			_box(-r, r, -r, r, 0.0, Laxis[3]))          # Z
	Vbar = Matrix{Float64}(undef, 24, 3)
	Fbar = Matrix{Int}(undef, 18, 4)
	colbar = Vector{String}(undef, 18)
	vo = fo = 0
	for (b, (Vb, Fb)) in enumerate(bars)
		Vbar[vo+1:vo+8, :] = Vb
		Fbar[fo+1:fo+6, :] = Fb .+ vo
		colbar[fo+1:fo+6] .= "-G" * colors[b]
		vo += 8;  fo += 6
	end

	# --- cones: 3 arrowheads, triangles ---
	ncv = nseg + 2
	Vcone  = Matrix{Float64}(undef, 3ncv, 3)
	Fcone  = Matrix{Int}(undef, 3 * 2nseg, 3)
	colcone = Vector{String}(undef, 3 * 2nseg)
	vo = fo = 0
	for a in 1:3
		Vc, Fc = _cone(a, Laxis[a], Laxis[a] + hl, cr, nseg)   # base at axis tip, apex hl beyond
		Vcone[vo+1:vo+ncv, :] = Vc
		Fcone[fo+1:fo+2nseg, :] = Fc .+ vo
		colcone[fo+1:fo+2nseg] .= "-G" * colors[a]
		vo += ncv;  fo += 2nseg
	end

	Vbar  .+= o'                                        # shift arrows to the anchor corner
	Vcone .+= o'
	nv0 = size(fv.verts, 1)
	fv.verts = vcat(fv.verts, Vbar, Vcone)
	push!(fv.faces, Fbar .+ nv0);            push!(fv.color, colbar);  push!(fv.isflat, false)
	push!(fv.faces, Fcone .+ (nv0 + 24));    push!(fv.color, colcone); push!(fv.isflat, false)
	return fv
end

# Catalogue of solids to demo. Each builds and returns a GMTfv.
const SOLIDS = Dict(
	"icosahedron" => () -> icosahedron(1.0),
	"octahedron"  => () -> octahedron(1.0),
	"dodecahedron"=> () -> dodecahedron(1.0),
	"tetrahedron" => () -> tetrahedron(1.0),
	"cube"        => () -> cube(1.0),
	"sphere"      => () -> sphere(1.0, n=3),
	"torus"       => () -> torus(r=2.0, R=5.0),
	"cylinder"    => () -> cylinder(1.0, 3.0),
)

# A simple two-source rig: a warm key light from upper-right-front and a dim
# cool fill from the left, both fixed in the world (SCENE lights).
const DEMO_LIGHTS = (
	(; type=:scene, direction=(-1.0, -1.0, -1.0), intensity=1.3, color=(1.0, 0.96, 0.9)),
	(; type=:scene, direction=( 1.0,  0.3,  0.2), intensity=0.4, color=(0.8, 0.85, 1.0)),
)

# ---------------------------------------------------------------------------
# Grid bridge: GMT.grid2tri(G) -> GMTfv -> F3D
# ---------------------------------------------------------------------------
# GMT's `grid2tri` turns a GMTgrid into a Vector{GMTdataset} of 3-D triangle
# polygons (top surface, optionally + vertical wall / bottom). Each dataset is
# one closed triangle (4 rows, row 4 == row 1). F3D wants a single mesh, so we
# fold those triangles into a GMTfv — one independent face per triangle (no
# vertex sharing, which keeps per-face colour trivial) — then reuse view_fv.
# Faces are colour-coded by their mean z through a GMT colormap (turbo), so the
# render carries the same height shading GMT's psxy path would draw.

# z value -> "#rrggbb" via a GMTcpt colormap (Mx3, stored 0-1 or 0-255).
function z_to_hex(z, cmap::AbstractMatrix, zmin, zmax)
	N = size(cmap, 1)
	t = zmax > zmin ? (z - zmin) / (zmax - zmin) : 0.0
	i = clamp(round(Int, t * (N - 1)) + 1, 1, N)
	s = maximum(cmap) > 1.0 ? 1.0 : 255.0            # detect 0-1 vs 0-255 storage
	r = round(Int, clamp(cmap[i, 1] * s, 0, 255))
	g = round(Int, clamp(cmap[i, 2] * s, 0, 255))
	b = round(Int, clamp(cmap[i, 3] * s, 0, 255))
	return string("#", lpad(string(r, base = 16), 2, '0'),
					   lpad(string(g, base = 16), 2, '0'),
					   lpad(string(b, base = 16), 2, '0'))
end

const DEG2M = 111194.9          # ~1 geographic degree in metres (GMT's value)

const GEOG_VFRAC = 0.135        # geog auto: displayed z-range / horizontal extent.
								# 0.135 reproduces the vexag=20 look on a ~10-deg,
								# ~7.5 km-relief grid and generalises to any grid.

# Resolve the factor that multiplies z. A numeric `zscale` is used verbatim.
# `:auto` adapts to the data:
#   * GEOG grid (x,y in degrees, z assumed in metres) with a NUMERIC `vexag`:
#     z is converted to degree units (z/DEG2M) for a true 1:1 scale, then
#     multiplied by `vexag` (a real vertical exaggeration factor).
#   * GEOG grid with `vexag=:auto` (the default): pick the exaggeration that
#     makes the displayed z-range = GEOG_VFRAC x the horizontal extent — i.e.
#     a good-looking slab (~ vexag 20), no flat invisible sheet.
#   * non-geog: same flat-slab idea with `vfrac` (never a cube / invisible sheet).
function _resolve_zscale(zscale, dx, dy, dz, vfrac, isgeog, vexag)
	zscale === :auto || return float(zscale)
	(isgeog && vexag !== :auto) && return float(vexag) / DEG2M   # explicit exaggeration
	horiz = max(dx, dy)
	(dz > 0 && horiz > 0) || return 1.0
	frac = isgeog ? GEOG_VFRAC : vfrac                           # auto flat-slab
	return frac * horiz / dz
end

"""
	tri2fv(D; cmap=:turbo, zscale=:auto, vfrac=0.2, vexag=1.0, isgeog=false, ncolor=256) -> GMTfv

Fold a `Vector{GMTdataset}` of 3-D triangles (as returned by `GMT.grid2tri`)
into a single coloured `GMTfv`. Each triangle becomes one face with its own
three vertices; faces are coloured by mean z through `cmap`. `ncolor` is the
colormap resolution.

Vertical scale (`zscale=:auto`, the default):
* `isgeog=true` — x,y are degrees and z is assumed in **metres**, so z is
  converted to degree units (true 1:1) and then multiplied by the vertical
  exaggeration `vexag` (default 1.0). Set `isgeog` from `GMT.isgeog(grid)`.
* `isgeog=false` — purely geometric: the displayed z-range is set to `vfrac`
  times the largest horizontal extent (`vfrac=0.2` ~ a gentle slab), so the
  surface reads *flatter than a cube*.

Pass a number for `zscale` to override completely (e.g. `zscale=1` for raw 1:1).
Colours always key off the true (un-scaled) z.
"""
function tri2fv(D::Vector{<:GMT.GMTdataset}; cmap=:turbo, zscale=:auto,
				vfrac=0.2, vexag=:auto, isgeog::Bool=false, ncolor::Int=256)
	nT = length(D)
	nT == 0 && error("grid2tri returned no triangles")
	V  = Matrix{Float64}(undef, 3nT, 3)
	F  = Matrix{Int}(undef, nT, 3)
	zc = Vector{Float64}(undef, nT)                  # per-face mean z (true, for colour)
	@inbounds for k in 1:nT
		d = D[k].data                                # 4x3, row 4 == row 1; first 3 are the corners
		b = 3 * (k - 1)
		for c in 1:3
			V[b+c, 1] = d[c, 1];  V[b+c, 2] = d[c, 2];  V[b+c, 3] = d[c, 3]   # z un-scaled here
		end
		F[k, 1], F[k, 2], F[k, 3] = b + 1, b + 2, b + 3
		zc[k] = (d[1, 3] + d[2, 3] + d[3, 3]) / 3
	end
	xmin, xmax = extrema(@view V[:, 1])
	ymin, ymax = extrema(@view V[:, 2])
	zmin, zmax = extrema(@view V[:, 3])
	s = _resolve_zscale(zscale, xmax - xmin, ymax - ymin, zmax - zmin, vfrac, isgeog, vexag)
	s == 1.0 || (@inbounds @views V[:, 3] .*= s)     # apply vertical scale to geometry
	czmin, czmax = extrema(zc)                        # colour range from true z
	step = czmax > czmin ? (czmax - czmin) / ncolor : 1.0
	C  = GMT.makecpt(cmap = string(cmap), range = (czmin, czmax, step))
	cm = C.colormap
	col = [string("-G", z_to_hex(zc[k], cm, czmin, czmax)) for k in 1:nT]
	bb = Float64[xmin, xmax, ymin, ymax, extrema(@view V[:, 3])...]
	return GMT.GMTfv(verts = V, faces = [F], color = [col], bbox = bb, isflat = [false])
end

"""
	grid2fv(G; cmap=:turbo, zscale=:auto, vfrac=0.2, vexag=1.0, ncolor=256, kw...) -> GMTfv

Triangulate a grid with `GMT.grid2tri(G; kw...)` and convert to a coloured
`GMTfv` ready for F3D. The vertical scale is geog-aware: if `GMT.isgeog(G)` is
true, x,y are degrees and z is assumed in metres, so `:auto` gives a true 1:1
scale times `vexag`; otherwise `:auto` uses the `vfrac` flat-slab heuristic (see
`tri2fv`). `kw...` are forwarded to `grid2tri` (`thickness`, `wall_only`,
`top_only`, `bottom`, `downsample`, `ratio`, `geog`, ...).
"""
function grid2fv(G; cmap=:turbo, zscale=:auto, vfrac=0.2, vexag=:auto, ncolor::Int=256, kwargs...)
	D = GMT.grid2tri(G; kwargs...)
	return tri2fv(D; cmap=cmap, zscale=zscale, vfrac=vfrac, vexag=vexag, isgeog=GMT.isgeog(G), ncolor=ncolor)
end

"""
	view_grid(G; kwargs...)

Visualise a GMT grid `G` (a `GMTgrid` or a grid file name) in F3D: `grid2tri` ->
coloured `GMTfv` -> interactive viewer (or an offscreen export).

# Surface & colour
- `cmap=:turbo`: GMT colormap name for the elevation colouring.
- `ncolor=256`: number of colour levels.
- `zscale=:auto`: vertical scale. `:auto` is geog-aware — geographic grids
  (`GMT.isgeog(G)`) get a true 1:1 metre scale, others the `vfrac` flat-slab look.
  A number overrides it directly.
- `vexag=:auto`: vertical exaggeration multiplier applied on top of `zscale`.
- `vfrac=0.2`: target relief height as a fraction of the xy span (non-geographic
  `:auto` only).

# Mesh build (forwarded to `GMT.grid2tri`)
- `thickness=0.0`, `isbase=false`, `bottom=false`, `wall_only=false`,
  `top_only=false`: solid/wall options.
- `downsample=0`: decimate the grid before triangulating (0 = none).
- `ratio=0.01`: triangulation simplification ratio.
- `geog=false`: force geographic handling.

# Image draping
- `drape=nothing`: a `GMTimage` to drape over the surface as a texture.
- `drape_clip=false`: when `true`, paint only the grid ∩ image overlap and let
  `outside` decide the rest. When `false`, the image is stretched over the whole
  surface.
- `outside=:drop`: what to do with the grid area the image does NOT cover
  (`drape_clip=true` only):
	- `:drop` — crop the grid to the overlap (no resample); rest not shown.
	- `:shade` — keep full grid; uncovered area = flat `outside_color` fill, no edges.
	- `:shademesh` — like `:shade` but with mesh edges on top.
	- `:transparent` — keep full grid; uncovered area is see-through.
- `outside_color=200`: fill colour for `:shade`/`:shademesh` — a grey `0-255`, or
  an `(r,g,b)` tuple (`0-255` ints, or `0-1` floats).

# Colour bar
- `colorbar=true`: draw a colour scale (right edge) keyed on the grid's true z range
  and `cmap`. Auto-suppressed when an image is draped (the surface shows the picture,
  not a z ramp). Needs an f3d built with `c/f3d_ext_*.cxx`.

# Export (forwarded to `view_fv`)
- `mapexport=""`: one-shot georeferenced map. Forces orthographic top-down +
  offscreen and saves to this file (extension picks the format: `png`/`jpg`/`tif`/
  `bmp`, default `png`). A `.tiff` extension writes a GeoTIFF stamped with the
  grid's range and projection.
- `savepng=""`: save the current view to a file (any of the formats above), without
  forcing top-down.
- `topdown=false`: orthographic straight-down, north-up view (georeferenceable).
- `offscreen=false`: render without opening a window.

# View (forwarded to `view_fv`)
- `title`, `size=(1600,1200)`, `bg=(0.1,0.1,0.15)`: window title, pixel size,
  background colour.
- `async=true`: viewer on a worker thread → REPL gets a `ViewHandle` at once
  (`close!(h)`); `false` blocks until the window closes.
- `lights=()`: vector of light NamedTuples (see `add_lights!`).
- `azimuth=-40`, `elevation=25`: orbit / tilt the camera (degrees).
- `up="+Z"`: scene up-direction (defaulted to `"+Z"` so grids lie flat, X,Y floor).
- `flat=false`: flat (faceted) shading instead of smooth.
- `axes=true`, `grid=true`: orientation gizmo / f3d floor grid (both forced off
  under `topdown`).
- `edges=false`, `linewidth=1.0`: draw mesh edges and their width.
- `trihedron=false`: add an XYZ trihedron to the mesh.

# Extended interactions (forwarded; need an f3d built with `c/f3d_ext_*.cxx`)
- `cube_axes=true`: labelled bounding-box (X/Y/Z tick) axes with coords.
- `coord_readout=true`: live world X/Y/Z under the cursor.
- `vscale_drag=true`, `vscale_step=0.01`: Ctrl+left-drag to exaggerate / flatten the
  relief (`vscale_step` per dragged pixel).
- `scale_handle=false`: Fledermaus-style gizmo at the rotation centre — drag the vertical
  arrowhead (vertical scale), horizontal arrows (tilt), or compass ring (azimuth).

# Material (forwarded to `view_fv`; `nothing` keeps f3d defaults)
- `metallic=nothing`: PBR metalness, scalar `0-1`.
- `roughness=nothing`: PBR roughness, scalar `0-1`.
- `emissive=nothing`: self-illumination factor — a scalar grey or an `(r,g,b)`
  tuple (`0-1`).

Any other `view_fv` keyword (e.g. `drape_light`, `drape_emis`, `drape_unlit`,
`georef`) passes straight through.

E.g. `view_grid(GMT.peaks())`, `view_grid("dem.grd"; vexag=5)`, or
`view_grid(G; drape=I, mapexport="lit.tiff")`.
"""
function view_grid(G; cmap=:turbo, zscale=:auto, vfrac=0.2, vexag=:auto, ncolor::Int=256,
				   thickness=0.0, isbase=false, downsample=0, ratio=0.01,
				   bottom=false, wall_only=false, top_only=false, geog=false,
				   drape::GMT.GMTimage=GMT.GMTimage(), drape_clip::Bool=false,
				   outside::Symbol=:drop, outside_color=200, colorbar::Bool=true, kwargs...)
	# Georeferenced drape (`drape_clip=true`): only the grid ∩ image area carries the
	# image. `outside` controls the grid area NOT covered by the image:
	#   :drop        – crop the grid to the overlap; uncovered area is not shown.
	#                  Cheapest: crop BOTH grid and image to their bbox intersection
	#                  (in-memory subset, NO gdalwarp/resample) and stretch-drape.
	#   :shade       – keep the full grid; uncovered area is a flat fixed colour
	#                  (`outside_color`, grey 0-255), NO mesh edges.
	#   :shademesh   – like :shade but with global mesh edges on top.
	#   :transparent – keep the full grid; uncovered area is invisible (see-through).
	# :shade/:shademesh pad the image into the grid bbox by index copy (no gdal). Only
	# :transparent still uses an alpha warp (drape_clip path in view_fv).
	# geo footprint (x0,x1,y0,y1,proj) of a grid -> lets view_fv stamp a GeoTIFF on .tiff export.
	geo(g) = (g.range[1], g.range[2], g.range[3], g.range[4], isempty(g.proj4) ? g.wkt : g.proj4)
	# Grid viewer defaults (caller can override any): lay the surface flat with Z up
	# (X,Y on the floor) and show the labelled cube axes. These flow on to view_fv.
	vkw = Dict{Symbol,Any}(kwargs)
	get!(vkw, :up, "+Z")
	get!(vkw, :cube_axes, true)

	# Line overlays (`lines=`) carry z in DATA units; the surface is drawn with the
	# vertical scale `_resolve_zscale` gives, so forward that SAME factor as `line_zfac`
	# (else the line floats off the surface). N x 2 lines have no z -> lie on z = 0.
	if haskey(vkw, :lines) || haskey(vkw, :L)
		Gh = isa(G, GMT.GMTgrid) ? G : GMT.gmtread(G)
		r  = Gh.range
		get!(vkw, :line_zfac,
			 _resolve_zscale(zscale, r[2] - r[1], r[4] - r[3], r[6] - r[5], vfrac, GMT.isgeog(Gh), vexag))
	end
	if !isempty(drape) && drape_clip
		Gin = isa(G, GMT.GMTgrid) ? G : GMT.gmtread(G)
		full(g) = grid2fv(g; cmap=cmap, zscale=zscale, vfrac=vfrac, vexag=vexag, ncolor=ncolor,
						  thickness=thickness, isbase=isbase, downsample=downsample,
						  ratio=ratio, bottom=bottom, wall_only=wall_only, top_only=top_only, geog=geog)
		if (outside === :drop)
			# crop BOTH grid and image to their bbox intersection (in-memory subset,
			# no gdalwarp/resample) and stretch-drape; uncovered area is not built.
			gr, ir = Gin.range, drape.range
			ix0, ix1 = max(gr[1], ir[1]), min(gr[2], ir[2])
			iy0, iy1 = max(gr[3], ir[3]), min(gr[4], ir[4])
			(ix1 > ix0 && iy1 > iy0) || error("grid and image bounding boxes do not overlap")
			Gc = GMT.crop(Gin, region=(ix0, ix1, iy0, iy1))[1]
			Ic = GMT.crop(drape, region=(ix0, ix1, iy0, iy1))[1]
			return view_fv(full(Gc); drape=Ic, drape_clip=false, georef=geo(Gc), vkw...)
		elseif (outside === :transparent)
			# full grid; warp image onto the grid bbox with alpha 0 outside -> uncovered
			# area is see-through (drape_clip path enables blending).
			return view_fv(full(Gin); drape=drape, drape_clip=true, georef=geo(Gin), vkw...)
		elseif (outside === :shade)
			# full grid; uncovered area = flat `outside_color` fill, NO edges. `drape_pad`
			# places the image into the full-grid-bbox canvas by index copy (NO gdal/
			# resample): colour = image + fixed-colour fill outside (lit -> relief shading);
			# emissive = image + BLACK fill outside (fill emits nothing, only image glows).
			gr = Gin.range
			Cg, Ce = drape_pad(drape, gr[1], gr[2], gr[3], gr[4]; fill=outside_color)
			return view_fv(full(Gin); drape=Cg, drape_emis=Ce, drape_clip=false, georef=geo(Gin), vkw...)
		elseif (outside === :shademesh)
			# like :shade but with global mesh edges on top (the combined look).
			gr = Gin.range
			Cg, Ce = drape_pad(drape, gr[1], gr[2], gr[3], gr[4]; fill=outside_color)
			kw = copy(vkw)
			kw[:edges]     = true
			kw[:linewidth] = get(kw, :linewidth, 1.0)
			return view_fv(full(Gin); drape=Cg, drape_emis=Ce, drape_clip=false, georef=geo(Gin), kw...)
		else
			error("`outside` must be :drop, :shade, :shademesh or :transparent (got :$outside)")
		end
	end

	Gp = isa(G, GMT.GMTgrid) ? G : GMT.gmtread(G)
	fv = grid2fv(Gp; cmap=cmap, zscale=zscale, vfrac=vfrac, vexag=vexag, ncolor=ncolor,
				 thickness=thickness, isbase=isbase, downsample=downsample,
				 ratio=ratio, bottom=bottom, wall_only=wall_only, top_only=top_only, geog=geog)

	# Colour scale keyed on the grid's true z range + the same colormap (not when an
	# image is draped — then the surface shows the picture, not a z-colour ramp).
	if colorbar && isempty(drape)
		zmn, zmx = Float64(Gp.range[5]), Float64(Gp.range[6])
		nd = _axis_decimals(zmx - zmn)
		get!(vkw, :colorbar, (rgb=cmap_palette(cmap, ncolor), n=ncolor,
							  vmin=zmn, vmax=zmx, title="", fmt="%.$(nd)f"))
	end
	return view_fv(fv; drape=drape, drape_clip=drape_clip, georef=geo(Gp), vkw...)
end

# Georeferenced? An image carries a CRS (proj4 / WKT / EPSG) only when it has been
# referenced; a plain picture (e.g. `mat2img` of an array, or a decoded JPEG/PNG)
# has none. That is exactly the line between "show map coordinates" and "just show
# the picture".
_img_is_georef(I::GMT.GMTimage) = !isempty(I.proj4) || !isempty(I.wkt) || I.epsg != 0

# Minimum decimal places so adjacent axis tick labels stay UNIQUE: VTK lays out up
# to ~`maxticks` ticks across the span, so the smallest step is ~span/maxticks; pick
# enough decimals that that step is non-zero when rounded. Over-resolving (assuming
# more ticks than VTK draws) only adds digits — it never makes labels collide.
function _axis_decimals(span::Real; maxticks::Int=10)
	s = abs(float(span))
	s <= 0 && return 0
	return clamp(ceil(Int, -log10(s / maxticks)), 0, 8)
end

"""
    view_image(I::GMTimage; kwargs...)

Display a 2-D image `I` in an interactive F3D window as a flat, top-down picture —
no intermediate grid. The image is laid on a quad spanning its own extent and
draped on as an unlit texture, so it shows the exact pixels. It is a strict **2-D
viewer**: orthographic, north up, rotation locked (`interactor.style="2d"`, pan +
zoom only), no orientation gizmo.

Whether it is **georeferenced** (carries a CRS — `proj4`/`wkt`/`epsg`) decides two
things automatically:
- a **referenced** image gets the 2-D coordinate frame — an X axis along the
  bottom and a Y axis along the left with outward tick marks and lon/lat labels —
  and the window is sized to the coordinate-extent aspect;
- a **plain** image gets no axes and the window is sized to the pixel aspect.

# Keywords
- `decimals=nothing`: tick-label decimal places (`Int`, or `(dx, dy)` per axis).
  `nothing` auto-picks the fewest decimals that keep every label unique.
- `size=nothing`: explicit window size `(w, h)` in px; `nothing` derives it from the
  image aspect (coordinate extent if referenced, else pixels).
- `title="F3D — GMT image"`: window title bar text.
- `bg=(0.1,0.1,0.15)`: background colour, RGB in `0-1`.
- `savepng=""`: save the frame to this file (format from extension); empty = none.
- `offscreen=false`: render without opening a window (no interaction).
- `async=true`: viewer on a worker thread → REPL gets a `ViewHandle` at once
  (`close!(h)`); `false` blocks until the window closes. Forced off when `offscreen`.

A referenced image also gets the live coordinate readout (lon/lat under the cursor)
in the interactive window.

E.g. `view_image(I)` or `view_image(I; decimals=3)`.
"""
function _view_image_impl(I::GMT.GMTimage; _handle_chan=nothing, title::AbstractString="F3D — GMT image", bg=(0.1, 0.1, 0.15),
		size=nothing, decimals=nothing, offscreen::Bool=false, savepng::String="",
		lines=nothing, line_color=nothing, line_width::Real=2.0, L=nothing)
	lines = L === nothing ? lines : L          # `L` = GMT-style short alias for `lines`
	savefmt = F3D.PNG
	isempty(savepng) || ((savepng, savefmt) = _img_target(savepng))
	isgeo = _img_is_georef(I)
	nr, nc = Base.size(I, 1), Base.size(I, 2)        # rows, cols (kwarg `size` shadows Base.size)

	# Extent: real coordinates if referenced, else the pixel grid.
	r = (length(I.range) >= 4 && I.range[2] > I.range[1] && I.range[4] > I.range[3]) ?
		I.range : Float64[1.0, nc, 1.0, nr]
	x0, x1, y0, y1 = Float64(r[1]), Float64(r[2]), Float64(r[3]), Float64(r[4])

	# Window: match the image aspect (coordinate extent if referenced, else pixels),
	# then pad for the outward ticks + labels when axes are drawn.
	if size === nothing
		asp  = isgeo ? (x1 - x0) / (y1 - y0) : nc / nr
		long = 900
		w, h = asp >= 1 ? (long, max(round(Int, long / asp), 1)) :
						   (max(round(Int, long * asp), 1), long)
		isgeo && (w += 90; h += 70)                  # room for axis annotations
		win = (w, h)
	else
		win = size
	end

	# Flat quad at z=0 spanning the extent, draped with the image.
	V = Float64[x0 y0 0.0; x1 y0 0.0; x1 y1 0.0; x0 y1 0.0]
	quad = GMT.GMTfv(verts=V, faces=[[1 2 3 4]], color=[String[]],
					 bbox=Float64[x0, x1, y0, y1, 0.0, 0.0], isflat=[false])
	m = fv_to_mesh(quad; drape=true)

	F3D.f3d_engine_autoload_plugins()
	engine = F3D.f3d_engine_create(Cint(offscreen ? 1 : 0))
	engine == C_NULL && error("failed to create F3D engine")
	scene  = F3D.f3d_engine_get_scene(engine)
	window = F3D.f3d_engine_get_window(engine)
	F3D.f3d_window_set_size(window, Cint(win[1]), Cint(win[2]))
	F3D.f3d_window_set_window_name(window, title)

	opts = F3D.f3d_engine_get_options(engine)
	F3D.f3d_options_set_as_string_representation(opts, "scene.up_direction", "+Z")
	F3D.f3d_options_set_as_bool(opts, "ui.axis", Cint(0))                # no gizmo
	F3D.f3d_options_set_as_bool(opts, "ui.scalar_bar", Cint(0))
	F3D.f3d_options_set_as_bool(opts, "render.grid.enable", Cint(0))
	F3D.f3d_options_set_as_bool(opts, "scene.camera.orthographic", Cint(1))   # 2-D
	F3D.f3d_options_set_as_string(opts, "interactor.style", "2d")             # lock rotation
	F3D.f3d_options_set_as_double_vector(opts, "render.background.color",
										 Cdouble[bg[1], bg[2], bg[3]], Csize_t(3))

	# Drape the image as an UNLIT texture: emissive = image at full factor and the
	# diffuse light killed, so the quad shows the exact pixels with no relief shading.
	tex_path = joinpath(tempdir(), "f3d_image_$(getpid()).png")
	GMT.gmtwrite(tex_path, I)
	cp = collapse_path(tex_path)
	F3D.f3d_options_set_as_string(opts, "model.color.texture", cp)
	F3D.f3d_options_set_as_string(opts, "model.emissive.texture", cp)
	F3D.f3d_options_set_as_double_vector(opts, "model.emissive.factor", Cdouble[1, 1, 1], Csize_t(3))
	F3D.f3d_options_set_as_double(opts, "render.light.intensity", Cdouble(0.0))

	GC.@preserve m begin
		nrm = isempty(m.normals)   ? C_NULL : pointer(m.normals)
		tex = isempty(m.texcoords) ? C_NULL : pointer(m.texcoords)
		mesh = Ref(F3D.f3d_mesh_t(
			pointer(m.points),   Csize_t(length(m.points)),
			nrm,                 Csize_t(length(m.normals)),
			tex,                 Csize_t(length(m.texcoords)),
			pointer(m.sides),    Csize_t(length(m.sides)),
			pointer(m.indices),  Csize_t(length(m.indices))))
		F3D.f3d_scene_add_mesh(scene, mesh) == 1 ||
			(F3D.f3d_engine_delete(engine); error("f3d_scene_add_mesh failed"))
	end

	# Camera: orthographic, straight above, north up.
	cam = F3D.f3d_window_get_camera(window)
	F3D.f3d_camera_reset_to_bounds(cam, Cdouble(0.95))
	fp = zeros(Cdouble, 3);  F3D.f3d_camera_get_focal_point(cam, fp)
	ps = zeros(Cdouble, 3);  F3D.f3d_camera_get_position(cam, ps)
	d  = hypot(ps[1]-fp[1], ps[2]-fp[2], ps[3]-fp[3])
	F3D.f3d_camera_set_position(cam, [fp[1], fp[2], fp[3] + d])
	F3D.f3d_camera_set_view_up(cam, [0.0, 1.0, 0.0])
	F3D.f3d_camera_reset_to_bounds(cam, Cdouble(0.95))
	F3D.f3d_window_render(window)

	# Box-fit (not sphere-fit): reset_to_bounds fits the bounding sphere and centres
	# the image, wasting space on the long axis + all four sides. Measure the data
	# box on screen and zoom to fill the frame; for a georef image leave a label band
	# at the bottom (X axis) and left (Y axis) and pan the data into the top-right so
	# no space is wasted where there are no labels.
	todisp(wx, wy) = (dd = zeros(Cdouble, 3);
		F3D.f3d_window_get_display_from_world(window, [Cdouble(wx), Cdouble(wy), 0.0], dd); (dd[1], dd[2]))
	a = todisp(x0, y0);  b = todisp(x1, y1)
	dxpx = max(abs(b[1] - a[1]), 1.0);  dypx = max(abs(b[2] - a[2]), 1.0)
	# Bottom/left band carries the X/Y axes; top/right need only a small band so the
	# END labels (centred on the max-x / max-y corner ticks) are not clipped at the edge.
	leftpx  = isgeo ? 0.11 * win[1] : 0.02 * win[1]
	botpx   = isgeo ? 0.12 * win[2] : 0.02 * win[2]
	rightpx = isgeo ? 0.05 * win[1] : 0.02 * win[1]
	toppx   = isgeo ? 0.05 * win[2] : 0.02 * win[2]
	f = min((win[1] - leftpx - rightpx) / dxpx, (win[2] - botpx - toppx) / dypx)
	F3D.f3d_camera_zoom(cam, Cdouble(f));  F3D.f3d_window_render(window)
	# Pan so the data's left edge sits at `leftpx` and bottom edge at `botpx`.
	a = todisp(x0, y0);  b = todisp(x1, y1)
	datl = min(a[1], b[1]);  datb = min(a[2], b[2])
	wppx = (x1 - x0) / max(abs(b[1] - a[1]), 1.0);  wppy = (y1 - y0) / max(abs(b[2] - a[2]), 1.0)
	F3D.f3d_camera_pan(cam, Cdouble(-(leftpx - datl) * wppx), Cdouble(-(botpx - datb) * wppy), 0.0)
	F3D.f3d_window_render(window)

	# 2-D map frame (referenced images only): X bottom + Y left, outward ticks,
	# decimals chosen so labels are unique. Needs the f3d_ext DLL.
	if isgeo && _has_f3d_ext()
		dx = decimals === nothing ? _axis_decimals(x1 - x0) :
			 (decimals isa Tuple ? Int(decimals[1]) : Int(decimals))
		dy = decimals === nothing ? _axis_decimals(y1 - y0) :
			 (decimals isa Tuple ? Int(decimals[2]) : Int(decimals))
		F3D.f3d_ext_enable_image_axes(window, "%.$(dx)f", "%.$(dy)f")
		F3D.f3d_window_render(window)
	end

	# Line overlays on the flat image (coastlines, tracks). The image lies at z = 0
	# and the view is top-down, so zfac = 1 (z column, if any, is honoured but unseen).
	_draw_lines(window, lines, line_color, line_width, 1.0)

	if !isempty(savepng)
		img = F3D.f3d_window_render_to_image(window, Cint(0))
		F3D.f3d_image_save(img, savepng, savefmt);  F3D.f3d_image_delete(img)
		println("saved ", savepng)
	end

	if offscreen
		rm(tex_path; force=true)
		F3D.f3d_engine_delete(engine)
		return nothing
	end

	interactor = F3D.f3d_engine_get_interactor(engine)
	F3D.f3d_interactor_init_commands(interactor)
	F3D.f3d_interactor_init_bindings(interactor)
	# Live coordinate readout under the cursor (referenced images only). Picks the
	# world point on the flat quad -> shows lon/lat. Interactor-only, so it is enabled
	# here (not on the offscreen path) after the interactor is initialised.
	isgeo && _has_f3d_ext() && F3D.f3d_ext_enable_coord_readout(window)
	_handle_chan === nothing || put!(_handle_chan, interactor)
	_interactor_start_gcsafe(interactor, 1.0 / 30.0)        # blocks until closed (GC-safe)
	F3D.f3d_interactor_stop(interactor)
	if isgeo && _has_f3d_ext()
		F3D.f3d_ext_disable_coord_readout(window)
		F3D.f3d_ext_disable_cube_axes(window)
	end
	lines === nothing || !_has_f3d_ext() || F3D.f3d_ext_clear_lines(window)
	rm(tex_path; force=true)
	F3D.f3d_scene_clear(scene)
	F3D.f3d_engine_delete(engine)
	return nothing
end

# `async=true` → viewer on a worker thread, REPL gets a `ViewHandle` (→ `close!`) immediately.
view_image(I::GMT.GMTimage; async::Bool=true, kwargs...) =
	(async && !get(kwargs, :offscreen, false)) ?
		_async_view(ch -> _view_image_impl(I; _handle_chan=ch, kwargs...)) : _view_image_impl(I; kwargs...)
# ---------------------------------------------------------------------------
# Point clouds: a GMTdataset (N x >=3 table) -> F3D point cloud, coloured by a
# data column (z depth by default) through a GMT colormap.
#
# F3D has no per-point scalar/colour array on the mesh struct, so colour goes the
# same route as faces: a 1 x ncolor palette texture + one u-texcoord per point
# (v=0.5) pointing at its colour's texel. The mesh is built with EMPTY sides /
# indices, which libf3d renders as a pure point cloud (vertices only); points are
# drawn as round sprites (`model.point_sprites`) sized by `pointsize`.
# ---------------------------------------------------------------------------

# Build a 1 x n RGB palette (flat UInt8, 3n) from a GMT colormap name.
function cmap_palette(cmap, n::Int; categorical::Bool=false)
	C  = categorical ? GMT.makecpt(cmap=string(cmap), range=(1, n, 1), categorical=true) :
					   GMT.makecpt(cmap=string(cmap), range=(0.0, 1.0, 1.0 / n))
	cm = C.colormap
	s  = maximum(cm) > 1.0 ? 1.0 : 255.0          # 0-1 vs 0-255 storage
	pal = Vector{UInt8}(undef, 3n)
	@inbounds for i in 1:n
		pal[3i-2] = round(UInt8, clamp(cm[i, 1] * s, 0, 255))
		pal[3i-1] = round(UInt8, clamp(cm[i, 2] * s, 0, 255))
		pal[3i]   = round(UInt8, clamp(cm[i, 3] * s, 0, 255))
	end
	return pal
end

# Rubber-band pick plumbing (needs an f3d built with c/f3d_ext_*.cxx; absent in the
# stock DLL). The C side calls back with the selected point ids; `_pick_trampoline`
# is the @cfunction target (a NAMED top-level fn, so @cfunction accepts it) and reads
# the active Julia callback. ids are 0-based VTK -> +1 for Julia rows.
#
# State lives in LAZILY-created module globals, NOT top-level `const`: a partial
# Revise / `includet` reload updates changed methods but refuses to re-create a
# `const`, so the new method body would reference an unbound name (the UndefVarError
# seen on window close). Creating the Refs on first use is reload-proof.
_pick_onpick() = (@isdefined(_PICK_ONPICK) || (global _PICK_ONPICK = Ref{Any}(nothing)); _PICK_ONPICK)
_pick_cbref()  = (@isdefined(_PICK_CBREF)  || (global _PICK_CBREF  = Ref{Any}(nothing)); _PICK_CBREF)
function _pick_trampoline(ids::Ptr{Csize_t}, n::Csize_t, ::Ptr{Cvoid})::Cvoid
	f = _pick_onpick()[]
	f === nothing && return nothing
	try
		sel = n == 0 ? Int[] : Int.(unsafe_wrap(Array, ids, Int(n))) .+ 1
		f(sel)
	catch e
		@warn "onpick callback threw" exception=(e, catch_backtrace())
	end
	return nothing
end

# True if the running libf3d carries the c/f3d_ext_*.cxx symbols (rebuilt DLL).
_has_f3d_ext() = Libdl.dlsym(Libdl.dlopen(F3D.libf3d), :f3d_ext_enable_cube_axes; throw_error=false) !== nothing
# gap #1: in-memory base-colour texture (no temp PNG). Same rebuilt DLL as f3d_ext.
_has_inmem_texture() = Libdl.dlsym(Libdl.dlopen(F3D.libf3d), :f3d_window_set_color_texture; throw_error=false) !== nothing

# Turn on the extended viewer interactions (all need a rebuilt f3d_ext DLL). Called
# AFTER the interactor exists and after the first render (cube axes needs bounds).
# Returns a zero-arg closure that disables them again (call before scene teardown).
# NOTE: rubber-band point picking is NOT wired here — it is point-cloud-only and
# lives in view_points (a frustum pick on a surface also grabs occluded points).
function _enable_extras(window, opts; cube_axes=false, coord_readout=false,
						vscale_drag=false, vscale_step=0.01, scale_handle=false, colorbar=nothing)
	# NOTE: middle-drag pan + middle-click "set rotation centre" are NATIVE in f3d
	# (vtkF3DInteractorStyle middle=StartPan; interactor_impl middle-click picks a point
	# and animates the camera to centre it) — no f3d_ext needed once f3d.dll is rebuilt.
	(cube_axes || coord_readout || vscale_drag || scale_handle || colorbar !== nothing) || return () -> nothing
	if !_has_f3d_ext()
		@warn "extended interactions ignored: this f3d build has no f3d_ext (rebuild per f3d_GIT/c/f3d_ext_REBUILD.md)"
		return () -> nothing
	end
	# The Fledermaus-style gizmo already maps Ctrl+left-drag to vertical scale, so it
	# supersedes the plain vscale_drag observer — never install both (double-apply).
	scale_handle && (vscale_drag = false)
	coord_readout && F3D.f3d_ext_enable_coord_readout(window)
	vscale_drag   && F3D.f3d_ext_enable_vertical_scale_drag(window, opts, Cdouble(vscale_step))
	cube_axes     && F3D.f3d_ext_enable_cube_axes(window)
	scale_handle  && F3D.f3d_ext_enable_scale_handle(window, opts, Cdouble(vscale_step))
	# Re-enable the colour bar as DRAGGABLE now that the interactor exists (the static one
	# put up on the offscreen/main path is idempotently swapped for a vtkScalarBarWidget,
	# and the 'b' key toggles it with f3d's own scalar bar). `colorbar` is a NamedTuple
	# (rgb, n, vmin, vmax[, title, fmt]) or nothing.
	colorbar !== nothing && F3D.f3d_ext_enable_colorbar(window, colorbar.rgb, colorbar.n,
		colorbar.vmin, colorbar.vmax, get(colorbar, :title, ""), get(colorbar, :fmt, "%.1f");
		draggable=true)
	return function ()
		colorbar !== nothing && F3D.f3d_ext_disable_colorbar(window)
		scale_handle  && F3D.f3d_ext_disable_scale_handle(window)
		cube_axes     && F3D.f3d_ext_disable_cube_axes(window)
		vscale_drag   && F3D.f3d_ext_disable_vertical_scale_drag(window)
		coord_readout && F3D.f3d_ext_disable_coord_readout(window)
	end
end

# Install the in-DLL rubber-band selector on `window`, routing picks to `onpick`. The
# gesture is Ctrl+right-drag (gated on Ctrl in the C side, like Ctrl+left-drag = vertical
# scale), so it is always available and never fires on a plain right-drag. Returns true
# if installed. No-op + warning when the running f3d lacks the f3d_ext symbols.
# Normalise a colour to an (r,g,b) tuple of Float64 in [0,1]. Accepts a 3-tuple/vector
# already in [0,1], or anything `_rgb3` handles (name, gray number, "r/g/b", "#hex")
# which it returns as 0-255 bytes.
function _color01(c)
	if (c isa Tuple || c isa AbstractVector) && length(c) == 3 && all(x -> x isa Real, c)
		t = Float64.(Tuple(c))
		return maximum(t) <= 1 ? t : t ./ 255   # >1 anywhere => assume 0-255 input
	end
	t = _rgb3(c)                                 # 0-255 bytes
	return (t[1] / 255, t[2] / 255, t[3] / 255)
end

# ---------------------------------------------------------------------------
# Line overlays: draw polylines (coastlines, tracks, contours) ON TOP of a
# surface or image. libf3d's mesh API has no line cells, so this goes through the
# f3d_ext renderer hatch (`f3d_ext_add_lines`). Needs the f3d_ext DLL.
#
# `lines` input forms, each treated as one polyline:
#   - a Matrix: N x 2 (z = 0) or N x 3 (column 3 is z)
#   - a GMTdataset (its `.data` matrix; a multi-segment file is a Vector{GMTdataset})
#   - a Vector/Tuple of any of the above (several polylines / layers in one call)
# ---------------------------------------------------------------------------
_collect_polylines(x::AbstractMatrix) = [Matrix{Float64}(x)]
_collect_polylines(x::GMT.GMTdataset)  = [Matrix{Float64}(x.data)]
function _collect_polylines(x)          # Vector/Tuple of the above (recurses)
	out = Matrix{Float64}[]
	for el in x
		append!(out, _collect_polylines(el))
	end
	return out
end

# Pack polylines into the flat (points, sizes) buffers the C side wants. `zfac` scales
# the z column so a line lands on a surface drawn with the same vertical scale; a 2-col
# polyline has no z and lies on z = 0.
function _lines_to_arrays(lines, zfac::Real)
	polys = _collect_polylines(lines)
	pts   = Cdouble[]
	sizes = Cuint[]
	for P in polys
		n = size(P, 1)
		n < 2 && continue
		hasz = size(P, 2) >= 3
		push!(sizes, Cuint(n))
		for i in 1:n
			push!(pts, P[i, 1], P[i, 2], hasz ? P[i, 3] * zfac : 0.0)
		end
	end
	return pts, sizes, length(pts) ÷ 3, length(sizes)
end

# Resolve a line colour to (r,g,b) Float64 in [0,1]. Accepts a colour NAME (Symbol or
# String, e.g. :red / "darkgreen" / "#ff8800" / "255/128/0" — via `parse_gmt_color`),
# a grey number, or an (r,g,b) tuple/vector ([0,1] or 0-255). `nothing` => yellow.
function _line_rgb(color)
	color === nothing && return (1.0, 1.0, 0.0)
	if color isa Symbol || color isa AbstractString
		t = parse_gmt_color(string(color));  return (t[1] / 255, t[2] / 255, t[3] / 255)
	elseif color isa Real
		g = color <= 1 ? Float64(color) : color / 255;  return (g, g, g)
	end
	return _color01(color)                       # (r,g,b) tuple/vector
end

# Draw the `lines` overlay on `window` (no-op if none / no f3d_ext). `zfac` matches the
# surface's vertical scale; `line_color` is any `_line_rgb`-able colour (default yellow);
# `line_width` is in screen pixels. `overlay=1` keeps the lines from z-fighting the surface.
function _draw_lines(window, lines, line_color, line_width, zfac)
	(lines === nothing || !_has_f3d_ext()) && return
	pts, sizes, npts, nlines = _lines_to_arrays(lines, zfac)
	npts == 0 && return
	r, g, b = _line_rgb(line_color)
	F3D.f3d_ext_add_lines(window, pts, npts, sizes, nlines, Cdouble[r, g, b],
						   nothing, Float64(line_width), Cint(1))
	F3D.f3d_window_render(window)
end

function _arm_pick(window, onpick, pickcolor=(0.83, 0.83, 0.83))
	onpick === nothing && return false
	h = Libdl.dlopen(F3D.libf3d)
	sym = Libdl.dlsym(h, :f3d_ext_enable_rubber_band_pick; throw_error=false)
	if sym === nothing
		@warn "onpick ignored: this f3d build has no f3d_ext (rebuild f3d with c/f3d_ext_*.cxx)"
		return false
	end
	r, g, b = _color01(pickcolor)
	cb = @cfunction(_pick_trampoline, Cvoid, (Ptr{Csize_t}, Csize_t, Ptr{Cvoid}))
	ok = ccall(sym, Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cdouble, Cdouble, Cdouble),
			   window, cb, C_NULL, Cdouble(r), Cdouble(g), Cdouble(b))
	ok == 1 || return false
	_pick_onpick()[] = onpick           # what the trampoline calls
	_pick_cbref()[]  = cb               # keep the @cfunction alive (GC guard)
	return true
end

"""
	view_points(D; kwargs...)

Show a `GMTdataset` (an `N x >=3` table of `x y z [...]`) as a 3-D point cloud in
F3D, colouring each point by a data column through a GMT colormap. Blocks until
the window is closed (unless `offscreen`).

# Colour
- `color=:z`: which value drives the colour — `:z` (column 3, depth, the default),
  or a column index `Int` (`1`=x, `2`=y, ...), or a length-`N` vector of values.
  Continuous (ramp) colouring.
- `class=nothing`: nominal sibling of `color` — same source forms, but flags the
  values as discrete CLASSES (implies `categorical=true` and the qualitative
  `:categorical` cmap). Use for labels/IDs, not continuous data.
- `cmap=nothing`: GMT colormap name. `nothing` picks `:categorical` when classed,
  else `:turbo`.
- `categorical=false`: force discrete-class painting (one solid colour per value,
  no ramp, no colour bar). Set implicitly by `class`.
- `ncolor=256`: palette resolution (continuous) / becomes #classes (categorical).
- `clim=nothing`: `(lo, hi)` colour limits; `nothing` = data min/max.

# Points
- `pointsize=1`: point size in pixels (`1` = true single-pixel points).
- `sprites=false`: when `true`, draw round splats coloured by value (gap #9). The
  sprite mapper ignores texture coords, so per-point colour is baked on via
  `f3d_ext_color_point_sprites` — REQUIRES an f3d built with `c/f3d_ext_*.cxx`; on a
  stock DLL the splats render uniform grey (a warning is shown).
- `splat="sphere"`: sprite shape — `"sphere"` (shaded disc), `"circle"` (flat ring),
  or `"gaussian"` (soft, can look fuzzy/dark over a dark bg). Only with `sprites=true`.

# Vertical scale (same geog-aware logic as `view_grid`)
- `zscale=:auto`: `:auto` sets a sensible flat slab so x,y and z are never on the
  same raw scale — geographic data (`GMT.isgeog`) gets a true 1:1 metres→degrees
  scale times `vexag`; non-geographic uses the `vfrac` heuristic. A number
  overrides (e.g. `zscale=1` for raw 1:1). Colours always key off the true z.
- `vexag=:auto`: vertical exaggeration multiplier (geographic `:auto` only).
- `vfrac=0.2`: target relief height as a fraction of the xy span (non-geographic).
- `isgeog=nothing`: force geographic on/off; `nothing` = autodetect via `GMT.isgeog(D)`.

# View / export (as in `view_fv`)
- `title`, `size=(1200,1000)`, `bg=(0.1,0.1,0.15)`, `lights=()`.
- `async=true`: viewer on a worker thread → REPL gets a `ViewHandle` at once;
  `false` blocks until the window closes (and returns the selection).
- `axes=true`, `grid=true`: orientation gizmo / f3d floor grid.
- `azimuth=-40`, `elevation=25`: orbit / tilt the camera (degrees).
- `offscreen=false`, `savepng=""`: render without a window / save the frame
  (format from extension: png/jpg/tif/bmp).

# Extended interactions (need an f3d built with `c/f3d_ext_*.cxx`; a stock DLL warns
# and ignores them)
- `cube_axes=true`: labelled bounding-box (X/Y/Z tick) axes with coords (default on).
- `coord_readout=true`: live world X/Y/Z under the cursor (bottom-left).
- `vscale_drag=true`: Ctrl+left-drag to exaggerate / flatten the relief
  (`vscale_step=0.01` per pixel).
- `colorbar=true`: colour scale on the right edge (continuous colouring only — off
  for the categorical/class path).
- `up="+Z"`: scene up-direction (`"+Z"` lays z-up data flat).

# Interactive selection (rubber-band) — always on, Ctrl+right-drag
- **Ctrl+right-drag** a box to select points (Ctrl+Z undoes, re-dragging the same box
  deselects); plain right-drag stays normal navigation. The selected points are kept
  for you — read them back with `selection(h)` (async) or from the return value
  (`async=false`); both give a `GMTdataset` of the picked rows. No option, no callback.
  REQUIRES an f3d built with `c/f3d_ext_*.cxx`. Interactive only.
  E.g. `h = view_points(D); ... ; sel = selection(h)`.
- `onpick=nothing`: for full control, pass `f(rows::Vector{Int})` instead — called with
  the selected row indices into `D.data` on every change (replaces the default stash).
- `pickcolor=(0.83,0.83,0.83)`: overlay colour for the selected points (light grey by
  default, so it does not clash with the points' own colours). Accepts an RGB tuple in
  `[0,1]`, a 0-255 triplet, or a colour name/`"#hex"`/gray number (as in `fill`).

E.g. `view_points(D)`, `view_points(D; cmap=:roma)`, `view_points(D; vexag=10)`.
"""
# `async=true` → viewer on a worker thread, REPL gets a `ViewHandle` (→ `close!`) immediately.
function view_points(D::GMT.GMTdataset; async::Bool=true, onpick=nothing, kwargs...)
	# Ctrl+right-drag box-select is ALWAYS on (no option). By default the picked points
	# are stashed for you — read them back with `selection(h)` (async) or the return value
	# (`async=false`). A custom `onpick=f` overrides the default stash.
	selref = Ref{Any}(nothing)
	# Default sink runs on the viewer's WORKER thread, so it must NOT touch GMT (not
	# thread-safe -> hard process crash). Stash a plain matrix copy; `selection(h)` wraps
	# it in a GMTdataset on the main thread.
	cb = onpick !== nothing ? onpick :
		 (rows -> (selref[] = isempty(rows) ? nothing : D.data[rows, :]))
	if async && !get(kwargs, :offscreen, false)   # offscreen has no window -> nothing to hand back
		return _async_view(ch -> _view_points_impl(D; _handle_chan=ch, onpick=cb, kwargs...); sel=selref)
	else
		_view_points_impl(D; onpick=cb, kwargs...)
		return selref[]                            # sync: hand back the selection on close
	end
end

function _view_points_impl(D::GMT.GMTdataset; _handle_chan=nothing, color=:z, class=nothing, cmap=nothing, ncolor::Int=256,
					 clim=nothing, categorical::Bool=false, pointsize::Real=1, sprites::Bool=false,
					 splat::AbstractString="sphere", spritesize::Real=10.0,
					 zscale=:auto, vfrac=0.2, vexag=:auto, isgeog=nothing,
					 title::AbstractString="F3D — point cloud",
					 size::Tuple{Int,Int}=(1200, 1000), bg=(0.1, 0.1, 0.15), lights=(),
					 axes::Bool=true, grid::Bool=true, offscreen::Bool=false,
					 savepng::AbstractString="", azimuth::Real=-40.0, elevation::Real=25.0,
					 up="+Z", cube_axes::Bool=true, coord_readout::Bool=true,
					 vscale_drag::Bool=true, vscale_step::Real=0.01, scale_handle::Bool=true,
				 colorbar::Bool=true,
					 onpick=nothing, pickcolor=(0.83, 0.83, 0.83),
					 lines=nothing, line_color=nothing, line_width::Real=2.0, L=nothing)
	lines = L === nothing ? lines : L          # `L` = GMT-style short alias for `lines`
	A = D.data
	N = Base.size(A, 1)
	N == 0 && error("dataset has no points")
	Base.size(A, 2) >= 3 || error("dataset needs at least 3 columns (x y z); got $(Base.size(A,2))")

	# `class` is the nominal sibling of `color`: passing it picks the source AND implies
	# categorical painting with the qualitative `:categorical` cmap (user can still override
	# `cmap`). `color` stays the continuous path.
	src = class === nothing ? color : class
	class === nothing || (categorical = true)
	cmap === nothing && (cmap = categorical ? :categorical : :turbo)

	# source: a column index / :z, an N-vector, a one-column matrix, or a GMTdataset.
	# Keep a VIEW (no copy) — the continuous path promotes in its own arithmetic, the
	# categorical path only needs unique/lookup. `vec` on an Nx1 matrix is a reshape view.
	cv = src isa GMT.GMTdataset ? src.data : src
	cvals = cv isa AbstractVector ? cv :
			cv isa AbstractMatrix  ? (GMT.isvector(cv) ? vec(cv) :
									  error("`color`/`class` matrix/dataset must be a single column; got size $(Base.size(cv))")) :
			@view A[:, cv === :z ? 3 : Int(cv)]
	length(cvals) == N || error("`color`/`class` length $(length(cvals)) != $N points")
	cmin, cmax = clim === nothing ? extrema(cvals) : (float(clim[1]), float(clim[2]))
	span = cmax > cmin ? cmax - cmin : 1.0

	# Vertical scale — SAME geog-aware logic as view_grid/tri2fv (`_resolve_zscale`):
	# `:auto` makes a sensible flat slab (geog: 1:1 metres->degrees x `vexag`; else the
	# `vfrac` heuristic), so x,y and z are NEVER on the same raw scale. A number overrides.
	xmn, xmx = extrema(@view A[:, 1]);  ymn, ymx = extrema(@view A[:, 2])
	zmn, zmx = extrema(@view A[:, 3])
	geo = isgeog === nothing ? GMT.isgeog(D) : Bool(isgeog)
	s   = Float32(_resolve_zscale(zscale, xmx - xmn, ymx - ymn, zmx - zmn, vfrac, geo, vexag))

	pts = Vector{Float32}(undef, 3N)
	tc  = Vector{Float32}(undef, 2N)
	if categorical
		# Nominal classes (e.g. LIDAR ASPRS): one distinct colour per unique value, no
		# ramp. ncolor := #classes; each point's texel = its class index. GMT builds the
		# discrete palette (`makecpt ... categorical=true`); `cmap=:categorical` is a good default.
		u       = sort(unique(cvals))
		ncolor  = length(u)
		cls2idx = Dict(c => k for (k, c) in enumerate(u))
		@inbounds for i in 1:N
			pts[3i-2] = A[i, 1];  pts[3i-1] = A[i, 2];  pts[3i] = A[i, 3] * s
			k = cls2idx[cvals[i]]
			tc[2i-1] = Float32((k - 0.5) / ncolor)      # texel centre of this class
			tc[2i]   = 0.5f0
		end
		pal = cmap_palette(cmap, ncolor; categorical=true)
		println("  classes: ", join(string.(u), ", "))
	else
		@inbounds for i in 1:N
			pts[3i-2] = A[i, 1];  pts[3i-1] = A[i, 2];  pts[3i] = A[i, 3] * s
			t = clamp((cvals[i] - cmin) / span, 0.0, 1.0)
			tc[2i-1] = Float32(clamp((floor(t * ncolor) + 0.5) / ncolor, 0.0, 1.0))   # texel centre
			tc[2i]   = 0.5f0
		end
		pal = cmap_palette(cmap, ncolor)
	end

	# Coloured ROUND sprites (gap #9): vtkPointGaussianMapper ignores the palette
	# texture, so for sprites we bake a per-point RGB array (same palette index the
	# texcoord encodes) and hand it to f3d_ext_color_point_sprites after the first
	# render. `splat` ("sphere"/"circle"/"gaussian") picks the splat SHAPE.
	# Bake the RGB even when starting as a PLAIN point cloud (sprites=false): the sprite
	# actor exists (hidden) from the start, so seeding its colour now lets the C side cache
	# it — otherwise the first 'o' key (enable sprites) shows uncoloured grey splats because
	# f3d wipes the colour array before our re-assert observer ever sees it (see
	# f3d_ext_color_point_sprites / reassertSpriteColors).
	rgb = UInt8[]
	if _has_f3d_ext()
		rgb = Vector{UInt8}(undef, 3N)
		@inbounds for i in 1:N
			row = clamp(floor(Int, tc[2i-1] * ncolor) + 1, 1, ncolor)   # 1-based palette row
			o = 3 * (row - 1)
			rgb[3i-2] = pal[o+1];  rgb[3i-1] = pal[o+2];  rgb[3i] = pal[o+3]
		end
	end

	savefmt = F3D.PNG
	isempty(savepng) || ((savepng, savefmt) = _img_target(savepng))

	F3D.f3d_engine_autoload_plugins()
	engine = F3D.f3d_engine_create(Cint(offscreen ? 1 : 0))
	engine == C_NULL && error("failed to create F3D engine")
	scene  = F3D.f3d_engine_get_scene(engine)
	window = F3D.f3d_engine_get_window(engine)
	F3D.f3d_window_set_size(window, Cint(size[1]), Cint(size[2]))
	F3D.f3d_window_set_window_name(window, title)

	opts = F3D.f3d_engine_get_options(engine)
	# `up`: scene up-direction. set_as_string_representation (NOT set_as_string -> crashes
	# on the `direction` option type).
	up === nothing || F3D.f3d_options_set_as_string_representation(opts, "scene.up_direction", string(up))
	F3D.f3d_options_set_as_bool(opts, "ui.scalar_bar", Cint(0))
	axes && F3D.f3d_options_set_as_bool(opts, "ui.axis", Cint(1))
	if grid
		F3D.f3d_options_set_as_bool(opts, "render.grid.enable", Cint(1))
		F3D.f3d_options_set_as_bool(opts, "render.grid.absolute", Cint(0))  # bbox bottom = cube axes floor
	end
	bgc = Cdouble[bg[1], bg[2], bg[3]]
	F3D.f3d_options_set_as_double_vector(opts, "render.background.color", bgc, Csize_t(3))
	F3D.f3d_options_set_as_bool(opts, "model.point_sprites.enable", Cint(sprites ? 1 : 0))
	sprites && F3D.f3d_options_set_as_string(opts, "model.point_sprites.type", splat)
	F3D.f3d_options_set_as_double(opts, "render.point_size", Cdouble(pointsize))
	# Sprite splat size (the `o` key cycles the TYPE but not the size; f3d's default 10 is
	# oversized). Set it always so cycling to a sprite shape looks right; Shift+/- adjusts live.
	F3D.f3d_options_set_as_double(opts, "model.point_sprites.size", Cdouble(spritesize))

	# Colour palette. PREFER an in-memory texture (gap #1): no temp PNG, and it
	# survives f3d's per-render option re-push. The old path wrote a PNG, set
	# `model.color.texture`, then deleted the file — but ANY later re-render (e.g. the
	# Ctrl-drag vertical-scale changing render.model_scale) makes f3d re-read that path,
	# now gone -> "Texture file does not exist ..." spam + lost colour. The in-memory
	# image is re-applied every render with no file. Falls back to the PNG on a stock DLL.
	palette_path = ""
	if _has_inmem_texture()
		palimg = F3D.f3d_image_new_params(Cuint(ncolor), Cuint(1), Cuint(3), F3D.BYTE)
		GC.@preserve pal F3D.f3d_image_set_content(palimg, pointer(pal))
		F3D.f3d_window_set_color_texture(window, palimg)   # copies content into the renderer
		F3D.f3d_image_delete(palimg)
	else
		palette_path = write_palette_png(pal, ncolor)
		F3D.f3d_options_set_as_string(opts, "model.color.texture", palette_path)
	end

	GC.@preserve pts tc begin
		mesh = Ref(F3D.f3d_mesh_t(
			pointer(pts), Csize_t(length(pts)),
			C_NULL,       Csize_t(0),                  # no normals (point cloud)
			pointer(tc),  Csize_t(length(tc)),         # texcoords -> palette colour
			C_NULL,       Csize_t(0),                  # empty sides   -> point cloud
			C_NULL,       Csize_t(0),                  # empty indices -> point cloud
		))
		e = Ref{Cstring}(C_NULL)
		if F3D.f3d_mesh_is_valid(mesh, e) != 1
			msg = e[] == C_NULL ? "unknown" : unsafe_string(e[])
			e[] == C_NULL || F3D.f3d_utils_string_free(e[])
			F3D.f3d_engine_delete(engine)
			error("point-cloud mesh invalid: $msg")
		end
		e[] == C_NULL || F3D.f3d_utils_string_free(e[])
		F3D.f3d_scene_add_mesh(scene, mesh) == 1 || error("f3d_scene_add_mesh failed")
	end

	isempty(lights) || add_lights!(scene, lights)
	println(title, ": ", N, " points, ", ncolor, " colours")

	camera = F3D.f3d_window_get_camera(window)
	F3D.f3d_camera_reset_to_bounds(camera, 0.9)
	azimuth   == 0 || F3D.f3d_camera_azimuth(camera, Cdouble(azimuth))
	elevation == 0 || F3D.f3d_camera_elevation(camera, Cdouble(elevation))
	F3D.f3d_window_render(window)
	isempty(palette_path) || rm(palette_path; force=true)   # PNG fallback: drop after first read

	# Sprites ignore the palette texture -> push the per-point RGB onto the gaussian
	# mapper now that the sprite actor exists (after the first render). gap #9.
	if !isempty(rgb)
		GC.@preserve rgb begin
			ok = F3D.f3d_ext_color_point_sprites(window, pointer(rgb), N, 3)
			ok == 1 || @warn "f3d_ext_color_point_sprites did not apply (no sprite actor?)"
		end
		F3D.f3d_window_render(window)
	end

	# Labelled cube axes with coordinates in EVERY figure — incl. offscreen / savepng
	# exports (enabled here, before the frame grab, not only on the interactive path).
	if cube_axes && _has_f3d_ext()
		F3D.f3d_ext_enable_cube_axes(window)
		F3D.f3d_window_render(window)
	end

	# Colour scale keyed on the value range that drives the point colours. Skipped for
	# the categorical path (discrete classes, not a continuous ramp).
	if colorbar && !categorical && _has_f3d_ext()
		nd = _axis_decimals(cmax - cmin)
		F3D.f3d_ext_enable_colorbar(window, pal, ncolor, cmin, cmax, "", "%.$(nd)f")
		F3D.f3d_window_render(window)
	end

	# Line overlays drawn ON TOP of the cloud. `s` is the SAME vertical scale applied to
	# the points, so a line's z (data units) lands at the cloud's level. Needs f3d_ext.
	_draw_lines(window, lines, line_color, line_width, s)

	if !isempty(savepng)
		img = F3D.f3d_window_render_to_image(window, Cint(0))
		F3D.f3d_image_save(img, savepng, savefmt)
		F3D.f3d_image_delete(img)
		println("saved ", savepng)
	end

	if offscreen
		F3D.f3d_engine_delete(engine)
		return nothing
	end

	interactor = F3D.f3d_engine_get_interactor(engine)
	F3D.f3d_interactor_init_commands(interactor)
	F3D.f3d_interactor_init_bindings(interactor)
	# Extended interactions (need a rebuilt f3d_ext DLL): cube axes / coordinate
	# readout / vertical-scale drag. Enabled after the first render (cube axes needs
	# bounds). Point clouds are the right place for the rubber-band selector.
	# Hand the colour-bar palette to _enable_extras so it re-enables as a draggable widget
	# ('b' toggles it). Skipped on the categorical path (no continuous ramp), matching the
	# static bar above.
	cbar_nt = (colorbar && !categorical && _has_f3d_ext()) ?
		(rgb=pal, n=ncolor, vmin=cmin, vmax=cmax, fmt="%.$(_axis_decimals(cmax - cmin))f") : nothing
	disable_extras = _enable_extras(window, opts; cube_axes=cube_axes,   # re-assert (idempotent)
									coord_readout=coord_readout, vscale_drag=vscale_drag,
									vscale_step=vscale_step, scale_handle=scale_handle,
									colorbar=cbar_nt)
	# Shift+'+' / Shift+'-' grow / shrink the point sprites (the `o` key only cycles type;
	# plain '+'/'-' stay free for zoom).
	_has_f3d_ext() && F3D.f3d_ext_enable_sprite_size_keys(window, opts, Cdouble(spritesize))
	# Vertical scale distorts gaussian/sphere splats if applied as an actor transform; keep
	# the sprites at the model_scale z by baking coords instead (re-placed on the `o` toggle).
	_has_f3d_ext() && F3D.f3d_ext_enable_sprite_zscale_sync(window, opts)
	# `onpick` IS the rubber-band switch: pass it and the box-select is on; omit it and
	# there is no selector at all. Installed AFTER the interactor exists and active right
	# away -> right-drag a box selects; the C side calls back with the ids ->
	# _pick_trampoline -> onpick(rows). Ctrl+Z undoes / re-dragging the same box deselects.
	pick_on = _arm_pick(window, onpick, pickcolor)
	pick_on && println("  pick: Ctrl+right-drag a box to select (Ctrl+Z undo); selection(h) / return value gives the points")
	_handle_chan === nothing || put!(_handle_chan, interactor)   # async: let the REPL close! us
	_interactor_start_gcsafe(interactor, 1.0 / 30.0)    # blocks until window closed (GC-safe)
	F3D.f3d_interactor_stop(interactor)   # kill the event-loop timer -> no stray OnTimer AV on close
	pick_on && F3D.f3d_ext_disable_rubber_band_pick(window)
	_pick_onpick()[] = nothing;  _pick_cbref()[] = nothing
	_has_f3d_ext() && F3D.f3d_ext_disable_sprite_size_keys(window)
	_has_f3d_ext() && F3D.f3d_ext_disable_sprite_zscale_sync(window)
	disable_extras()
	colorbar && !categorical && _has_f3d_ext() && F3D.f3d_ext_disable_colorbar(window)
	lines === nothing || !_has_f3d_ext() || F3D.f3d_ext_clear_lines(window)
	F3D.f3d_scene_clear(scene)        # drop actors before GL teardown -> avoids close-time AV in engine_delete
	F3D.f3d_engine_delete(engine)
	return nothing
end

function main(name::AbstractString="torus"; color::Bool=true, lights=DEMO_LIGHTS, flat::Bool=false,
			  axes::Bool=true, grid::Bool=true, trihedron::Bool=false)
	builder=get(SOLIDS, lowercase(name), nothing)
	if builder === nothing
		error("unknown solid '$name'. Choose one of: $(join(sort(collect(keys(SOLIDS))), ", "))")
	end
	fv = builder()
	color && colorize_by_z!(fv)         # fill fv.color so the colour path is exercised
	view_fv(fv; title="F3D — GMT $name" * (flat ? " (flat)" : ""),
			lights=lights, flat=flat, axes=axes, grid=grid, trihedron=trihedron)
end

if !isempty(PROGRAM_FILE) && lowercase(abspath(PROGRAM_FILE)) == lowercase(@__FILE__)
	name = isempty(ARGS) ? "torus" : ARGS[1]
	flat = any(a -> lowercase(a) == "flat", ARGS)   # e.g. `julia gmt_solids.jl cube flat`
	tri  = any(a -> lowercase(a) in ("trihedron", "axes", "arrows"), ARGS)
	if lowercase(name) in ("grid", "peaks")         # demo the grid bridge: `julia gmt_solids.jl grid`
		view_grid(GMT.peaks(); flat=flat, trihedron=tri)
	elseif isfile(name)                             # a grid file: `julia gmt_solids.jl dem.grd`
		view_grid(name; flat=flat, trihedron=tri)
	else
		main(name; flat=flat, trihedron=tri)    # e.g. `julia gmt_solids.jl cube trihedron`
	end
end

# Colour comes from `fv.color` (GMT `-G` strings). Real GMT producers fill it —
# e.g. `flatfv(image, ...)` builds an FV from an RGB image, one `-G#rrggbb` per
# face, so `view_fv(flatfv("pic.png", shape=:circle))` is coloured for free.
# `colorize_by_z!` here is only a demo filler for the plain solids.
#
# Illumination: normals are computed in `fv_to_mesh`. Default `flat=false` gives
# smooth shading (averaged per-vertex normals, `compute_vertex_normals`);
# `flat=true` gives faceted shading (one Newell face normal per face, split
# verts). Lights are set via the `lights` keyword — e.g.
#   view_fv(fv; flat=true, lights=[(; type=:scene, direction=(-1,-1,-1), intensity=1.3)])
# With `lights=()` F3D falls back to its default headlight.
# CLI: `julia gmt_solids.jl cube flat`.
