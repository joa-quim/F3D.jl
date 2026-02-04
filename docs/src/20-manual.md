# Manual

This manual covers the F3D.jl API organized by functional area. All functions are thin `ccall` wrappers around the F3D C API. Pointers returned by F3D functions are opaque handles -- you pass them to other F3D functions and must free them when documented.

## General Conventions

- Functions returning `Cint` as a success indicator use `1` for success, `0` for failure.
- Opaque handles (`Ptr{f3d_engine_t}`, `Ptr{f3d_window_t}`, etc.) are managed by the engine unless stated otherwise.
- Heap-allocated strings and structures must be freed with the corresponding `_free` / `_delete` function.
- All angle arguments are in **degrees**.
- 3D coordinates use arrays of 3 `Cdouble` values (`[x, y, z]`).

## Types and Data Structures

### Geometric Primitives

| Type | Description |
|:-----|:------------|
| `f3d_point3_t` | A 3D point, `NTuple{3, Cdouble}` |
| `f3d_vector3_t` | A 3D vector, `NTuple{3, Cdouble}` |
| `f3d_angle_deg_t` | An angle in degrees, `Cdouble` |

### Color

```julia
struct f3d_color_t
    data::NTuple{3, Cdouble}   # RGB, each component in [0, 1]
end
```

Access and modify components:

| Function | Description |
|:---------|:------------|
| `f3d_color_r(color)` | Get red component |
| `f3d_color_g(color)` | Get green component |
| `f3d_color_b(color)` | Get blue component |
| `f3d_color_set(color, r, g, b)` | Set all components |

### Direction

```julia
struct f3d_direction_t
    data::NTuple{3, Cdouble}
end
```

| Function | Description |
|:---------|:------------|
| `f3d_direction_x(dir)` | Get x component |
| `f3d_direction_y(dir)` | Get y component |
| `f3d_direction_z(dir)` | Get z component |
| `f3d_direction_set(dir, x, y, z)` | Set all components |

### Ratio

```julia
struct f3d_ratio_t
    value::Cdouble
end
```

### 2D Transform

```julia
struct f3d_transform2d_t
    data::NTuple{9, Cdouble}   # 3x3 matrix stored as 9 values
end
```

Create transforms with:
```julia
f3d_transform2d_create(transform, scale_x, scale_y, translate_x, translate_y, angle_deg)
```

### Colormap

```julia
struct f3d_colormap_t
    data::Ptr{Cdouble}
    count::Csize_t
end
```

Free with `f3d_colormap_free(colormap)`.

### Mesh

```julia
struct f3d_mesh_t
    points::Ptr{Cfloat}                    # Vertex positions (x,y,z triples)
    points_count::Csize_t                  # Number of floats (3 * num_vertices)
    normals::Ptr{Cfloat}                   # Vertex normals
    normals_count::Csize_t
    texture_coordinates::Ptr{Cfloat}       # UV coordinates
    texture_coordinates_count::Csize_t
    face_sides::Ptr{Cuint}                 # Number of vertices per face
    face_sides_count::Csize_t
    face_indices::Ptr{Cuint}               # Vertex indices for each face
    face_indices_count::Csize_t
end
```

Validate a mesh with:
```julia
f3d_mesh_is_valid(mesh, error_message)  # Returns 1 if valid
```
The error message string must be freed with `f3d_utils_string_free()`.

### Light State

```julia
@enum f3d_light_type_t begin
    F3D_LIGHT_TYPE_HEADLIGHT = 1
    F3D_LIGHT_TYPE_CAMERA_LIGHT = 2
    F3D_LIGHT_TYPE_SCENE_LIGHT = 3
end

struct f3d_light_state_t
    type::f3d_light_type_t
    position::f3d_point3_t
    color::f3d_color_t
    direction::f3d_vector3_t
    positional_light::Cint
    intensity::Cdouble
    switch_state::Cint
end
```

| Function | Description |
|:---------|:------------|
| `f3d_light_state_free(light_state)` | Free a light state |
| `f3d_light_state_equal(a, b)` | Compare two light states (returns 1 if equal) |

