module F3D

using Downloads

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
    _find_asset_url() -> String

Query the GitHub API for the F3D nightly release and return the download URL
for the raytracing asset matching the current platform.
"""
function _find_asset_url()
    api_url = "https://api.github.com/repos/f3d-app/f3d/releases/tags/nightly"
    @info "Querying GitHub API for F3D nightly release..."

    local body::String
    buf = IOBuffer()
    try
        Downloads.download(api_url, buf; headers = ["Accept" => "application/vnd.github.v3+json"])
        body = String(take!(buf))
    catch e
        error("Failed to query GitHub API: $e")
    end

    os, arch, ext = _get_asset_filter()
    ext_escaped = replace(ext, "." => "\\.")

    # Match: browser_download_url pointing to an asset containing OS, arch, "raytracing", and the right extension
    # Example filename: F3D-3.4.1-56-g30d63098-Windows-x86_64-raytracing.zip
    pattern = Regex("\"browser_download_url\"\\s*:\\s*\"(https://[^\"]*$(os)[^\"]*$(arch)[^\"]*raytracing$(ext_escaped))\"")

    m = match(pattern, body)
    if m === nothing
        error("Could not find a matching F3D nightly raytracing asset for $os-$arch ($ext)")
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
        Downloads.download(url, archive_path)
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
    update()

Delete the current F3D library and download the latest nightly build.
Call this manually when you want to update to a newer version:

    using F3D
    F3D.update()

Note: Requires restarting Julia after updating for the new library to take effect.
"""
function update()
    base_dir = dirname(@__FILE__)
    lib_dir = joinpath(base_dir, "lib")
    if isdir(lib_dir)
        rm(lib_dir; recursive = true, force = true)
        @info "Removed existing F3D libraries."
    end
    new_dir = ensure_f3d()
    @info "F3D updated successfully. Restart Julia to use the new library."
    return new_dir
end

#export ensure_f3d
const _f3d_bin_dir = ensure_f3d()

# Add bin directory to PATH so dependent DLLs/shared libs can be found
if Sys.iswindows()
    ENV["PATH"] = _f3d_bin_dir * ";" * get(ENV, "PATH", "")
elseif Sys.isapple()
    ENV["DYLD_LIBRARY_PATH"] = _f3d_bin_dir * ":" * get(ENV, "DYLD_LIBRARY_PATH", "")
else
    ENV["LD_LIBRARY_PATH"] = _f3d_bin_dir * ":" * get(ENV, "LD_LIBRARY_PATH", "")
end

const libf3d = joinpath(_f3d_bin_dir, _lib_filename())

include("libf3d.jl")

end # module F3D
