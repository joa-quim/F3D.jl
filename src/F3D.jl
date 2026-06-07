module F3D


"""
	_get_asset_filter() -> (os, arch, ext)

Return a tuple describing the current platform for matching F3D release assets.
"""
function _get_asset_filter()
	if Sys.iswindows()
		Sys.ARCH === :x86_64 || error("Only x86_64 is supported on Windows")
		return ("Windows", "x86_64", ".zip")
	elseif Sys.isapple()
		if Sys.ARCH === :aarch64
			return ("macOS", "arm64", ".dmg")
		else
			return ("macOS", "x86_64", ".dmg")
		end
	elseif Sys.islinux()
		Sys.ARCH === :x86_64 || error("Only x86_64 is supported on Linux")
		return ("Linux", "x86_64", ".tar.gz")
	else
		error("Unsupported operating system")
	end
end

"""
	_github_api_fetch(api_url) -> String

Fetch a GitHub API URL and return the response body as a string.
"""
function _github_api_fetch(api_url)
	local body::String
	tmp = tempname()
	try
		run(`curl -sL -H "Accept: application/vnd.github.v3+json" -o $tmp $api_url`)
		body = read(tmp, String)
	catch e
		error("Failed to query GitHub API: $e")
	finally
		rm(tmp; force = true)
	end
	return body
end

"""
	_find_release_tag(version) -> String

Resolve a version string to a GitHub release tag.

- `"nightly"` → `"nightly"`
- `"3.4.1"` → `"v3.4.1"` (exact match, verified to exist)
- `"3.4"` → `"v3.4.1"` (latest matching v3.4.x release)
"""
function _find_release_tag(version::AbstractString)
	version == "nightly" && return "nightly"

	parts = split(version, '.')
	if length(parts) == 3
		# Exact version: verify it exists
		tag = "v$version"
		api_url = "https://api.github.com/repos/f3d-app/f3d/releases/tags/$tag"
		body = _github_api_fetch(api_url)
		if occursin("\"Not Found\"", body)
			error("Release $tag not found on GitHub")
		end
		return tag
	elseif length(parts) == 2
		# Partial version: find latest matching release
		@info "Searching for latest v$version.x release..."
		api_url = "https://api.github.com/repos/f3d-app/f3d/releases?per_page=100"
		body = _github_api_fetch(api_url)
		prefix = "v$version."
		best_tag = ""
		best_patch = -1
		for m in eachmatch(r"\"tag_name\"\s*:\s*\"(v[^\"]+)\"", body)
			tag = String(m.captures[1])
			if startswith(tag, prefix)
				# Extract patch number, skip pre-releases like RC
				rest = tag[length(prefix)+1:end]
				patch = tryparse(Int, rest)
				if patch !== nothing && patch > best_patch
					best_patch = patch
					best_tag = tag
				end
			end
		end
		if best_tag == ""
			error("No release found matching v$version.x")
		end
		@info "Found release: $best_tag"
		return best_tag
	else
		error("Invalid version format: \"$version\". Use \"3.4\" or \"3.4.1\" or \"nightly\".")
	end
end

"""
	_find_asset_url(version="nightly") -> String

Query the GitHub API for an F3D release and return the download URL
for the raytracing asset matching the current platform.

- `"nightly"` → latest nightly build
- `"3.4.1"` → exact version 3.4.1
- `"3.4"` → latest 3.4.x release
"""
function _find_asset_url(version::AbstractString="nightly")
	tag = _find_release_tag(version)
	api_url = "https://api.github.com/repos/f3d-app/f3d/releases/tags/$tag"
	@info "Querying GitHub API for F3D release '$tag'..."

	body = _github_api_fetch(api_url)

	os, arch, ext = _get_asset_filter()
	ext_escaped = replace(ext, "." => "\\.")

	# Match: browser_download_url pointing to an asset containing OS, arch, "raytracing", and the right extension
	# Nightly example: F3D-3.4.1-56-g30d63098-Windows-x86_64-raytracing.zip
	# Release example: F3D-3.4.1-Windows-x86_64-raytracing.zip
	pattern = Regex("\"browser_download_url\"\\s*:\\s*\"(https://[^\"]*$(os)[^\"]*$(arch)[^\"]*raytracing$(ext_escaped))\"")

	m = match(pattern, body)
	if m === nothing
		error("Could not find a matching F3D raytracing asset for $os-$arch ($ext) in release '$tag'")
	end
	url = String(m.captures[1])
	@info "Found asset URL: $url"
	return url