### Camera State

```julia
struct f3d_camera_state_t
    position::f3d_point3_t
    focal_point::f3d_point3_t
    view_up::f3d_vector3_t
    view_angle::f3d_angle_deg_t
end
```

### Backend and Module Info

```julia
struct f3d_backend_info_t
    name::Cstring        # Backend name ("GLX", "EGL", "WGL", etc.)
    available::Cint      # Non-zero if available
end

struct f3d_module_info_t
    name::Cstring
    available::Cint
end
```

### Library Info

```julia
struct f3d_lib_info_t
    version::Cstring
    version_full::Cstring
    build_date::Cstring
    build_system::Cstring
    compiler::Cstring
    modules::Ptr{f3d_module_info_t}
    vtk_version::Cstring
    copyrights::Ptr{Cstring}
    license::Cstring
end
```

### Reader Info

```julia
struct f3d_reader_info_t
    name::Cstring
    description::Cstring
    extensions::Ptr{Cstring}      # NULL-terminated array
    mime_types::Ptr{Cstring}      # NULL-terminated array
    plugin_name::Cstring
    has_scene_reader::Cint
    has_geometry_reader::Cint
end
```

---

## Engine

The engine is the central object that owns the window, scene, interactor, and options. You must create an engine before doing anything else.

### Creating Engines

| Function | Description |
|:---------|:------------|
| `f3d_engine_create(offscreen)` | Create engine with automatic window. Set `offscreen=1` to hide the window. |
| `f3d_engine_create_none()` | Create engine with no window |
| `f3d_engine_create_wgl(offscreen)` | Create engine with WGL window (Windows) |
| `f3d_engine_create_glx(offscreen)` | Create engine with GLX window (Linux) |
| `f3d_engine_create_egl()` | Create engine with offscreen EGL window |
| `f3d_engine_create_osmesa()` | Create engine with offscreen OSMesa window |
| `f3d_engine_create_external(get_proc_address)` | Create engine with external OpenGL context |
| `f3d_engine_create_external_wgl()` | External WGL context (Windows) |
| `f3d_engine_create_external_glx()` | External GLX context (Linux) |
| `f3d_engine_create_external_cocoa()` | External Cocoa context (macOS) |
| `f3d_engine_create_external_egl()` | External EGL context |
| `f3d_engine_create_external_osmesa()` | External OSMesa context |

All `create` functions return `Ptr{f3d_engine_t}` (or `NULL` on failure). **Every engine must be deleted** with:

```julia
f3d_engine_delete(engine)
```

### Engine Sub-objects

These handles are owned by the engine -- do **not** free them:

| Function | Returns |
|:---------|:--------|
| `f3d_engine_get_window(engine)` | `Ptr{f3d_window_t}` |
| `f3d_engine_get_scene(engine)` | `Ptr{f3d_scene_t}` |
| `f3d_engine_get_interactor(engine)` | `Ptr{f3d_interactor_t}` |
| `f3d_engine_get_options(engine)` | `Ptr{f3d_options_t}` |

### Engine Configuration

| Function | Description |
|:---------|:------------|
| `f3d_engine_set_cache_path(engine, path)` | Set cache directory (returns 1 on success) |
| `f3d_engine_set_options(engine, options)` | Copy options into the engine |

### Plugins

| Function | Description |
|:---------|:------------|
| `f3d_engine_load_plugin(path_or_name)` | Load a plugin (returns 1 on success) |
| `f3d_engine_autoload_plugins()` | Automatically load all static plugins |
| `f3d_engine_get_plugins_list(plugin_path)` | List plugins in a directory. Free result with `f3d_engine_free_string_array()`. |

### Reader Options

| Function | Description |
|:---------|:------------|
| `f3d_engine_get_all_reader_option_names()` | Get all reader option names. Free with `f3d_engine_free_string_array()`. |
| `f3d_engine_set_reader_option(name, value)` | Set a reader option (returns 1 on success) |

### Library Information

```julia
# Get library info
info = f3d_engine_get_lib_info()
# ... use info ...
f3d_engine_free_lib_info(info)

# Get reader info
count = Ref{Cint}(0)
readers = f3d_engine_get_readers_info(count)
# ... use readers[1..count[]] ...
f3d_engine_free_readers_info(readers)

# Get rendering backends
count = Ref{Cint}(0)
backends = f3d_engine_get_rendering_backend_list(count)
# ... use backends ...
f3d_engine_free_backend_list(backends)
```

---

## Options

Options control rendering behavior. Create a standalone options object, configure it, then apply it to the engine.

### Lifecycle

```julia
options = f3d_options_create()
# ... configure ...
f3d_engine_set_options(engine, options)
f3d_options_delete(options)
```

Or modify the engine's options directly:
```julia
options = f3d_engine_get_options(engine)   # Do NOT delete this -- owned by engine
f3d_options_set_as_bool(options, "render.grid.enable", 1)
```

### Setters

| Function | Description |
|:---------|:------------|
| `f3d_options_set_as_bool(options, name, value)` | Set boolean option |
| `f3d_options_set_as_int(options, name, value)` | Set integer option |
| `f3d_options_set_as_double(options, name, value)` | Set double option |
| `f3d_options_set_as_string(options, name, value)` | Set string option |
| `f3d_options_set_as_double_vector(options, name, values, count)` | Set double vector |
| `f3d_options_set_as_int_vector(options, name, values, count)` | Set integer vector |
| `f3d_options_set_as_string_representation(options, name, str)` | Set from string representation |

### Getters

| Function | Returns |
|:---------|:--------|
| `f3d_options_get_as_bool(options, name)` | `Cint` (0 or 1) |
| `f3d_options_get_as_int(options, name)` | `Cint` |
| `f3d_options_get_as_double(options, name)` | `Cdouble` |
| `f3d_options_get_as_string(options, name)` | `Cstring` -- free with `f3d_options_free_string()` |
| `f3d_options_get_as_string_representation(options, name)` | `Cstring` -- free with `f3d_options_free_string()` |
| `f3d_options_get_as_double_vector(options, name, values, count)` | Fills pre-allocated array |
| `f3d_options_get_as_int_vector(options, name, values, count)` | Fills pre-allocated array |

### Manipulation

| Function | Description |
|:---------|:------------|
| `f3d_options_toggle(options, name)` | Toggle a boolean option |
| `f3d_options_is_same(options, other, name)` | Compare option value between two objects (returns 1 if same) |
| `f3d_options_has_value(options, name)` | Check if option is set (returns 1 if set) |
| `f3d_options_copy(options, other, name)` | Copy option value from `other` to `options` |
| `f3d_options_reset(options, name)` | Reset to default |
| `f3d_options_remove_value(options, name)` | Remove value (optional options only) |
| `f3d_options_is_optional(options, name)` | Check if option is optional |
| `f3d_options_get_closest_option(options, option, closest, distance)` | Find closest matching option name (Levenshtein distance) |

### Querying Names

```julia
# Get all available option names
count = Ref{Csize_t}(0)
names = f3d_options_get_all_names(count)
# ... iterate names[1..count[]] ...
f3d_options_free_names(names, count[])

# Get names of options that have been set
names = f3d_options_get_names(options, count)
f3d_options_free_names(names, count[])
```

### Parsing and Formatting

These static functions parse/format individual option values:

| Function | Description |
|:---------|:------------|
| `f3d_options_parse_bool(str)` | Parse string to bool |
| `f3d_options_parse_int(str)` | Parse string to int |
| `f3d_options_parse_double(str)` | Parse string to double |
| `f3d_options_parse_string(str)` | Parse string (returns copy, free with `f3d_options_free_string()`) |
| `f3d_options_parse_double_vector(str, values, count)` | Parse string to double vector |
| `f3d_options_parse_int_vector(str, values, count)` | Parse string to int vector |
| `f3d_options_format_bool(value)` | Format bool to string (free result) |
| `f3d_options_format_int(value)` | Format int to string (free result) |
| `f3d_options_format_double(value)` | Format double to string (free result) |
| `f3d_options_format_string(value)` | Format string (returns copy, free result) |
| `f3d_options_format_double_vector(values, count)` | Format double vector to string (free result) |
| `f3d_options_format_int_vector(values, count)` | Format int vector to string (free result) |