end

"""
	_lib_filename() -> String

Return the expected F3D C API library filename for the current OS.
"""
function _lib_filename()
	if Sys.iswindows()
		return "f3d_c_api.dll"
	elseif Sys.isapple()
		return "libf3d_c_api.dylib"
	elseif Sys.islinux()
		return "libf3d_c_api.so"
	else
		error("Unsupported operating system")
	end
end

"""
	_extract_archive!(archive, dest)

Extract `archive` into `dest` using platform-appropriate tools.
"""
function _extract_archive!(archive, dest)
	mkpath(dest)
	if Sys.iswindows()
		run(`powershell -NoProfile -Command "Expand-Archive -Path '$archive' -DestinationPath '$dest' -Force"`)
	elseif Sys.islinux()
		run(`tar -xzf $archive -C $dest`)
	elseif Sys.isapple()
		mount_output = read(`hdiutil attach $archive -nobrowse -readonly`, String)
		lines = filter(!isempty, split(mount_output, '\n'))
		mount_point = strip(split(lines[end], '\t')[end])
		try
			run(`cp -R $mount_point/. $dest/`)
		finally
			run(`hdiutil detach $mount_point -quiet`)
		end
		run(`xattr -cr $dest`)
	else
		error("Unsupported operating system for extraction")
	end
	return dest
end

"""
	_find_file(dir, name) -> String

Recursively search `dir` for a file named `name`. Returns the full path.
"""
function _find_file(dir, name)
	for (root, dirs, files) in walkdir(dir)
		for f in files
			if f == name
				return joinpath(root, f)
			end
		end
	end
	error("Could not find $name in $dir")
end

"""
	ensure_f3d() -> String

Ensures the F3D library is available under `src/lib/` inside this package.
Returns the directory containing the F3D C API library.

1. Check if library already exists in `src/lib/` → return early
2. Query GitHub API for the nightly asset URL
3. Download the archive
4. Extract it
5. Clean up the archive
6. Return the directory containing the library
"""
function ensure_f3d()
	base_dir = dirname(@__FILE__)
	lib_dir = joinpath(base_dir, "lib")

	lib_name = _lib_filename()

	# Check if the library already exists somewhere under lib_dir
	if isdir(lib_dir)
		try
			lib_path = _find_file(lib_dir, lib_name)
			lib_parent = dirname(lib_path)
			@info "F3D library already available at $lib_parent"
			return lib_parent
		catch
			@info "lib/ directory exists but library not found, re-downloading..."
			rm(lib_dir; recursive = true, force = true)
		end
	end

	url = _find_asset_url()

	archive_name = basename(url)
	mkpath(lib_dir)
	archive_path = joinpath(lib_dir, archive_name)

	@info "Downloading F3D from $url ..."
	try
		run(`curl -sL -o $archive_path $url`)
	catch e
		error("Failed to download F3D: $e")
	end
	@info "Download complete: $archive_path"

	@info "Extracting archive..."
	_extract_archive!(archive_path, lib_dir)

	rm(archive_path; force = true)
	@info "Archive removed."

	lib_path = _find_file(lib_dir, lib_name)
	lib_parent = dirname(lib_path)
	@info "F3D library ready at $lib_parent"
	return lib_parent
end