All formatted strings must be freed with `f3d_options_free_string()`.

---

## Scene

The scene manages loaded 3D content, lights, and animations.

### Loading Content

| Function | Description |
|:---------|:------------|
| `f3d_scene_add(scene, file_path)` | Load a single file (returns 1 on success) |
| `f3d_scene_add_multiple(scene, file_paths, count)` | Load multiple files |
| `f3d_scene_add_mesh(scene, mesh)` | Load a programmatic mesh |
| `f3d_scene_add_buffer(scene, buffer, size)` | Load from a memory buffer |
| `f3d_scene_clear(scene)` | Remove all loaded content |
| `f3d_scene_supports(scene, file_path)` | Check if a file format is supported (returns 1 if yes) |

#### Example: Loading a File

```julia
scene = f3d_engine_get_scene(engine)
success = f3d_scene_add(scene, joinpath(pkgdir(F3D), "test", "data", "cow.vtp"))
```

### Lights

| Function | Description |
|:---------|:------------|
| `f3d_scene_add_light(scene, light_state)` | Add a light, returns its index |
| `f3d_scene_get_light_count(scene)` | Get number of lights |
| `f3d_scene_get_light(scene, index)` | Get light state at index (free with `f3d_light_state_free()`) |
| `f3d_scene_update_light(scene, index, light_state)` | Update light at index |
| `f3d_scene_remove_light(scene, index)` | Remove light at index |
| `f3d_scene_remove_all_lights(scene)` | Remove all lights |

### Animation

| Function | Description |
|:---------|:------------|
| `f3d_scene_load_animation_time(scene, time_value)` | Load scene at specified animation time |
| `f3d_scene_animation_time_range(scene, min_time, max_time)` | Get time range of animations |
| `f3d_scene_available_animations(scene)` | Get number of available animations |

---

## Window

The window handles rendering and display.

### Window Information

| Function | Description |
|:---------|:------------|
| `f3d_window_get_type(window)` | Get window type (`f3d_window_type_t` enum) |
| `f3d_window_is_offscreen(window)` | Check if offscreen (returns 1 if yes) |
| `f3d_window_get_width(window)` | Get width in pixels |
| `f3d_window_get_height(window)` | Get height in pixels |

### Window Types

```julia
@enum f3d_window_type_t begin
    F3D_WINDOW_NONE = 0
    F3D_WINDOW_EXTERNAL = 1
    F3D_WINDOW_GLX = 2
    F3D_WINDOW_WGL = 3
    F3D_WINDOW_COCOA = 4
    F3D_WINDOW_EGL = 5
    F3D_WINDOW_OSMESA = 6
    F3D_WINDOW_WASM = 7
    F3D_WINDOW_UNKNOWN = 8
end
```

### Window Configuration

| Function | Description |
|:---------|:------------|
| `f3d_window_set_size(window, width, height)` | Set window dimensions |
| `f3d_window_set_position(window, x, y)` | Set window position |
| `f3d_window_set_icon(window, icon, icon_size)` | Set window icon |
| `f3d_window_set_window_name(window, name)` | Set window title |

### Rendering

| Function | Description |
|:---------|:------------|
| `f3d_window_render(window)` | Render to screen (returns 1 on success) |
| `f3d_window_render_to_image(window, no_background)` | Render and return image. Set `no_background=1` for transparent background. **Free result with `f3d_image_delete()`**. |

### Coordinate Conversion

| Function | Description |
|:---------|:------------|
| `f3d_window_get_world_from_display(window, display_point, world_point)` | Convert display to world coordinates |
| `f3d_window_get_display_from_world(window, world_point, display_point)` | Convert world to display coordinates |

Both functions take `Ptr{Cdouble}` arrays of 3 elements.

### Camera Access

```julia
camera = f3d_window_get_camera(window)   # Owned by window, do NOT free
```

---

## Camera

The camera controls the viewpoint. Get it from the window with `f3d_window_get_camera()`.

### Position and Orientation

| Function | Description |
|:---------|:------------|
| `f3d_camera_set_position(camera, pos)` | Set camera position `[x,y,z]` |
| `f3d_camera_get_position(camera, pos)` | Get camera position |
| `f3d_camera_set_focal_point(camera, fp)` | Set focal point `[x,y,z]` |
| `f3d_camera_get_focal_point(camera, fp)` | Get focal point |
| `f3d_camera_set_view_up(camera, up)` | Set up vector `[x,y,z]` |
| `f3d_camera_get_view_up(camera, up)` | Get up vector |
| `f3d_camera_set_view_angle(camera, angle)` | Set view angle (degrees) |
| `f3d_camera_get_view_angle(camera)` | Get view angle (degrees) |

### Camera State

Save and restore the complete camera configuration:

```julia
f3d_camera_set_state(camera, state)   # Set full state
f3d_camera_get_state(camera, state)   # Get full state
```

### Movement

| Function | Description |
|:---------|:------------|
| `f3d_camera_dolly(camera, val)` | Divide distance from focal point by `val` |
| `f3d_camera_pan(camera, right, up, forward)` | Move along camera axes |
| `f3d_camera_zoom(camera, factor)` | Decrease view angle by `factor` |

### Rotation

| Function | Description |
|:---------|:------------|
| `f3d_camera_roll(camera, angle)` | Rotate about forward axis |
| `f3d_camera_azimuth(camera, angle)` | Rotate about vertical axis (centered at focal point) |
| `f3d_camera_yaw(camera, angle)` | Rotate about vertical axis (centered at camera position) |
| `f3d_camera_elevation(camera, angle)` | Rotate about horizontal axis (centered at focal point) |
| `f3d_camera_pitch(camera, angle)` | Rotate about horizontal axis (centered at camera position) |

All angles are in degrees.

### Defaults

| Function | Description |
|:---------|:------------|
| `f3d_camera_set_current_as_default(camera)` | Store current configuration as default |
| `f3d_camera_reset_to_default(camera)` | Reset to stored default |
| `f3d_camera_reset_to_bounds(camera, zoom_factor)` | Reset using scene bounds. `zoom_factor=1.0` aligns bounds to window edges; `0.9` is a common value for some margin. |

---

## Image

Image objects represent 2D pixel data. They can be created empty, from parameters, from files, or from rendering.

### Creating Images

| Function | Description |
|:---------|:------------|
| `f3d_image_new_empty()` | Create empty image |
| `f3d_image_new_params(width, height, channels, channel_type)` | Create with parameters |
| `f3d_image_new_path(path)` | Load from file |

All created images must be freed with `f3d_image_delete(img)`.

### Channel Types

```julia
@enum f3d_image_channel_type_t begin
    BYTE = 0
    SHORT = 1
    FLOAT = 2
end
```

### Save Formats

```julia
@enum f3d_image_save_format_t begin
    PNG = 0
    JPG = 1
    TIF = 2
    BMP = 3
end
```

### Image Properties

| Function | Returns |
|:---------|:--------|
| `f3d_image_get_width(img)` | Width in pixels |
| `f3d_image_get_height(img)` | Height in pixels |
| `f3d_image_get_channel_count(img)` | Number of channels |
| `f3d_image_get_channel_type(img)` | Channel type |
| `f3d_image_get_channel_type_size(img)` | Size of channel type in bytes |

### Pixel Access

```julia
# Get normalized pixel value (each channel in [0, 1])
pixel = zeros(Cdouble, 3)  # Allocate for channel count
f3d_image_get_normalized_pixel(img, x, y, pixel)
```

### Content Access

| Function | Description |
|:---------|:------------|
| `f3d_image_set_content(img, buffer)` | Set image content from buffer |
| `f3d_image_get_content(img)` | Get raw content pointer (owned by image, do not free) |

### Saving

```julia
# Save to file
f3d_image_save(img, "output.png", F3D.PNG)

# Save to buffer
size = Ref{Cuint}(0)
buf = f3d_image_save_buffer(img, F3D.PNG, size)
# ... use buf[1:size[]] ...
f3d_image_free_buffer(buf)
```