"""
	update(version="nightly")

Delete the current F3D library and download the specified version.

	F3D.update()          # latest nightly
	F3D.update("3.4")     # latest 3.4.x release
	F3D.update("3.4.0")   # exact version 3.4.0

Requires restarting Julia after updating for the new library to take effect.
"""
function update(version::AbstractString="nightly")
	base_dir = dirname(@__FILE__)
	lib_dir = joinpath(base_dir, "lib")
	if isdir(lib_dir)
		rm(lib_dir; recursive = true, force = true)
		@info "Removed existing F3D libraries."
	end
	url = _find_asset_url(version)

	archive_name = basename(url)
	mkpath(lib_dir)
	archive_path = joinpath(lib_dir, archive_name)

	@info "Downloading F3D from $url ..."
	try
		run(`curl -sL -o $archive_path $url`)
	catch e
		error("Failed to download F3D: $e")
	end
	@info "Download complete: $archive_path"

	@info "Extracting archive..."
	_extract_archive!(archive_path, lib_dir)

	rm(archive_path; force = true)
	@info "Archive removed."

	lib_name = _lib_filename()
	lib_path = _find_file(lib_dir, lib_name)
	lib_parent = dirname(lib_path)
	@info "F3D updated to '$version'. Restart Julia to use the new library."
	return lib_parent
end

#export ensure_f3d
const libf3d = joinpath(ensure_f3d(), _lib_filename())

include("libf3d.jl")

"""
	preload_raytracing()

Make the raytracing backend loadable. The raytracing build loads its accelerator
DLLs (`ospray_module_cpu`, `ispcrt_device_cpu`, the OpenVKL CPU device modules, …)
by *bare* name at runtime. They live next to `libf3d` in `bin/`, a directory the
Julia process does not have on its loader search path, so the loads fail with
"the specified module could not be found" and toggling raytracing (the `R` key)
crashes the process.

Opening each DLL once by its *absolute* path registers it under its base name, so
f3d/ospray's later bare-name `LoadLibrary` resolves to the already-resident module —
without mutating `PATH` or the global loader search order. Idempotent and safe to
call repeatedly; a no-op on non-Windows platforms (Linux/macOS resolve via RPATH).
Call once before raytracing can be triggered.

# Offscreen raytracing (works, fast)

Measured at 1200×900: plain GL ≈ 0.001 s, raytraced ≈ 0.06 s (1 spp) … 0.29 s (5 spp).

```julia
using F3D
F3D.preload_raytracing()                      # Windows: make ospray modules loadable
engine = F3D.f3d_engine_create(Cint(1))       # 1 = offscreen
window = F3D.f3d_engine_get_window(engine)
opts   = F3D.f3d_engine_get_options(engine)
# … set window size, add your mesh to the scene …
F3D.f3d_options_set_as_bool(opts, "render.raytracing.enable",  Cint(1))
F3D.f3d_options_set_as_int( opts, "render.raytracing.samples", Cint(5))   # samples/pixel
img = F3D.f3d_window_render_to_image(window, Cint(0))
F3D.f3d_image_save(img, "out.png", F3D.PNG)
```

NOTE: enabling raytracing in the *live* interactor (the `R` key) pins all CPU cores at
100 %, drops GPU to zero, and freezes the window (root cause not isolated); the
interactive viewers in the companion GMTF3D package strip the `R`/`Shift+R` binds for
that reason. The offscreen path above, with the identical options, is fast and clean.
See the GMTF3D docs (Raytracing page).
"""
const _RT_PRELOADED = Ref(false)
function preload_raytracing()
	(_RT_PRELOADED[] || !Sys.iswindows()) && return
	bin = dirname(libf3d)
	for name in ("ispcrt_device_cpu", "openvkl_module_cpu_device_4",
				 "openvkl_module_cpu_device_8", "openvkl_module_cpu_device_16",
				 "openvkl_module_cpu_device", "ospray_module_cpu", "ospray_module_denoiser")
		p = joinpath(bin, name * ".dll")
		# Win32 LoadLibraryExW by absolute path with LOAD_WITH_ALTERED_SEARCH_PATH (0x8):
		# the flag makes the DLL's *own* dependencies (rkcommon, tbb, openvkl, …) resolve
		# from its own directory (bin/), and the load registers the module under its base
		# name so ospray's later bare-name load resolves to it. ccall to kernel32 needs no
		# package dependency. (Plain LoadLibraryW omits the altered search path and fails
		# to find those sibling deps.)
		isfile(p) && ccall((:LoadLibraryExW, "kernel32"), stdcall, Ptr{Cvoid},
						   (Cwstring, Ptr{Cvoid}, UInt32), p, C_NULL, 0x00000008)
	end
	_RT_PRELOADED[] = true
	return
end

end # module F3D