### Comparison

| Function | Description |
|:---------|:------------|
| `f3d_image_equals(img, reference)` | Test equality (returns non-zero if equal) |
| `f3d_image_not_equals(img, reference)` | Test inequality |
| `f3d_image_compare(img, reference)` | Compute SSIM difference |

### Terminal Output

| Function | Description |
|:---------|:------------|
| `f3d_image_to_terminal_text(img, stream)` | Write ANSI-colored text to file stream |
| `f3d_image_to_terminal_text_string(img)` | Get ANSI-colored text as string (internal storage, do not free) |

### Metadata

| Function | Description |
|:---------|:------------|
| `f3d_image_set_metadata(img, key, value)` | Set metadata |
| `f3d_image_get_metadata(img, key)` | Get metadata value (internal storage, do not free) |
| `f3d_image_all_metadata(img, count)` | Get all keys (free with `f3d_image_free_metadata_keys()`) |

### Supported Formats

```julia
count = f3d_image_get_supported_formats_count()
formats = f3d_image_get_supported_formats()   # Internal storage, do NOT free
```

---

## Interactor

The interactor handles user input events, key bindings, commands, and animations.

### Commands

Commands are named actions that can be triggered programmatically or via key bindings.

| Function | Description |
|:---------|:------------|
| `f3d_interactor_init_commands(interactor)` | Reset to default commands |
| `f3d_interactor_add_command(interactor, action, callback, user_data)` | Add a custom command |
| `f3d_interactor_remove_command(interactor, action)` | Remove a command |
| `f3d_interactor_get_command_actions(interactor, count)` | Get all actions. Free with `f3d_interactor_free_string_array()`. |
| `f3d_interactor_trigger_command(interactor, command, keep_comments)` | Trigger a command (returns 1 on success) |

### Key Bindings

Bindings connect key combinations to commands.

#### Interaction Bind Structure

```julia
@enum f3d_interaction_bind_modifier_keys_t begin
    F3D_INTERACTION_BIND_ANY = 128
    F3D_INTERACTION_BIND_NONE = 0
    F3D_INTERACTION_BIND_CTRL = 1
    F3D_INTERACTION_BIND_SHIFT = 2
    F3D_INTERACTION_BIND_CTRL_SHIFT = 3
end

struct f3d_interaction_bind_t
    mod::f3d_interaction_bind_modifier_keys_t
    inter::NTuple{256, Cchar}
end
```

| Function | Description |
|:---------|:------------|
| `f3d_interaction_bind_format(bind, output, output_size)` | Format bind to string (e.g., "Ctrl+A"). Buffer must be >= 512 bytes. |
| `f3d_interaction_bind_parse(str, bind)` | Parse string to bind |
| `f3d_interaction_bind_less_than(lhs, rhs)` | Compare for ordering |
| `f3d_interaction_bind_equals(lhs, rhs)` | Compare for equality |

#### Binding Management

| Function | Description |
|:---------|:------------|
| `f3d_interactor_init_bindings(interactor)` | Reset to default bindings |
| `f3d_interactor_add_binding(interactor, bind, commands, count, group)` | Add a binding |
| `f3d_interactor_remove_binding(interactor, bind)` | Remove a binding |
| `f3d_interactor_get_binds(interactor, count)` | Get all binds. Free with `f3d_interactor_free_bind_array()`. |
| `f3d_interactor_get_bind_groups(interactor, count)` | Get all groups. Free with `f3d_interactor_free_string_array()`. |
| `f3d_interactor_get_binds_for_group(interactor, group, count)` | Get binds in a group. Free with `f3d_interactor_free_bind_array()`. |
| `f3d_interactor_get_binding_documentation(interactor, bind, doc)` | Get documentation for a binding |
| `f3d_interactor_get_binding_type(interactor, bind)` | Get binding type |

#### Binding Types

```julia
@enum f3d_interactor_binding_type_t begin
    F3D_INTERACTOR_BINDING_CYCLIC = 0
    F3D_INTERACTOR_BINDING_NUMERICAL = 1
    F3D_INTERACTOR_BINDING_TOGGLE = 2
    F3D_INTERACTOR_BINDING_OTHER = 3
end
```

#### Binding Documentation

```julia
struct f3d_binding_documentation_t
    doc::NTuple{512, Cchar}
    value::NTuple{256, Cchar}
end
```

### Animation Control

| Function | Description |
|:---------|:------------|
| `f3d_interactor_toggle_animation(interactor, direction)` | Toggle animation |
| `f3d_interactor_start_animation(interactor, direction)` | Start animation |
| `f3d_interactor_stop_animation(interactor)` | Stop animation |
| `f3d_interactor_is_playing_animation(interactor)` | Check if playing (returns 1 if yes) |
| `f3d_interactor_get_animation_direction(interactor)` | Get current direction |

```julia
@enum f3d_interactor_animation_direction_t begin
    F3D_INTERACTOR_ANIMATION_FORWARD = 0
    F3D_INTERACTOR_ANIMATION_BACKWARD = 1
end
```

### Camera Movement

| Function | Description |
|:---------|:------------|
| `f3d_interactor_enable_camera_movement(interactor)` | Enable camera movement |
| `f3d_interactor_disable_camera_movement(interactor)` | Disable camera movement |

### Input Events

Forward input events to the interactor programmatically:

| Function | Description |
|:---------|:------------|
| `f3d_interactor_trigger_mod_update(interactor, mod)` | Update modifier key state |
| `f3d_interactor_trigger_mouse_button(interactor, action, button)` | Mouse button press/release |
| `f3d_interactor_trigger_mouse_position(interactor, xpos, ypos)` | Mouse move (pixel coordinates) |
| `f3d_interactor_trigger_mouse_wheel(interactor, direction)` | Mouse wheel |
| `f3d_interactor_trigger_keyboard_key(interactor, action, key_sym)` | Keyboard key press/release |
| `f3d_interactor_trigger_text_character(interactor, codepoint)` | Text character input (Unicode) |
| `f3d_interactor_trigger_event_loop(interactor, delta_time)` | Manually trigger event loop step |

#### Input Enums

```julia
@enum f3d_interactor_mouse_button_t begin
    F3D_INTERACTOR_MOUSE_LEFT = 0
    F3D_INTERACTOR_MOUSE_RIGHT = 1
    F3D_INTERACTOR_MOUSE_MIDDLE = 2
end

@enum f3d_interactor_wheel_direction_t begin
    F3D_INTERACTOR_WHEEL_FORWARD = 0
    F3D_INTERACTOR_WHEEL_BACKWARD = 1
    F3D_INTERACTOR_WHEEL_LEFT = 2
    F3D_INTERACTOR_WHEEL_RIGHT = 3
end

@enum f3d_interactor_input_action_t begin
    F3D_INTERACTOR_INPUT_PRESS = 0
    F3D_INTERACTOR_INPUT_RELEASE = 1
end

@enum f3d_interactor_input_modifier_t begin
    F3D_INTERACTOR_INPUT_NONE = 0
    F3D_INTERACTOR_INPUT_CTRL = 1
    F3D_INTERACTOR_INPUT_SHIFT = 2
    F3D_INTERACTOR_INPUT_CTRL_SHIFT = 3
end
```

### Event Loop

| Function | Description |
|:---------|:------------|
| `f3d_interactor_start(interactor, delta_time)` | Start event loop |
| `f3d_interactor_start_with_callback(interactor, delta_time, callback, user_data)` | Start with per-iteration callback |
| `f3d_interactor_stop(interactor)` | Stop event loop immediately |
| `f3d_interactor_request_render(interactor)` | Request render on next loop iteration |
| `f3d_interactor_request_stop(interactor)` | Request stop on next loop iteration |

### Interaction Recording

| Function | Description |
|:---------|:------------|
| `f3d_interactor_play_interaction(interactor, file_path, delta_time)` | Play a VTK interaction file (returns 1 on success) |
| `f3d_interactor_record_interaction(interactor, file_path)` | Record interaction to file (returns 1 on success) |

### Memory Management

| Function | Description |
|:---------|:------------|
| `f3d_interactor_free_string_array(array, count)` | Free string arrays from interactor functions |
| `f3d_interactor_free_bind_array(array)` | Free bind arrays from interactor functions |

---

## Context

Rendering contexts for OpenGL symbol resolution.

| Function | Description |
|:---------|:------------|
| `f3d_context_glx()` | Create GLX context (Linux) |
| `f3d_context_wgl()` | Create WGL context (Windows) |
| `f3d_context_cocoa()` | Create Cocoa context (macOS) |
| `f3d_context_egl()` | Create EGL context |
| `f3d_context_osmesa()` | Create OSMesa context |
| `f3d_context_get_symbol(lib, func)` | Create context from library/function name |
| `f3d_context_delete(ctx)` | Delete a context |

All created contexts must be deleted with `f3d_context_delete()`.

---

## Logging

Control F3D's logging output.

### Log Levels

```julia
@enum f3d_log_verbose_level_t begin
    F3D_LOG_DEBUG = 0
    F3D_LOG_INFO = 1
    F3D_LOG_WARN = 2
    F3D_LOG_ERROR = 3
    F3D_LOG_QUIET = 4
end
```

### Logging Functions

| Function | Description |
|:---------|:------------|
| `f3d_log_print(level, message)` | Log at specified level |
| `f3d_log_debug(message)` | Log debug message |
| `f3d_log_info(message)` | Log info message |
| `f3d_log_warn(message)` | Log warning message |
| `f3d_log_error(message)` | Log error message |

### Configuration

| Function | Description |
|:---------|:------------|
| `f3d_log_set_verbose_level(level, force_std_err)` | Set log level. If `force_std_err != 0`, all output goes to stderr. |
| `f3d_log_get_verbose_level()` | Get current log level |
| `f3d_log_set_use_coloring(use)` | Enable/disable ANSI coloring |
| `f3d_log_forward(callback)` | Set log forwarding callback (or `C_NULL` to disable) |

---

## Utilities

General utility functions.

| Function | Description |
|:---------|:------------|
| `f3d_utils_text_distance(str_a, str_b)` | Compute Levenshtein distance |
| `f3d_utils_tokenize(str, keep_comments, out_count)` | Tokenize string (bash-style). Free result with `f3d_utils_tokens_free()`. |
| `f3d_utils_tokens_free(tokens, count)` | Free tokenized result |
| `f3d_utils_collapse_path(path, base_directory)` | Normalize path (expand `~`, resolve `..`). Free result with `f3d_utils_string_free()`. |
| `f3d_utils_glob_to_regex(glob, path_separator)` | Convert glob to regex. Free result with `f3d_utils_string_free()`. |
| `f3d_utils_get_env(env)` | Get environment variable. Free result with `f3d_utils_string_free()`. |
| `f3d_utils_get_known_folder(known_folder)` | Get Windows known folder path. Free result with `f3d_utils_string_free()`. |
| `f3d_utils_string_free(str)` | Free strings returned by utility functions |
| `f3d_utils_get_dpi_scale()` | Get DPI scale (Windows only, returns 1.0 on other platforms) |

### Known Folders (Windows)

```julia
@enum f3d_utils_known_folder_t begin
    F3D_UTILS_KNOWN_FOLDER_ROAMINGAPPDATA = 0
    F3D_UTILS_KNOWN_FOLDER_LOCALAPPDATA = 1
    F3D_UTILS_KNOWN_FOLDER_PICTURES = 2
end
```

---

## Updating F3D

```julia
using F3D
F3D.update()          # latest nightly build
F3D.update("3.4")     # latest 3.4.x release (e.g. 3.4.1)
F3D.update("3.4.0")   # exact version 3.4.0
```

This deletes the cached binaries and re-downloads the specified version. Restart Julia after updating.

When a partial version like `"3.4"` is given, the latest patch release is selected automatically (skipping pre-releases like RC). The full version `"3.4.0"` downloads that exact release.
