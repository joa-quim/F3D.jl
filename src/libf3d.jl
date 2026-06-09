"""Describe a 3D point."""
const f3d_point3_t = NTuple{3, Cdouble}

"""Describe a 3D vector."""
const f3d_vector3_t = NTuple{3, Cdouble}

"""Describe an angle in degrees."""
const f3d_angle_deg_t = Cdouble

"""
    f3d_ratio_t

Describe a ratio.
"""
struct f3d_ratio_t
    value::Cdouble
end

"""
    f3d_color_t

Describe a RGB color.
"""
struct f3d_color_t
    data::NTuple{3, Cdouble}
end

"""
    f3d_color_r(color)

Get the red component of a color.
"""
function f3d_color_r(color)
    ccall((:f3d_color_r, libf3d), Cdouble, (Ptr{f3d_color_t},), color)
end

"""
    f3d_color_g(color)

Get the green component of a color.
"""
function f3d_color_g(color)
    ccall((:f3d_color_g, libf3d), Cdouble, (Ptr{f3d_color_t},), color)
end

"""
    f3d_color_b(color)

Get the blue component of a color.
"""
function f3d_color_b(color)
    ccall((:f3d_color_b, libf3d), Cdouble, (Ptr{f3d_color_t},), color)
end

"""
    f3d_color_set(color, r, g, b)

Set color components.
"""
function f3d_color_set(color, r, g, b)
    ccall((:f3d_color_set, libf3d), Cvoid, (Ptr{f3d_color_t}, Cdouble, Cdouble, Cdouble), color, r, g, b)
end

"""
    f3d_direction_t

Describe a 3D direction.
"""
struct f3d_direction_t
    data::NTuple{3, Cdouble}
end

"""
    f3d_direction_x(dir)

Get the x component of a direction.
"""
function f3d_direction_x(dir)
    ccall((:f3d_direction_x, libf3d), Cdouble, (Ptr{f3d_direction_t},), dir)
end

"""
    f3d_direction_y(dir)

Get the y component of a direction.
"""
function f3d_direction_y(dir)
    ccall((:f3d_direction_y, libf3d), Cdouble, (Ptr{f3d_direction_t},), dir)
end

"""
    f3d_direction_z(dir)

Get the z component of a direction.
"""
function f3d_direction_z(dir)
    ccall((:f3d_direction_z, libf3d), Cdouble, (Ptr{f3d_direction_t},), dir)
end

"""
    f3d_direction_set(dir, x, y, z)

Set direction components.
"""
function f3d_direction_set(dir, x, y, z)
    ccall((:f3d_direction_set, libf3d), Cvoid, (Ptr{f3d_direction_t}, Cdouble, Cdouble, Cdouble), dir, x, y, z)
end

"""
    f3d_transform2d_t

Store a 3x3 transform matrix as a sequence of 9 double values.
"""
struct f3d_transform2d_t
    data::NTuple{9, Cdouble}
end

"""
    f3d_transform2d_create(transform, scale_x, scale_y, translate_x, translate_y, angle_deg)

Create a 2D transform from scale, translate and angle.

# Arguments
* `transform`: Transform structure to fill.
* `scale_x`: Scale factor in x.
* `scale_y`: Scale factor in y.
* `translate_x`: Translation in x.
* `translate_y`: Translation in y.
* `angle_deg`: Rotation angle in degrees.
"""
function f3d_transform2d_create(transform, scale_x, scale_y, translate_x, translate_y, angle_deg)
    ccall((:f3d_transform2d_create, libf3d), Cvoid, (Ptr{f3d_transform2d_t}, Cdouble, Cdouble, Cdouble, Cdouble, f3d_angle_deg_t), transform, scale_x, scale_y, translate_x, translate_y, angle_deg)
end

"""
    f3d_colormap_t

Describe a colormap.
"""
struct f3d_colormap_t
    data::Ptr{Cdouble}
    count::Csize_t
end

"""
    f3d_colormap_free(colormap)

Free a colormap structure.

# Arguments
* `colormap`: Colormap to free.
"""
function f3d_colormap_free(colormap)
    ccall((:f3d_colormap_free, libf3d), Cvoid, (Ptr{f3d_colormap_t},), colormap)
end

"""
    f3d_mesh_scalar_t

Describe a named scalar array used to color a mesh through a colormap.

`components` is the number of values per point/cell (1 for a scalar field).
`data_count` must be `components` times the number of points (point array) or
faces (cell array).
"""
struct f3d_mesh_scalar_t
    name::Cstring
    components::Cuint
    data::Ptr{Cfloat}
    data_count::Csize_t
end

"""
    f3d_mesh_color_t

Describe a named direct-color array used to color a mesh.

Values are unsigned chars in the [0, 255] range. `components` must be 3 (RGB) or
4 (RGBA). `data_count` must be `components` times the number of points (point
array) or faces (cell array).
"""
struct f3d_mesh_color_t
    name::Cstring
    components::Cuint
    data::Ptr{Cuchar}
    data_count::Csize_t
end

"""
    f3d_mesh_t

Describe a 3D surfacic mesh.
"""
struct f3d_mesh_t
    points::Ptr{Cfloat}
    points_count::Csize_t
    normals::Ptr{Cfloat}
    normals_count::Csize_t
    texture_coordinates::Ptr{Cfloat}
    texture_coordinates_count::Csize_t
    face_sides::Ptr{Cuint}
    face_sides_count::Csize_t
    face_indices::Ptr{Cuint}
    face_indices_count::Csize_t
    point_scalars::Ptr{f3d_mesh_scalar_t}
    point_scalars_count::Csize_t
    cell_scalars::Ptr{f3d_mesh_scalar_t}
    cell_scalars_count::Csize_t
    point_colors::Ptr{f3d_mesh_color_t}
    point_colors_count::Csize_t
    cell_colors::Ptr{f3d_mesh_color_t}
    cell_colors_count::Csize_t
end

# Back-compat constructor: callers that only supply geometry (points/normals/
# texcoords/sides/indices) get empty scalar/color arrays.
function f3d_mesh_t(points, points_count, normals, normals_count,
                    texture_coordinates, texture_coordinates_count,
                    face_sides, face_sides_count, face_indices, face_indices_count)
    return f3d_mesh_t(points, points_count, normals, normals_count,
        texture_coordinates, texture_coordinates_count,
        face_sides, face_sides_count, face_indices, face_indices_count,
        C_NULL, Csize_t(0), C_NULL, Csize_t(0),
        C_NULL, Csize_t(0), C_NULL, Csize_t(0))
end

"""
    f3d_mesh_data_type_t

Scalar data types for a zero-copy [`f3d_memory_view_t`](@ref). Order mirrors
`f3d::mesh_view::data_type`.
"""
@enum f3d_mesh_data_type_t::UInt32 begin
    F3D_MESH_DATA_U8 = 0
    F3D_MESH_DATA_I8
    F3D_MESH_DATA_U16
    F3D_MESH_DATA_I16
    F3D_MESH_DATA_U32
    F3D_MESH_DATA_I32
    F3D_MESH_DATA_U64
    F3D_MESH_DATA_I64
    F3D_MESH_DATA_F32
    F3D_MESH_DATA_F64
end

"""
    f3d_data_array_t

Zero-copy view of an existing array. `data` is NOT copied and must stay alive while the
mesh view is in the scene. `name` may be `C_NULL`. `components`/`stride` default to 1 when
left at 0; `stride` is counted in elements, not bytes.
"""
struct f3d_data_array_t
    name::Cstring
    type::f3d_mesh_data_type_t
    data::Ptr{Cvoid}
    components::Csize_t
    stride::Csize_t
    time_dependent::Cint
end
# Convenience: empty/unused array slot.
f3d_data_array_t() = f3d_data_array_t(Cstring(C_NULL), F3D_MESH_DATA_F32, C_NULL, Csize_t(0), Csize_t(0), Cint(0))

"""
    f3d_cell_array_t

Zero-copy view of a cell array. `offset_count` is cells+1 (leave 0 for "no cell"); the last
offset equals `index_count`. `offsets`/`indices` must use an integer type (I32/U32/I64/U64).
"""
struct f3d_cell_array_t
    offset_count::Csize_t
    offsets::f3d_data_array_t
    index_count::Csize_t
    indices::f3d_data_array_t
end
f3d_cell_array_t() = f3d_cell_array_t(Csize_t(0), f3d_data_array_t(), Csize_t(0), f3d_data_array_t())

"""
    f3d_memory_view_t

Zero-copy view of a whole mesh in memory (mirrors `f3d::mesh_view::memory_view_t`). Pass by
`Ref` to [`f3d_scene_add_mesh_view`](@ref). All referenced pointers must stay pinned while
the mesh is in the scene. `points` must have 3 components (F32/F64); `normals` (3) and
`texture_coordinates` (2) are optional (leave `.data` `C_NULL`).
"""
struct f3d_memory_view_t
    point_count::Csize_t
    points::f3d_data_array_t
    normals::f3d_data_array_t
    texture_coordinates::f3d_data_array_t
    vertices::f3d_cell_array_t
    lines::f3d_cell_array_t
    polygons::f3d_cell_array_t
    point_scalars::Ptr{f3d_data_array_t}
    point_scalars_count::Csize_t
    cell_scalars::Ptr{f3d_data_array_t}
    cell_scalars_count::Csize_t
    base_color_texture::Ptr{Cvoid}
    base_color_texture_width::Csize_t
    base_color_texture_height::Csize_t
    base_color_texture_components::Csize_t
    base_color_texture_emissive::Cint
    # Optional 4x4 GPU transform (row-major). An all-zero matrix means identity / no transform.
    transform_matrix::NTuple{16,Cdouble}
end

"""
    f3d_mesh_is_valid(mesh, error_message)

Check validity of a mesh.

The returned error message string is heap-allocated and must be freed with [`f3d_utils_string_free`](@ref)().

# Arguments
* `mesh`: Mesh to validate.
* `error_message`: Pointer to receive error message if invalid.
# Returns
1 if valid, 0 if invalid.
"""
function f3d_mesh_is_valid(mesh, error_message)
    ccall((:f3d_mesh_is_valid, libf3d), Cint, (Ptr{f3d_mesh_t}, Ptr{Cstring}), mesh, error_message)
end

"""
    f3d_light_type_t

Enumeration of light types.
"""
@enum f3d_light_type_t::UInt32 begin
    F3D_LIGHT_TYPE_HEADLIGHT = 1
    F3D_LIGHT_TYPE_CAMERA_LIGHT = 2
    F3D_LIGHT_TYPE_SCENE_LIGHT = 3
end

"""
    f3d_light_state_t

Structure describing the state of a light.
"""
struct f3d_light_state_t
    type::f3d_light_type_t
    position::f3d_point3_t
    color::f3d_color_t
    direction::f3d_vector3_t
    positional_light::Cint
    intensity::Cdouble
    switch_state::Cint
end

"""
    f3d_light_state_free(light_state)

Free a light state structure.

# Arguments
* `light_state`: Light state to free.
"""
function f3d_light_state_free(light_state)
    ccall((:f3d_light_state_free, libf3d), Cvoid, (Ptr{f3d_light_state_t},), light_state)
end

"""
    f3d_light_state_equal(a, b)

Compare two light states for equality.

# Arguments
* `a`: First light state.
* `b`: Second light state.
# Returns
1 if equal, 0 otherwise.
"""
function f3d_light_state_equal(a, b)
    ccall((:f3d_light_state_equal, libf3d), Cint, (Ptr{f3d_light_state_t}, Ptr{f3d_light_state_t}), a, b)
end

const f3d_camera_t = Cvoid

"""
    f3d_camera_state_t

Structure containing all information to configure a camera.
"""
struct f3d_camera_state_t
    position::f3d_point3_t
    focal_point::f3d_point3_t
    view_up::f3d_vector3_t
    view_angle::f3d_angle_deg_t
end

"""
    f3d_camera_set_position(camera, pos)

Set the position of the camera.

# Arguments
* `camera`: Camera handle.
* `pos`: Position array [x, y, z].
"""
function f3d_camera_set_position(camera, pos)
    ccall((:f3d_camera_set_position, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, pos)
end

"""
    f3d_camera_get_position(camera, pos)

Get the position of the camera.

# Arguments
* `camera`: Camera handle.
* `pos`: Output position array [x, y, z].
"""
function f3d_camera_get_position(camera, pos)
    ccall((:f3d_camera_get_position, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, pos)
end

"""
    f3d_camera_set_focal_point(camera, focal_point)

Set the focal point of the camera.

# Arguments
* `camera`: Camera handle.
* `focal_point`: Focal point array [x, y, z].
"""
function f3d_camera_set_focal_point(camera, focal_point)
    ccall((:f3d_camera_set_focal_point, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, focal_point)
end

"""
    f3d_camera_get_focal_point(camera, focal_point)

Get the focal point of the camera.

# Arguments
* `camera`: Camera handle.
* `focal_point`: Output focal point array [x, y, z].
"""
function f3d_camera_get_focal_point(camera, focal_point)
    ccall((:f3d_camera_get_focal_point, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, focal_point)
end

"""
    f3d_camera_set_view_up(camera, view_up)

Set the view up vector of the camera.

# Arguments
* `camera`: Camera handle.
* `view_up`: View up vector [x, y, z].
"""
function f3d_camera_set_view_up(camera, view_up)
    ccall((:f3d_camera_set_view_up, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, view_up)
end

"""
    f3d_camera_get_view_up(camera, view_up)

Get the view up vector of the camera.

# Arguments
* `camera`: Camera handle.
* `view_up`: Output view up vector [x, y, z].
"""
function f3d_camera_get_view_up(camera, view_up)
    ccall((:f3d_camera_get_view_up, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{Cdouble}), camera, view_up)
end

"""
    f3d_camera_set_view_angle(camera, angle)

Set the view angle in degrees of the camera.

# Arguments
* `camera`: Camera handle.
* `angle`: View angle in degrees.
"""
function f3d_camera_set_view_angle(camera, angle)
    ccall((:f3d_camera_set_view_angle, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_get_view_angle(camera)

Get the view angle in degrees of the camera.

# Arguments
* `camera`: Camera handle.
# Returns
View angle in degrees.
"""
function f3d_camera_get_view_angle(camera)
    ccall((:f3d_camera_get_view_angle, libf3d), f3d_angle_deg_t, (Ptr{f3d_camera_t},), camera)
end

"""
    f3d_camera_set_state(camera, state)

Set the complete state of the camera.

# Arguments
* `camera`: Camera handle.
* `state`: Camera state structure.
"""
function f3d_camera_set_state(camera, state)
    ccall((:f3d_camera_set_state, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{f3d_camera_state_t}), camera, state)
end

"""
    f3d_camera_get_state(camera, state)

Get the complete state of the camera.

# Arguments
* `camera`: Camera handle.
* `state`: Output camera state structure.
"""
function f3d_camera_get_state(camera, state)
    ccall((:f3d_camera_get_state, libf3d), Cvoid, (Ptr{f3d_camera_t}, Ptr{f3d_camera_state_t}), camera, state)
end

"""
    f3d_camera_dolly(camera, val)

Divide the camera's distance from the focal point by the given value.

# Arguments
* `camera`: Camera handle.
* `val`: Value to divide distance by.
"""
function f3d_camera_dolly(camera, val)
    ccall((:f3d_camera_dolly, libf3d), Cvoid, (Ptr{f3d_camera_t}, Cdouble), camera, val)
end

"""
    f3d_camera_pan(camera, right, up, forward)

Move the camera along its horizontal, vertical, and forward axes.

# Arguments
* `camera`: Camera handle.
* `right`: Movement along the right axis.
* `up`: Movement along the up axis.
* `forward`: Movement along the forward axis.
"""
function f3d_camera_pan(camera, right, up, forward)
    ccall((:f3d_camera_pan, libf3d), Cvoid, (Ptr{f3d_camera_t}, Cdouble, Cdouble, Cdouble), camera, right, up, forward)
end

"""
    f3d_camera_zoom(camera, factor)

Decrease the view angle (or the parallel scale in parallel mode) by the specified factor.

# Arguments
* `camera`: Camera handle.
* `factor`: Zoom factor.
"""
function f3d_camera_zoom(camera, factor)
    ccall((:f3d_camera_zoom, libf3d), Cvoid, (Ptr{f3d_camera_t}, Cdouble), camera, factor)
end

"""
    f3d_camera_roll(camera, angle)

Rotate the camera about its forward axis.

# Arguments
* `camera`: Camera handle.
* `angle`: Rotation angle in degrees.
"""
function f3d_camera_roll(camera, angle)
    ccall((:f3d_camera_roll, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_azimuth(camera, angle)

Rotate the camera about its vertical axis, centered at the focal point.

# Arguments
* `camera`: Camera handle.
* `angle`: Rotation angle in degrees.
"""
function f3d_camera_azimuth(camera, angle)
    ccall((:f3d_camera_azimuth, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_yaw(camera, angle)

Rotate the camera about its vertical axis, centered at the camera's position.

# Arguments
* `camera`: Camera handle.
* `angle`: Rotation angle in degrees.
"""
function f3d_camera_yaw(camera, angle)
    ccall((:f3d_camera_yaw, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_elevation(camera, angle)

Rotate the camera about its horizontal axis, centered at the focal point.

# Arguments
* `camera`: Camera handle.
* `angle`: Rotation angle in degrees.
"""
function f3d_camera_elevation(camera, angle)
    ccall((:f3d_camera_elevation, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_pitch(camera, angle)

Rotate the camera about its horizontal axis, centered at the camera's position.

# Arguments
* `camera`: Camera handle.
* `angle`: Rotation angle in degrees.
"""
function f3d_camera_pitch(camera, angle)
    ccall((:f3d_camera_pitch, libf3d), Cvoid, (Ptr{f3d_camera_t}, f3d_angle_deg_t), camera, angle)
end

"""
    f3d_camera_set_current_as_default(camera)

Store the current camera configuration as default.

# Arguments
* `camera`: Camera handle.
"""
function f3d_camera_set_current_as_default(camera)
    ccall((:f3d_camera_set_current_as_default, libf3d), Cvoid, (Ptr{f3d_camera_t},), camera)
end

"""
    f3d_camera_reset_to_default(camera)

Reset the camera to the stored default camera configuration.

# Arguments
* `camera`: Camera handle.
"""
function f3d_camera_reset_to_default(camera)
    ccall((:f3d_camera_reset_to_default, libf3d), Cvoid, (Ptr{f3d_camera_t},), camera)
end

"""
    f3d_camera_reset_to_bounds(camera, zoom_factor)

Reset the camera using the bounds of actors in the scene.

Provided zoom\\_factor will be used to position the camera. A value of 1 corresponds to the bounds roughly aligned to the edges of the window.

# Arguments
* `camera`: Camera handle.
* `zoom_factor`: Zoom factor (default: 0.9).
"""
function f3d_camera_reset_to_bounds(camera, zoom_factor)
    ccall((:f3d_camera_reset_to_bounds, libf3d), Cvoid, (Ptr{f3d_camera_t}, Cdouble), camera, zoom_factor)
end

# typedef void ( * ( * f3d_context_function_t ) ( const char * ) ) ( )
"""Function pointer type for OpenGL symbol resolution."""
const f3d_context_function_t = Ptr{Cvoid}

const f3d_context = Cvoid

"""Opaque handle to a context object."""
const f3d_context_t = f3d_context

# no prototype is found for this function at context_c_api.h:28:29, please use with caution
"""
    f3d_context_glx()

Create a GLX context.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Returns
Context handle.
"""
function f3d_context_glx()
    ccall((:f3d_context_glx, libf3d), Ptr{f3d_context_t}, ())
end

# no prototype is found for this function at context_c_api.h:37:29, please use with caution
"""
    f3d_context_wgl()

Create a WGL context.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Returns
Context handle.
"""
function f3d_context_wgl()
    ccall((:f3d_context_wgl, libf3d), Ptr{f3d_context_t}, ())
end

# no prototype is found for this function at context_c_api.h:46:29, please use with caution
"""
    f3d_context_cocoa()

Create a COCOA context.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Returns
Context handle.
"""
function f3d_context_cocoa()
    ccall((:f3d_context_cocoa, libf3d), Ptr{f3d_context_t}, ())
end

# no prototype is found for this function at context_c_api.h:55:29, please use with caution
"""
    f3d_context_egl()

Create an EGL context.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Returns
Context handle.
"""
function f3d_context_egl()
    ccall((:f3d_context_egl, libf3d), Ptr{f3d_context_t}, ())
end

# no prototype is found for this function at context_c_api.h:64:29, please use with caution
"""
    f3d_context_osmesa()

Create an OSMesa context.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Returns
Context handle.
"""
function f3d_context_osmesa()
    ccall((:f3d_context_osmesa, libf3d), Ptr{f3d_context_t}, ())
end

"""
    f3d_context_get_symbol(lib, func)

Create a context from a library name and function name.

The returned context must be deleted with [`f3d_context_delete`](@ref)().

# Arguments
* `lib`: Library name.
* `func`: Function name to resolve.
# Returns
Context handle.
"""
function f3d_context_get_symbol(lib, func)
    ccall((:f3d_context_get_symbol, libf3d), Ptr{f3d_context_t}, (Cstring, Cstring), lib, func)
end

"""
    f3d_context_delete(ctx)

Delete a context object.

# Arguments
* `ctx`: Context handle.
"""
function f3d_context_delete(ctx)
    ccall((:f3d_context_delete, libf3d), Cvoid, (Ptr{f3d_context_t},), ctx)
end

const f3d_interactor_t = Cvoid

"""
    f3d_interaction_bind_modifier_keys_t

Enumeration of supported modifier key combinations.
"""
@enum f3d_interaction_bind_modifier_keys_t::UInt32 begin
    F3D_INTERACTION_BIND_ANY = 128
    F3D_INTERACTION_BIND_NONE = 0
    F3D_INTERACTION_BIND_CTRL = 1
    F3D_INTERACTION_BIND_SHIFT = 2
    F3D_INTERACTION_BIND_CTRL_SHIFT = 3
end

"""
    f3d_interaction_bind_t

Structure representing an interaction binding.
"""
struct f3d_interaction_bind_t
    mod::f3d_interaction_bind_modifier_keys_t
    inter::NTuple{256, Cchar}
end

"""
    f3d_interaction_bind_format(bind, output, output_size)

Format an interaction bind into a string.

Formats the bind into a string like "A", "Any+Question", "Shift+L", etc. The output buffer must be at least 512 bytes.

# Arguments
* `bind`: Interaction bind to format.
* `output`: Output buffer to store the formatted string.
* `output_size`: Size of the output buffer.
"""
function f3d_interaction_bind_format(bind, output, output_size)
    ccall((:f3d_interaction_bind_format, libf3d), Cvoid, (Ptr{f3d_interaction_bind_t}, Cstring, Cint), bind, output, output_size)
end

"""
    f3d_interaction_bind_parse(str, bind)

Parse a string into an interaction bind.

Creates an interaction bind from a string like "A", "Ctrl+A", "Shift+B", etc.

# Arguments
* `str`: String to parse.
* `bind`: Output parameter for the parsed bind.
"""
function f3d_interaction_bind_parse(str, bind)
    ccall((:f3d_interaction_bind_parse, libf3d), Cvoid, (Cstring, Ptr{f3d_interaction_bind_t}), str, bind)
end

"""
    f3d_interaction_bind_less_than(lhs, rhs)

Compare two interaction binds for less-than ordering.

Compares modifier and interaction string for ordering. Useful for storing binds in sorted data structures.

# Arguments
* `lhs`: Left-hand side bind.
* `rhs`: Right-hand side bind.
# Returns
1 if lhs < rhs, 0 otherwise.
"""
function f3d_interaction_bind_less_than(lhs, rhs)
    ccall((:f3d_interaction_bind_less_than, libf3d), Cint, (Ptr{f3d_interaction_bind_t}, Ptr{f3d_interaction_bind_t}), lhs, rhs)
end

"""
    f3d_interaction_bind_equals(lhs, rhs)

Compare two interaction binds for equality.

Compares both modifier and interaction string for equality.

# Arguments
* `lhs`: Left-hand side bind.
* `rhs`: Right-hand side bind.
# Returns
1 if binds are equal, 0 otherwise.
"""
function f3d_interaction_bind_equals(lhs, rhs)
    ccall((:f3d_interaction_bind_equals, libf3d), Cint, (Ptr{f3d_interaction_bind_t}, Ptr{f3d_interaction_bind_t}), lhs, rhs)
end

"""
    f3d_interactor_binding_type_t

Enumeration of binding types.
"""
@enum f3d_interactor_binding_type_t::UInt32 begin
    F3D_INTERACTOR_BINDING_CYCLIC = 0
    F3D_INTERACTOR_BINDING_NUMERICAL = 1
    F3D_INTERACTOR_BINDING_TOGGLE = 2
    F3D_INTERACTOR_BINDING_OTHER = 3
end

"""
    f3d_interactor_mouse_button_t

Enumeration of supported mouse buttons.
"""
@enum f3d_interactor_mouse_button_t::UInt32 begin
    F3D_INTERACTOR_MOUSE_LEFT = 0
    F3D_INTERACTOR_MOUSE_RIGHT = 1
    F3D_INTERACTOR_MOUSE_MIDDLE = 2
end

"""
    f3d_interactor_wheel_direction_t

Enumeration of supported mouse wheel directions.
"""
@enum f3d_interactor_wheel_direction_t::UInt32 begin
    F3D_INTERACTOR_WHEEL_FORWARD = 0
    F3D_INTERACTOR_WHEEL_BACKWARD = 1
    F3D_INTERACTOR_WHEEL_LEFT = 2
    F3D_INTERACTOR_WHEEL_RIGHT = 3
end

"""
    f3d_interactor_input_action_t

Enumeration of supported input actions.
"""
@enum f3d_interactor_input_action_t::UInt32 begin
    F3D_INTERACTOR_INPUT_PRESS = 0
    F3D_INTERACTOR_INPUT_RELEASE = 1
end

"""
    f3d_interactor_input_modifier_t

Enumeration of supported input modifiers.
"""
@enum f3d_interactor_input_modifier_t::UInt32 begin
    F3D_INTERACTOR_INPUT_NONE = 0
    F3D_INTERACTOR_INPUT_CTRL = 1
    F3D_INTERACTOR_INPUT_SHIFT = 2
    F3D_INTERACTOR_INPUT_CTRL_SHIFT = 3
end

"""
    f3d_interactor_animation_direction_t

Enumeration of animation direction.
"""
@enum f3d_interactor_animation_direction_t::UInt32 begin
    F3D_INTERACTOR_ANIMATION_FORWARD = 0
    F3D_INTERACTOR_ANIMATION_BACKWARD = 1
end

"""
    f3d_interactor_init_commands(interactor)

@{

` Commands`

Initialize commands (remove existing and add defaults).

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_init_commands(interactor)
    ccall((:f3d_interactor_init_commands, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

# typedef void ( * f3d_interactor_command_callback_t ) ( const char * * args , int arg_count , void * user_data )
"""Callback signature for command execution."""
const f3d_interactor_command_callback_t = Ptr{Cvoid}

"""
    f3d_interactor_add_command(interactor, action, callback, user_data)

Add a command with the provided action.

# Arguments
* `interactor`: Interactor handle.
* `action`: Action string.
* `callback`: Command callback function.
* `user_data`: Optional user data passed to callback.
"""
function f3d_interactor_add_command(interactor, action, callback, user_data)
    ccall((:f3d_interactor_add_command, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cstring, f3d_interactor_command_callback_t, Ptr{Cvoid}), interactor, action, callback, user_data)
end

"""
    f3d_interactor_remove_command(interactor, action)

Remove a command for the provided action.

# Arguments
* `interactor`: Interactor handle.
* `action`: Action string.
"""
function f3d_interactor_remove_command(interactor, action)
    ccall((:f3d_interactor_remove_command, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cstring), interactor, action)
end

"""
    f3d_interactor_get_command_actions(interactor, count)

Get all command actions.

# Arguments
* `interactor`: Interactor handle.
* `count`: Output parameter for number of actions.
# Returns
Array of action strings. Caller must free the array with [`f3d_interactor_free_string_array`](@ref)().
"""
function f3d_interactor_get_command_actions(interactor, count)
    ccall((:f3d_interactor_get_command_actions, libf3d), Ptr{Cstring}, (Ptr{f3d_interactor_t}, Ptr{Cint}), interactor, count)
end

"""
    f3d_interactor_trigger_command(interactor, command, keep_comments)

Trigger a command.

# Arguments
* `interactor`: Interactor handle.
* `command`: Command string.
* `keep_comments`: If non-zero, comments with # are supported.
# Returns
1 if command succeeded, 0 otherwise.
"""
function f3d_interactor_trigger_command(interactor, command, keep_comments)
    ccall((:f3d_interactor_trigger_command, libf3d), Cint, (Ptr{f3d_interactor_t}, Cstring, Cint), interactor, command, keep_comments)
end

"""
    f3d_interactor_init_bindings(interactor)

@{

` Bindings`

Initialize bindings (remove existing and add defaults).

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_init_bindings(interactor)
    ccall((:f3d_interactor_init_bindings, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_add_binding(interactor, bind, commands, command_count, group)

Add a binding for the provided bind.

# Arguments
* `interactor`: Interactor handle.
* `bind`: Interaction bind.
* `commands`: Array of command strings.
* `command_count`: Number of commands.
* `group`: Optional group name (can be NULL).
"""
function f3d_interactor_add_binding(interactor, bind, commands, command_count, group)
    ccall((:f3d_interactor_add_binding, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Ptr{f3d_interaction_bind_t}, Ptr{Cstring}, Cint, Cstring), interactor, bind, commands, command_count, group)
end

"""
    f3d_interactor_remove_binding(interactor, bind)

Remove a binding for the provided bind.

# Arguments
* `interactor`: Interactor handle.
* `bind`: Interaction bind.
"""
function f3d_interactor_remove_binding(interactor, bind)
    ccall((:f3d_interactor_remove_binding, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Ptr{f3d_interaction_bind_t}), interactor, bind)
end

"""
    f3d_interactor_get_bind_groups(interactor, count)

Get all bind groups.

# Arguments
* `interactor`: Interactor handle.
* `count`: Output parameter for number of groups.
# Returns
Array of group strings. Caller must free the array with [`f3d_interactor_free_string_array`](@ref)().
"""
function f3d_interactor_get_bind_groups(interactor, count)
    ccall((:f3d_interactor_get_bind_groups, libf3d), Ptr{Cstring}, (Ptr{f3d_interactor_t}, Ptr{Cint}), interactor, count)
end

"""
    f3d_interactor_get_binds_for_group(interactor, group, count)

Get all binds for a specific group.

# Arguments
* `interactor`: Interactor handle.
* `group`: Group name.
* `count`: Output parameter for number of binds.
# Returns
Array of binds. Caller must free the array with [`f3d_interactor_free_bind_array`](@ref)().
"""
function f3d_interactor_get_binds_for_group(interactor, group, count)
    ccall((:f3d_interactor_get_binds_for_group, libf3d), Ptr{f3d_interaction_bind_t}, (Ptr{f3d_interactor_t}, Cstring, Ptr{Cint}), interactor, group, count)
end

"""
    f3d_interactor_get_binds(interactor, count)

Get all binds.

# Arguments
* `interactor`: Interactor handle.
* `count`: Output parameter for number of binds.
# Returns
Array of binds. Caller must free the array with [`f3d_interactor_free_bind_array`](@ref)().
"""
function f3d_interactor_get_binds(interactor, count)
    ccall((:f3d_interactor_get_binds, libf3d), Ptr{f3d_interaction_bind_t}, (Ptr{f3d_interactor_t}, Ptr{Cint}), interactor, count)
end

"""
    f3d_binding_documentation_t

Structure containing binding documentation.
"""
struct f3d_binding_documentation_t
    doc::NTuple{512, Cchar}
    value::NTuple{256, Cchar}
end

"""
    f3d_interactor_get_binding_documentation(interactor, bind, doc)

Get documentation for a binding.

# Arguments
* `interactor`: Interactor handle.
* `bind`: Interaction bind.
* `doc`: Output parameter for documentation.
"""
function f3d_interactor_get_binding_documentation(interactor, bind, doc)
    ccall((:f3d_interactor_get_binding_documentation, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Ptr{f3d_interaction_bind_t}, Ptr{f3d_binding_documentation_t}), interactor, bind, doc)
end

"""
    f3d_interactor_get_binding_type(interactor, bind)

Get the type of a binding.

# Arguments
* `interactor`: Interactor handle.
* `bind`: Interaction bind.
# Returns
Binding type.
"""
function f3d_interactor_get_binding_type(interactor, bind)
    ccall((:f3d_interactor_get_binding_type, libf3d), f3d_interactor_binding_type_t, (Ptr{f3d_interactor_t}, Ptr{f3d_interaction_bind_t}), interactor, bind)
end

"""
    f3d_interactor_toggle_animation(interactor, direction)

@{

` Animation`

Toggle the animation.

# Arguments
* `interactor`: Interactor handle.
* `direction`: Animation direction.
"""
function f3d_interactor_toggle_animation(interactor, direction)
    ccall((:f3d_interactor_toggle_animation, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_animation_direction_t), interactor, direction)
end

"""
    f3d_interactor_start_animation(interactor, direction)

Start the animation.

# Arguments
* `interactor`: Interactor handle.
* `direction`: Animation direction.
"""
function f3d_interactor_start_animation(interactor, direction)
    ccall((:f3d_interactor_start_animation, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_animation_direction_t), interactor, direction)
end

"""
    f3d_interactor_stop_animation(interactor)

Stop the animation.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_stop_animation(interactor)
    ccall((:f3d_interactor_stop_animation, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_is_playing_animation(interactor)

Check if animation is currently playing.

# Arguments
* `interactor`: Interactor handle.
# Returns
1 if animation is playing, 0 otherwise.
"""
function f3d_interactor_is_playing_animation(interactor)
    ccall((:f3d_interactor_is_playing_animation, libf3d), Cint, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_get_animation_direction(interactor)

Get the current animation direction.

# Arguments
* `interactor`: Interactor handle.
# Returns
Current animation direction.
"""
function f3d_interactor_get_animation_direction(interactor)
    ccall((:f3d_interactor_get_animation_direction, libf3d), f3d_interactor_animation_direction_t, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_enable_camera_movement(interactor)

@{

` Movement`

Enable camera movement.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_enable_camera_movement(interactor)
    ccall((:f3d_interactor_enable_camera_movement, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_disable_camera_movement(interactor)

Disable camera movement.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_disable_camera_movement(interactor)
    ccall((:f3d_interactor_disable_camera_movement, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_trigger_mod_update(interactor, mod)

@{

` Forwarding input events`

Trigger a modifier update.

# Arguments
* `interactor`: Interactor handle.
* `mod`: Input modifier.
"""
function f3d_interactor_trigger_mod_update(interactor, mod)
    ccall((:f3d_interactor_trigger_mod_update, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_input_modifier_t), interactor, mod)
end

"""
    f3d_interactor_trigger_mouse_button(interactor, action, button)

Trigger a mouse button event.

# Arguments
* `interactor`: Interactor handle.
* `action`: Input action (press or release).
* `button`: Mouse button.
"""
function f3d_interactor_trigger_mouse_button(interactor, action, button)
    ccall((:f3d_interactor_trigger_mouse_button, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_input_action_t, f3d_interactor_mouse_button_t), interactor, action, button)
end

"""
    f3d_interactor_trigger_mouse_position(interactor, xpos, ypos)

Trigger a mouse position event.

# Arguments
* `interactor`: Interactor handle.
* `xpos`: X position in window coordinates (pixels).
* `ypos`: Y position in window coordinates (pixels).
"""
function f3d_interactor_trigger_mouse_position(interactor, xpos, ypos)
    ccall((:f3d_interactor_trigger_mouse_position, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cdouble, Cdouble), interactor, xpos, ypos)
end

"""
    f3d_interactor_trigger_mouse_wheel(interactor, direction)

Trigger a mouse wheel event.

# Arguments
* `interactor`: Interactor handle.
* `direction`: Wheel direction.
"""
function f3d_interactor_trigger_mouse_wheel(interactor, direction)
    ccall((:f3d_interactor_trigger_mouse_wheel, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_wheel_direction_t), interactor, direction)
end

"""
    f3d_interactor_trigger_keyboard_key(interactor, action, key_sym)

Trigger a keyboard key event.

# Arguments
* `interactor`: Interactor handle.
* `action`: Input action (press or release).
* `key_sym`: Key symbol string.
"""
function f3d_interactor_trigger_keyboard_key(interactor, action, key_sym)
    ccall((:f3d_interactor_trigger_keyboard_key, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_input_action_t, Cstring), interactor, action, key_sym)
end

"""
    f3d_interactor_trigger_text_character(interactor, codepoint)

Trigger a text character input event.

# Arguments
* `interactor`: Interactor handle.
* `codepoint`: Unicode codepoint of the character.
"""
function f3d_interactor_trigger_text_character(interactor, codepoint)
    ccall((:f3d_interactor_trigger_text_character, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cuint), interactor, codepoint)
end

"""
    f3d_interactor_trigger_event_loop(interactor, delta_time)

Manually trigger the event loop.

# Arguments
* `interactor`: Interactor handle.
* `delta_time`: Time step in seconds (must be positive).
"""
function f3d_interactor_trigger_event_loop(interactor, delta_time)
    ccall((:f3d_interactor_trigger_event_loop, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cdouble), interactor, delta_time)
end

"""
    f3d_interactor_play_interaction(interactor, file_path, delta_time)

Play a VTK interaction file.

# Arguments
* `interactor`: Interactor handle.
* `file_path`: Path to the interaction file.
* `delta_time`: Time step in seconds (default: 1.0/30).
# Returns
1 on success, 0 on failure.
"""
function f3d_interactor_play_interaction(interactor, file_path, delta_time)
    ccall((:f3d_interactor_play_interaction, libf3d), Cint, (Ptr{f3d_interactor_t}, Cstring, Cdouble), interactor, file_path, delta_time)
end

"""
    f3d_interactor_record_interaction(interactor, file_path)

Record interaction to a VTK interaction file.

# Arguments
* `interactor`: Interactor handle.
* `file_path`: Path to save the interaction file.
# Returns
1 on success, 0 on failure.
"""
function f3d_interactor_record_interaction(interactor, file_path)
    ccall((:f3d_interactor_record_interaction, libf3d), Cint, (Ptr{f3d_interactor_t}, Cstring), interactor, file_path)
end

"""
    f3d_interactor_start(interactor, delta_time)

Start the interactor event loop.

# Arguments
* `interactor`: Interactor handle.
* `delta_time`: Time step in seconds.
"""
function f3d_interactor_start(interactor, delta_time)
    ccall((:f3d_interactor_start, libf3d), Cvoid, (Ptr{f3d_interactor_t}, Cdouble), interactor, delta_time)
end

# typedef void ( * f3d_interactor_callback_t ) ( void * user_data )
const f3d_interactor_callback_t = Ptr{Cvoid}

"""
    f3d_interactor_set_event_loop_user_callback(interactor, callback, user_data)

Set the event loop user callback.

# Arguments
* `interactor`: Interactor handle.
* `callback`: Optional user callback called at the start of each event-loop iteration. May be NULL if no callback is desired.
* `user_data`: Optional opaque pointer passed verbatim to callback.
"""
function f3d_interactor_set_event_loop_user_callback(interactor, callback, user_data)
    ccall((:f3d_interactor_set_event_loop_user_callback, libf3d), Cvoid, (Ptr{f3d_interactor_t}, f3d_interactor_callback_t, Ptr{Cvoid}), interactor, callback, user_data)
end

"""
    f3d_interactor_stop(interactor)

Stop the interactor.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_stop(interactor)
    ccall((:f3d_interactor_stop, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_request_render(interactor)

Request a render on the next event loop.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_request_render(interactor)
    ccall((:f3d_interactor_request_render, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_request_stop(interactor)

Request the interactor to stop on the next event loop.

# Arguments
* `interactor`: Interactor handle.
"""
function f3d_interactor_request_stop(interactor)
    ccall((:f3d_interactor_request_stop, libf3d), Cvoid, (Ptr{f3d_interactor_t},), interactor)
end

"""
    f3d_interactor_free_string_array(array, count)

Free a string array returned by interactor functions.

# Arguments
* `array`: String array to free.
* `count`: Number of strings in the array.
"""
function f3d_interactor_free_string_array(array, count)
    ccall((:f3d_interactor_free_string_array, libf3d), Cvoid, (Ptr{Cstring}, Cint), array, count)
end

"""
    f3d_interactor_free_bind_array(array)

Free a bind array returned by interactor functions.

# Arguments
* `array`: Bind array to free.
"""
function f3d_interactor_free_bind_array(array)
    ccall((:f3d_interactor_free_bind_array, libf3d), Cvoid, (Ptr{f3d_interaction_bind_t},), array)
end

const f3d_scene_t = Cvoid

"""
    f3d_scene_add(scene, file_path)

Add and load a file into the scene.

# Arguments
* `scene`: Scene handle.
* `file_path`: File path to add.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_add(scene, file_path)
    ccall((:f3d_scene_add, libf3d), Cint, (Ptr{f3d_scene_t}, Cstring), scene, file_path)
end

"""
    f3d_scene_add_multiple(scene, file_paths, count)

Add and load multiple files into the scene.

# Arguments
* `scene`: Scene handle.
* `file_paths`: Array of file paths.
* `count`: Number of file paths in the array.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_add_multiple(scene, file_paths, count)
    ccall((:f3d_scene_add_multiple, libf3d), Cint, (Ptr{f3d_scene_t}, Ptr{Cstring}, Csize_t), scene, file_paths, count)
end

"""
    f3d_scene_add_mesh(scene, mesh)

Add and load a mesh into the scene.

# Arguments
* `scene`: Scene handle.
* `mesh`: Mesh structure.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_add_mesh(scene, mesh)
    ccall((:f3d_scene_add_mesh, libf3d), Cint, (Ptr{f3d_scene_t}, Ptr{f3d_mesh_t}), scene, mesh)
end

"""
    f3d_scene_add_mesh_view(scene, view, name, t_min, t_max)

Add a zero-copy in-memory mesh view into the scene.

Unlike [`f3d_scene_add_mesh`](@ref) (which copies all arrays into F3D), this keeps
references to the caller-owned arrays described by `view`: no data is copied. Every
pointer inside `view` (and the arrays it points at) MUST stay alive and pinned (e.g.
`GC.@preserve`) until the scene is cleared. The array metadata is copied internally, so
the `f3d_memory_view_t` value itself may be transient.

Animation: pass a non-degenerate `[t_min, t_max]` range and mutate the referenced buffers
in place between renders (keep the same pointers). Use `t_min == t_max` for a static mesh.

# Returns
1 on success, 0 on failure.
"""
function f3d_scene_add_mesh_view(scene, view, name, t_min, t_max)
    ccall((:f3d_scene_add_mesh_view, libf3d), Cint,
        (Ptr{f3d_scene_t}, Ptr{f3d_memory_view_t}, Cstring, Cdouble, Cdouble),
        scene, view, name, t_min, t_max)
end

"""
    f3d_scene_add_buffer(scene, buffer, size)

Add and load a memory buffer into the scene.

# Arguments
* `scene`: Scene handle.
* `buffer`: Memory buffer containing a file.
* `size`: Size of the buffer in bytes.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_add_buffer(scene, buffer, size)
    ccall((:f3d_scene_add_buffer, libf3d), Cint, (Ptr{f3d_scene_t}, Ptr{Cvoid}, Csize_t), scene, buffer, size)
end

"""
    f3d_scene_clear(scene)

Clear the scene of all added files.

# Arguments
* `scene`: Scene handle.
"""
function f3d_scene_clear(scene)
    ccall((:f3d_scene_clear, libf3d), Cvoid, (Ptr{f3d_scene_t},), scene)
end

"""
    f3d_scene_add_light(scene, light_state)

Add a light based on a light state.

# Arguments
* `scene`: Scene handle.
* `light_state`: Light state structure.
# Returns
Index of the added light.
"""
function f3d_scene_add_light(scene, light_state)
    ccall((:f3d_scene_add_light, libf3d), Cint, (Ptr{f3d_scene_t}, Ptr{f3d_light_state_t}), scene, light_state)
end

"""
    f3d_scene_get_light_count(scene)

Get the number of lights.

# Arguments
* `scene`: Scene handle.
# Returns
Number of lights in the scene.
"""
function f3d_scene_get_light_count(scene)
    ccall((:f3d_scene_get_light_count, libf3d), Cint, (Ptr{f3d_scene_t},), scene)
end

"""
    f3d_scene_get_light(scene, index)

Get the light state at provided index.

The returned light\\_state is heap-allocated and must be freed with [`f3d_light_state_free`](@ref)().

# Arguments
* `scene`: Scene handle.
* `index`: Index of the light.
# Returns
Light state, NULL on failure.
"""
function f3d_scene_get_light(scene, index)
    ccall((:f3d_scene_get_light, libf3d), Ptr{f3d_light_state_t}, (Ptr{f3d_scene_t}, Cint), scene, index)
end

"""
    f3d_scene_update_light(scene, index, light_state)

Update a light at provided index with the provided light state.

# Arguments
* `scene`: Scene handle.
* `index`: Index of the light to update.
* `light_state`: New light state.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_update_light(scene, index, light_state)
    ccall((:f3d_scene_update_light, libf3d), Cint, (Ptr{f3d_scene_t}, Cint, Ptr{f3d_light_state_t}), scene, index, light_state)
end

"""
    f3d_scene_remove_light(scene, index)

Remove a light at provided index.

# Arguments
* `scene`: Scene handle.
* `index`: Index of the light to remove.
# Returns
1 on success, 0 on failure.
"""
function f3d_scene_remove_light(scene, index)
    ccall((:f3d_scene_remove_light, libf3d), Cint, (Ptr{f3d_scene_t}, Cint), scene, index)
end

"""
    f3d_scene_remove_all_lights(scene)

Remove all lights from the scene.

# Arguments
* `scene`: Scene handle.
"""
function f3d_scene_remove_all_lights(scene)
    ccall((:f3d_scene_remove_all_lights, libf3d), Cvoid, (Ptr{f3d_scene_t},), scene)
end

"""
    f3d_scene_supports(scene, file_path)

Check if a file path is supported by the scene.

# Arguments
* `scene`: Scene handle.
* `file_path`: File path to check.
# Returns
1 if supported, 0 otherwise.
"""
function f3d_scene_supports(scene, file_path)
    ccall((:f3d_scene_supports, libf3d), Cint, (Ptr{f3d_scene_t}, Cstring), scene, file_path)
end

"""
    f3d_scene_load_animation_time(scene, time_value)

Load added files at provided time value if they contain any animation.

# Arguments
* `scene`: Scene handle.
* `time_value`: Time value to load.
"""
function f3d_scene_load_animation_time(scene, time_value)
    ccall((:f3d_scene_load_animation_time, libf3d), Cvoid, (Ptr{f3d_scene_t}, Cdouble), scene, time_value)
end

"""
    f3d_scene_animation_time_range(scene, min_time, max_time)

Get animation time range of currently added files.

# Arguments
* `scene`: Scene handle.
* `min_time`: Pointer to store minimum time.
* `max_time`: Pointer to store maximum time.
"""
function f3d_scene_animation_time_range(scene, min_time, max_time)
    ccall((:f3d_scene_animation_time_range, libf3d), Cvoid, (Ptr{f3d_scene_t}, Ptr{Cdouble}, Ptr{Cdouble}), scene, min_time, max_time)
end

"""
    f3d_scene_available_animations(scene)

Return the number of animations available in the currently loaded files.

# Arguments
* `scene`: Scene handle.
# Returns
Number of available animations.
"""
function f3d_scene_available_animations(scene)
    ccall((:f3d_scene_available_animations, libf3d), Cuint, (Ptr{f3d_scene_t},), scene)
end

@enum f3d_image_save_format_t::UInt32 begin
    PNG = 0
    JPG = 1
    TIF = 2
    BMP = 3
end

@enum f3d_image_channel_type_t::UInt32 begin
    BYTE = 0
    SHORT = 1
    FLOAT = 2
end

"""Opaque handle to an image object."""
const f3d_image = Cvoid

"""
` f3d_image_t`

Forward declaration of the [`f3d_image`](@ref) structure
"""
const f3d_image_t = f3d_image

# no prototype is found for this function at image_c_api.h:39:27, please use with caution
"""
    f3d_image_new_empty()

Create a new empty image object

The returned image must be deleted with [`f3d_image_delete`](@ref)().

# Returns
Pointer to the newly created image object
"""
function f3d_image_new_empty()
    ccall((:f3d_image_new_empty, libf3d), Ptr{f3d_image_t}, ())
end

"""
    f3d_image_new_params(width, height, channelCount, channelType)

Create a new image object with the given parameters

The returned image must be deleted with [`f3d_image_delete`](@ref)().

# Returns
Pointer to the newly created image object
"""
function f3d_image_new_params(width, height, channelCount, channelType)
    ccall((:f3d_image_new_params, libf3d), Ptr{f3d_image_t}, (Cuint, Cuint, Cuint, f3d_image_channel_type_t), width, height, channelCount, channelType)
end

"""
    f3d_image_new_path(path)

Create a new image object from a file path

The returned image must be deleted with [`f3d_image_delete`](@ref)().

# Returns
Pointer to the newly created image object
"""
function f3d_image_new_path(path)
    ccall((:f3d_image_new_path, libf3d), Ptr{f3d_image_t}, (Cstring,), path)
end

"""
    f3d_image_delete(img)

Delete an image object

# Arguments
* `img`: Pointer to the image object to be deleted
"""
function f3d_image_delete(img)
    ccall((:f3d_image_delete, libf3d), Cvoid, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_equals(img, reference)

Test if two images are equal

# Arguments
* `img`: Pointer to the first image object
* `reference`: Pointer to the second image object
# Returns
Non-zero if images are equal, zero otherwise
"""
function f3d_image_equals(img, reference)
    ccall((:f3d_image_equals, libf3d), Cint, (Ptr{f3d_image_t}, Ptr{f3d_image_t}), img, reference)
end

"""
    f3d_image_not_equals(img, reference)

Test if two images are not equal

# Arguments
* `img`: Pointer to the first image object
* `reference`: Pointer to the second image object
# Returns
Non-zero if images are not equal, zero otherwise
"""
function f3d_image_not_equals(img, reference)
    ccall((:f3d_image_not_equals, libf3d), Cint, (Ptr{f3d_image_t}, Ptr{f3d_image_t}), img, reference)
end

"""
    f3d_image_get_normalized_pixel(img, x, y, pixel)

Get the normalized pixel

# Arguments
* `img`: Pointer to the image object to be deleted
* `x`: horizontal pixel coordinate
* `y`: vertical pixel coordinate
* `pixel`: Pointer to a preallocated buffer of channel count size
"""
function f3d_image_get_normalized_pixel(img, x, y, pixel)
    ccall((:f3d_image_get_normalized_pixel, libf3d), Cvoid, (Ptr{f3d_image_t}, Cint, Cint, Ptr{Cdouble}), img, x, y, pixel)
end

# no prototype is found for this function at image_c_api.h:97:27, please use with caution
"""
    f3d_image_get_supported_formats_count()

Get the count of supported image formats

# Returns
Count of supported image formats
"""
function f3d_image_get_supported_formats_count()
    ccall((:f3d_image_get_supported_formats_count, libf3d), Cuint, ())
end

# no prototype is found for this function at image_c_api.h:107:27, please use with caution
"""
    f3d_image_get_supported_formats()

Get the list of supported image formats

The returned array points to internal static storage and must NOT be freed. The pointer is valid until the next call to this function.

# Returns
Pointer to the array of supported image formats
"""
function f3d_image_get_supported_formats()
    ccall((:f3d_image_get_supported_formats, libf3d), Ptr{Cstring}, ())
end

"""
    f3d_image_get_width(img)

Get the width of an image

# Arguments
* `img`: Pointer to the image object
# Returns
Width of the image
"""
function f3d_image_get_width(img)
    ccall((:f3d_image_get_width, libf3d), Cuint, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_get_height(img)

Get the height of an image

# Arguments
* `img`: Pointer to the image object
# Returns
Height of the image
"""
function f3d_image_get_height(img)
    ccall((:f3d_image_get_height, libf3d), Cuint, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_get_channel_count(img)

Get the number of channels in an image

# Arguments
* `img`: Pointer to the image object
# Returns
Number of channels in the image
"""
function f3d_image_get_channel_count(img)
    ccall((:f3d_image_get_channel_count, libf3d), Cuint, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_get_channel_type(img)

Get the type of channels in an image

# Arguments
* `img`: Pointer to the image object
# Returns
Type of channels in the image
"""
function f3d_image_get_channel_type(img)
    ccall((:f3d_image_get_channel_type, libf3d), Cuint, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_get_channel_type_size(img)

Get the size of the channel type in an image

# Arguments
* `img`: Pointer to the image object
# Returns
Size of the channel type in the image
"""
function f3d_image_get_channel_type_size(img)
    ccall((:f3d_image_get_channel_type_size, libf3d), Cuint, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_set_content(img, buffer)

Set the content of an image from a buffer

# Arguments
* `img`: Pointer to the image object
* `buffer`: Pointer to the buffer containing the image content
"""
function f3d_image_set_content(img, buffer)
    ccall((:f3d_image_set_content, libf3d), Cvoid, (Ptr{f3d_image_t}, Ptr{Cvoid}), img, buffer)
end

"""
    f3d_image_get_content(img)

Get the content of an image as a buffer

The returned pointer is owned by the image and must NOT be freed. It is valid as long as the image exists and its content is not modified.

# Arguments
* `img`: Pointer to the image object
# Returns
Pointer to the buffer containing the image content
"""
function f3d_image_get_content(img)
    ccall((:f3d_image_get_content, libf3d), Ptr{Cvoid}, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_compare(img, reference)

Compare two images

# Arguments
* `img`: Pointer to the image object
* `reference`: Pointer to the reference image object
# Returns
SSIM difference between the two images
"""
function f3d_image_compare(img, reference)
    ccall((:f3d_image_compare, libf3d), Cdouble, (Ptr{f3d_image_t}, Ptr{f3d_image_t}), img, reference)
end

"""
    f3d_image_save(img, path, format)

Save an image to a file

# Arguments
* `img`: Pointer to the image object
* `path`: Path to the file where the image will be saved
* `format`: Format in which the image will be saved
"""
function f3d_image_save(img, path, format)
    ccall((:f3d_image_save, libf3d), Cvoid, (Ptr{f3d_image_t}, Cstring, f3d_image_save_format_t), img, path, format)
end

"""
    f3d_image_save_buffer(img, format, size)

Save an image to a buffer

The returned buffer is heap-allocated and must be freed with [`f3d_image_free_buffer`](@ref)().

# Arguments
* `img`: Pointer to the image object
* `format`: Format in which the image will be saved
* `size`: Pointer to store the size of the saved buffer
# Returns
Pointer to the buffer containing the saved image
"""
function f3d_image_save_buffer(img, format, size)
    ccall((:f3d_image_save_buffer, libf3d), Ptr{Cuchar}, (Ptr{f3d_image_t}, f3d_image_save_format_t, Ptr{Cuint}), img, format, size)
end

"""
    f3d_image_free_buffer(buffer)

Free a buffer returned by [`f3d_image_save_buffer`](@ref)

# Arguments
* `buffer`: Pointer to the buffer to free
"""
function f3d_image_free_buffer(buffer)
    ccall((:f3d_image_free_buffer, libf3d), Cvoid, (Ptr{Cuchar},), buffer)
end

"""
    f3d_image_to_terminal_text(img, stream)

Convert an image to colored text using ANSI escape sequences for terminal output

Writes colored text to the provided file stream. This is the C equivalent of toTerminalText(std::ostream&).

# Arguments
* `img`: Pointer to the image object
* `stream`: File stream to write to (e.g., stdout, stderr, or file handle)
"""
function f3d_image_to_terminal_text(img, stream)
    ccall((:f3d_image_to_terminal_text, libf3d), Cvoid, (Ptr{f3d_image_t}, Ptr{Cvoid}), img, stream)
end

"""
    f3d_image_to_terminal_text_string(img)

Convert an image to a string representation for terminal output

The returned string points to internal static storage and must NOT be freed. The pointer is valid until the next call to this function. This is the C equivalent of toTerminalText() that returns a std::string.

# Arguments
* `img`: Pointer to the image object
# Returns
Pointer to the string representation of the image
"""
function f3d_image_to_terminal_text_string(img)
    ccall((:f3d_image_to_terminal_text_string, libf3d), Cstring, (Ptr{f3d_image_t},), img)
end

"""
    f3d_image_set_metadata(img, key, value)

Set metadata for an image

# Arguments
* `img`: Pointer to the image object
* `key`: Metadata key
* `value`: Metadata value
"""
function f3d_image_set_metadata(img, key, value)
    ccall((:f3d_image_set_metadata, libf3d), Cvoid, (Ptr{f3d_image_t}, Cstring, Cstring), img, key, value)
end

"""
    f3d_image_get_metadata(img, key)

Get metadata from an image

The returned string points to internal static storage and must NOT be freed. The pointer is valid until the next call to this function.

# Arguments
* `img`: Pointer to the image object
* `key`: Metadata key
# Returns
Metadata value
"""
function f3d_image_get_metadata(img, key)
    ccall((:f3d_image_get_metadata, libf3d), Cstring, (Ptr{f3d_image_t}, Cstring), img, key)
end

"""
    f3d_image_all_metadata(img, count)

Get all metadata keys from an image

The returned keys must be freed with [`f3d_image_free_metadata_keys`](@ref).

# Arguments
* `img`: Pointer to the image object
* `count`: Pointer to store the count of metadata keys
# Returns
Pointer to the array of metadata keys
"""
function f3d_image_all_metadata(img, count)
    ccall((:f3d_image_all_metadata, libf3d), Ptr{Cstring}, (Ptr{f3d_image_t}, Ptr{Cuint}), img, count)
end

"""
    f3d_image_free_metadata_keys(keys, count)

Free metadata keys obtained from an image

Used to free the return of [`f3d_image_all_metadata`](@ref).

# Arguments
* `keys`: Pointer to the array of metadata keys
* `count`: Count of metadata keys
"""
function f3d_image_free_metadata_keys(keys, count)
    ccall((:f3d_image_free_metadata_keys, libf3d), Cvoid, (Ptr{Cstring}, Cuint), keys, count)
end

const f3d_window_t = Cvoid

"""
    f3d_window_type_t

Enumeration of supported window types.
"""
@enum f3d_window_type_t::UInt32 begin
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

"""
    f3d_window_get_type(window)

Get the type of the window.

# Arguments
* `window`: Window handle.
# Returns
The window type.
"""
function f3d_window_get_type(window)
    ccall((:f3d_window_get_type, libf3d), f3d_window_type_t, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_is_offscreen(window)

Check if the window is offscreen.

# Arguments
* `window`: Window handle.
# Returns
1 if offscreen, 0 otherwise.
"""
function f3d_window_is_offscreen(window)
    ccall((:f3d_window_is_offscreen, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_get_camera(window)

Get the camera provided by the window.

# Arguments
* `window`: Window handle.
# Returns
Camera handle.
"""
function f3d_window_get_camera(window)
    ccall((:f3d_window_get_camera, libf3d), Ptr{f3d_camera_t}, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_render(window)

Perform a render of the window to the screen.

All dynamic options are updated if needed.

# Arguments
* `window`: Window handle.
# Returns
1 on success, 0 on failure.
"""
function f3d_window_render(window)
    ccall((:f3d_window_render, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_render_to_image(window, no_background)

Perform a render of the window to the screen and save the result in an image.

The image is of ChannelType BYTE and 3 or 4 components (RGB or RGBA). Set no\\_background to non-zero to have a transparent background. The caller must free the returned image with [`f3d_image_delete`](@ref)().

# Arguments
* `window`: Window handle.
* `no_background`: If non-zero, renders with a transparent background.
# Returns
Image handle containing the rendered result, or NULL on failure.
"""
function f3d_window_render_to_image(window, no_background)
    ccall((:f3d_window_render_to_image, libf3d), Ptr{f3d_image_t}, (Ptr{f3d_window_t}, Cint), window, no_background)
end

"""
    f3d_window_set_color_texture(window, image)

Set the model base color texture from an in-memory image, avoiding a temporary file on disk.

The image is expected to be of ChannelType BYTE with 3 (RGB) or 4 (RGBA) components. When set, it takes precedence over the `model.color.texture` file-path option. Pass an empty image (width or height 0) to clear the override and fall back to that option.

# Arguments
* `window`: Window handle.
* `image`: Image handle holding the texture, not freed by this call.
"""
function f3d_window_set_color_texture(window, image)
    ccall((:f3d_window_set_color_texture, libf3d), Cvoid, (Ptr{f3d_window_t}, Ptr{f3d_image_t}), window, image)
end

"""
    f3d_ext_enable_vertical_scale_drag(window, options, sensitivity)

Map Ctrl + left-button vertical drag to the model's Z scale (vertical exaggeration).
Drives the `render.model_scale` option, so pass the engine's options handle (from
[`f3d_engine_get_options`](@ref)).

This is an `f3d_ext` extension symbol: it only exists in an f3d built with the
`c/f3d_ext_*.cxx` sources (a stock DLL has no `f3d_ext` symbols, so calling this on
one errors). Pass `sensitivity <= 0` for the default (0.01 per pixel). Returns 1 on
success, 0 if the window has no interactor yet.
"""
function f3d_ext_enable_vertical_scale_drag(window, options, sensitivity)
    ccall((:f3d_ext_enable_vertical_scale_drag, libf3d), Cint, (Ptr{f3d_window_t}, Ptr{Cvoid}, Cdouble), window, options, sensitivity)
end

"""
    f3d_ext_disable_vertical_scale_drag(window)

Restore the interactor style that was active before
[`f3d_ext_enable_vertical_scale_drag`](@ref). Does not reset the model scale; set
`render.model_scale` back to `(1,1,1)` to undo the exaggeration. `f3d_ext` symbol.
"""
function f3d_ext_disable_vertical_scale_drag(window)
    ccall((:f3d_ext_disable_vertical_scale_drag, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_scale_handle(window, options, sensitivity)

Show a Fledermaus-style interaction gizmo pinned to the camera focal point (the
rotation centre). Three left-drag handles:

* the vertical arrowhead cone → vertical scale (`render.model_scale` z); the shaft
  keeps a fixed length while the cone stretches to show the current exaggeration.
  Ctrl + left-drag anywhere also still scales.
* the two horizontal arrows → tilt (camera elevation about the horizontal axis through
  the focal point).
* the compass ring band → azimuth (heading rotation about the world vertical;
  inclination unchanged).

The vertical axis is world-up (leans with the view inclination); the horizontal axis
follows the camera screen-right, so both axes stay aligned with the window instead of
spinning as the view orbits.

A billboard label on the axis shows the vertical exaggeration. Drives
`render.model_scale` through the option (so it survives f3d's per-render push) — pass
the engine's options handle (from [`f3d_engine_get_options`](@ref)). `f3d_ext` symbol.
Pass `sensitivity <= 0` for the default (0.01 per pixel). Call after the engine has an
interactor and a first render. Returns 1 on success, 0 if the window has no
interactor/renderer/camera yet.
"""
function f3d_ext_enable_scale_handle(window, options, sensitivity)
    ccall((:f3d_ext_enable_scale_handle, libf3d), Cint, (Ptr{f3d_window_t}, Ptr{Cvoid}, Cdouble), window, options, sensitivity)
end

"""
    f3d_ext_disable_scale_handle(window)

Remove the scale-handle gizmo (props + observers). Does not reset the model scale;
set `render.model_scale` back to `(1,1,1)` to undo. `f3d_ext` symbol.
"""
function f3d_ext_disable_scale_handle(window)
    ccall((:f3d_ext_disable_scale_handle, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_coord_readout(window)

Show a live readout of the world coordinate under the mouse cursor in a text box at
the bottom-left of the view, updated on every mouse move (blank when off geometry).

`f3d_ext` extension symbol — only present in an f3d built with `c/f3d_ext_*.cxx`.
Cannot be active at the same time as [`f3d_ext_enable_vertical_scale_drag`](@ref) on
the same window (both install an interactor style). Returns 1 on success, 0 if the
window has no interactor/renderer yet.
"""
function f3d_ext_enable_coord_readout(window)
    ccall((:f3d_ext_enable_coord_readout, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_disable_coord_readout(window)

Remove the coordinate-readout overlay and restore the prior interactor style.
`f3d_ext` symbol.
"""
function f3d_ext_disable_coord_readout(window)
    ccall((:f3d_ext_disable_coord_readout, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_focus_pick(window)

Middle-CLICK (press+release, no drag) picks the point under the cursor, sets it as the
camera focal point (rotation centre) and pans so it is centred. Middle-DRAG still pans.
`f3d_ext` symbol — `_has_f3d_ext()`-gated on the caller side.
"""
function f3d_ext_enable_focus_pick(window)
    ccall((:f3d_ext_enable_focus_pick, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_disable_focus_pick(window)

Remove the middle-click focal-centre observers. `f3d_ext` symbol.
"""
function f3d_ext_disable_focus_pick(window)
    ccall((:f3d_ext_disable_focus_pick, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

# Component flags for f3d_ext_enable_cube_axes (must match f3d_ext.h).
const F3D_EXT_CUBE_AXES_EDGES   = 0x01  # cube edges + X/Y tick labels
const F3D_EXT_CUBE_AXES_FLOOR   = 0x02  # bottom floor plane
const F3D_EXT_CUBE_AXES_GRID    = 0x04  # gridlines on all faces (walls)
const F3D_EXT_CUBE_AXES_ZLABELS = 0x08  # Z (elevation) tick labels
const F3D_EXT_CUBE_AXES_DEFAULT = F3D_EXT_CUBE_AXES_EDGES | F3D_EXT_CUBE_AXES_FLOOR | F3D_EXT_CUBE_AXES_ZLABELS

"""
    f3d_ext_enable_cube_axes(window; edges=true, floor=true, grid=false, zlabels=true)
    f3d_ext_enable_cube_axes(window, flags::Integer)

Add labelled bounding-box axes (numbered X/Y/Z tick axes) around the data — the
cube-axes the stock libf3d lacks (API gap #2). The default is the cube edges +
X/Y/Z tick labels + a semi-transparent bottom floor; the wall gridlines (`grid`)
are opt-in, and Z elevation labels (`zlabels`) can be turned off. The cube uses
the exact data bounds. Bounds are captured at call time; call again to refresh
after a geometry/scale change. `f3d_ext` symbol. Returns 1 on success, 0 if there
is no renderer/camera/data yet.

For a grid/terrain layout where X and Y both lie on the floor and Z is the
vertical (elevation) axis, set `scene.up_direction` to `+Z` (the f3d default `+Y`
stands the grid up as a wall). Use `f3d_options_set_as_string_representation`.
"""
function f3d_ext_enable_cube_axes(window; edges::Bool = true, floor::Bool = true,
                                  grid::Bool = false, zlabels::Bool = true)
    flags = (edges   ? F3D_EXT_CUBE_AXES_EDGES   : 0x00) |
            (floor   ? F3D_EXT_CUBE_AXES_FLOOR   : 0x00) |
            (grid    ? F3D_EXT_CUBE_AXES_GRID    : 0x00) |
            (zlabels ? F3D_EXT_CUBE_AXES_ZLABELS : 0x00)
    return f3d_ext_enable_cube_axes(window, flags)
end
function f3d_ext_enable_cube_axes(window, flags::Integer)
    ccall((:f3d_ext_enable_cube_axes, libf3d), Cint, (Ptr{f3d_window_t}, Cint), window, Cint(flags))
end

"""
    f3d_ext_disable_cube_axes(window)

Remove the labelled cube axes. `f3d_ext` symbol.
"""
function f3d_ext_disable_cube_axes(window)
    ccall((:f3d_ext_disable_cube_axes, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_image_axes(window, xfmt="%.2f", yfmt="%.2f")

Add a 2-D map frame (X along the bottom, Y along the left, outward tick marks) for
a flat image viewed top-down. `xfmt`/`yfmt` are printf formats for the tick labels.
Shares the cube-axes registry, so `f3d_ext_disable_cube_axes` removes it. `f3d_ext`
symbol — `_has_f3d_ext()`-gated on the caller side.
"""
function f3d_ext_enable_image_axes(window, xfmt::AbstractString = "%.2f", yfmt::AbstractString = "%.2f")
    ccall((:f3d_ext_enable_image_axes, libf3d), Cint,
          (Ptr{f3d_window_t}, Cstring, Cstring), window, xfmt, yfmt)
end

"""
    f3d_ext_enable_colorbar(window, rgb, ncolors, vmin, vmax, title="", fmt="%.1f"; draggable=false)

Add a vertical colour scale on the right of the window from an ordered RGB palette
(`rgb` is `ncolors*3` bytes, low→high) mapped onto `[vmin, vmax]`. The C side copies
the palette immediately. With `draggable=true` the bar is wrapped in a
`vtkScalarBarWidget`, so it can be dragged and corner-resized with the mouse (needs an
interactor). `f3d_ext` symbol — `_has_f3d_ext()`-gated on the caller side.
"""
function f3d_ext_enable_colorbar(window, rgb::Vector{UInt8}, ncolors::Integer,
        vmin::Real, vmax::Real, title::AbstractString = "", fmt::AbstractString = "%.1f";
        draggable::Bool = false)
    GC.@preserve rgb ccall((:f3d_ext_enable_colorbar, libf3d), Cint,
        (Ptr{f3d_window_t}, Ptr{UInt8}, Cint, Cdouble, Cdouble, Cstring, Cstring, Cint),
        window, pointer(rgb), Cint(ncolors), Cdouble(vmin), Cdouble(vmax), title, fmt,
        Cint(draggable))
end

"""
    f3d_ext_disable_colorbar(window)

Remove the colour scale. `f3d_ext` symbol.
"""
function f3d_ext_disable_colorbar(window)
    ccall((:f3d_ext_disable_colorbar, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_color_point_sprites(window, rgb, n_points, n_comp)

Give point SPRITES per-point colours (F3D_API gap #9). The point-sprite path uses
`vtkPointGaussianMapper`, which ignores texture coordinates, so the palette-texture
+ per-point u-texcoord trick that colours plain `GL_POINTS` leaves every splat flat
grey. This bakes a per-point RGB (`n_comp==3`) or RGBA (`n_comp==4`) unsigned-char
colour array directly onto the sprite polydata, switches the gaussian mapper to
direct scalar colours, and turns Emissive on so the colour shows at full strength.

The splat SHAPE is the stock `model.point_sprites.type` option ("sphere" shaded ball
/ "circle" ring / "gaussian" soft blob); f3d's splat mapper ignores a shader override
set after the first render, so the shape can't be changed here. For round FLAT points
use the plain-points path + [`f3d_ext_round_points`](@ref) instead.

`rgb` is a `Vector{UInt8}` of `n_points*n_comp` interleaved bytes, read during the
call only. Enable point sprites and render the window once before calling. `f3d_ext`
symbol. Returns 1 if applied to at least one sprite actor, 0 on error / no match.
"""
function f3d_ext_color_point_sprites(window, rgb, n_points, n_comp)
    ccall((:f3d_ext_color_point_sprites, libf3d), Cint,
          (Ptr{f3d_window_t}, Ptr{Cuchar}, Csize_t, Cint),
          window, rgb, Csize_t(n_points), Cint(n_comp))
end

"""
    f3d_ext_round_points(window, on, unlit = true)

Render PLAIN points (point sprites disabled) as round discs (F3D_API gap #9). The
plain-points path honours the palette texture (colour-by-value works) but draws
SQUARE `GL_POINTS`; this sets `vtkProperty::RenderPointsAsSpheres` on the imported
point actors so they render round. With `unlit=true` lighting is turned off so each
disc is a flat, full-strength colour (no 3D sphere shading). Pass `on=false` to
revert to square points. Render once before calling. `f3d_ext` symbol. Returns 1 if
applied to at least one point actor, 0 on error / no match.
"""
function f3d_ext_round_points(window, on, unlit = true)
    ccall((:f3d_ext_round_points, libf3d), Cint,
          (Ptr{f3d_window_t}, Cint, Cint),
          window, Cint(on ? 1 : 0), Cint(unlit ? 1 : 0))
end

"""
    f3d_ext_enable_sprite_size_keys(window, options, size = 10.0, factor = 1.25)

Bind `Shift+'+'` / `Shift+'-'` to grow / shrink the point sprites at runtime. f3d's `O`
key cycles the sprite TYPE but never the size, so the non-default splat shapes render at
the fixed `model.point_sprites.size` (default 10) and look oversized. This observer
multiplies / divides that option by `factor` per press and re-renders; plain `+`/`-`
stay free (e.g. for zoom). Layout-independent (matches the shifted character). Needs an
interactor; pass the engine's options handle. `f3d_ext` symbol. Returns 1 on success, 0
if there is no interactor.
"""
function f3d_ext_enable_sprite_size_keys(window, options, size = 10.0, factor = 1.25)
    ccall((:f3d_ext_enable_sprite_size_keys, libf3d), Cint,
          (Ptr{f3d_window_t}, Ptr{Cvoid}, Cdouble, Cdouble),
          window, options, Cdouble(size), Cdouble(factor))
end

"""
    f3d_ext_disable_sprite_size_keys(window)

Remove the `Shift+'+'`/`'-'` sprite-resize key observer. `f3d_ext` symbol.
"""
function f3d_ext_disable_sprite_size_keys(window)
    ccall((:f3d_ext_disable_sprite_size_keys, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_sprite_zscale_sync(window, options)

Keep point SPRITES at the `render.model_scale` (vertical-scale) locations. f3d applies
model_scale as an actor transform, which anisotropically DISTORTS gaussian/sphere/circle
splats; this instead bakes the current model_scale into the sprite point coordinates
(from a cached original) so the sprites move to the stretched z without deforming.
Re-applied when the `O` key cycles into a sprite mode and once on enable. Needs an
interactor; pass the engine's options handle. `f3d_ext` symbol. Returns 1 on success.
"""
function f3d_ext_enable_sprite_zscale_sync(window, options)
    ccall((:f3d_ext_enable_sprite_zscale_sync, libf3d), Cint,
          (Ptr{f3d_window_t}, Ptr{Cvoid}), window, options)
end

"""
    f3d_ext_disable_sprite_zscale_sync(window)

Remove the sprite vertical-scale sync (and its `O` observer). `f3d_ext` symbol.
"""
function f3d_ext_disable_sprite_zscale_sync(window)
    ccall((:f3d_ext_disable_sprite_zscale_sync, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_add_lines(window, points, n_points, line_sizes, n_lines, rgb, vert_rgb, width, overlay)

Add polyline overlay(s) drawn ON TOP of the surfaces/images. The public libf3d mesh
API only builds polygon cells, so lines go through the `f3d_ext` renderer hatch (a
`vtkPolyData` of line cells + a flat-shaded `vtkActor`).

`points` is a `Vector{Cdouble}` of xyz interleaved (`3*n_points`). `line_sizes` is a
`Vector{Cuint}` of vertices per polyline (sum `== n_points`); pass `nothing`/`0` for a
single polyline. `rgb` is a 3-element `Vector{Cdouble}` in `[0,1]` (or `nothing` →
yellow). `vert_rgb` is `3*n_points` `UInt8` for per-vertex colour (overrides `rgb`) or
`nothing`. `width` is in screen pixels. `overlay != 0` pulls the lines toward the
camera so coplanar lines on a surface are not lost to z-fighting.

`f3d_ext` symbol — only present in an f3d built with `c/f3d_ext_*.cxx`. Returns a
line-set id (>= 1) for [`f3d_ext_remove_lines`](@ref), or 0 on error.
"""
function f3d_ext_add_lines(window, points::Vector{Cdouble}, n_points::Integer,
        line_sizes, n_lines::Integer, rgb, vert_rgb, width::Real, overlay::Integer)
    GC.@preserve points line_sizes rgb vert_rgb ccall((:f3d_ext_add_lines, libf3d), Cint,
        (Ptr{f3d_window_t}, Ptr{Cdouble}, Csize_t, Ptr{Cuint}, Csize_t,
         Ptr{Cdouble}, Ptr{Cuchar}, Cdouble, Cint),
        window, points, Csize_t(n_points),
        line_sizes === nothing ? C_NULL : line_sizes, Csize_t(n_lines),
        rgb === nothing ? C_NULL : rgb,
        vert_rgb === nothing ? C_NULL : vert_rgb,
        Cdouble(width), Cint(overlay))
end

"""
    f3d_ext_remove_lines(window, id)

Remove one line set previously added with [`f3d_ext_add_lines`](@ref) by its `id`.
No-op if unknown. `f3d_ext` symbol.
"""
function f3d_ext_remove_lines(window, id)
    ccall((:f3d_ext_remove_lines, libf3d), Cvoid, (Ptr{f3d_window_t}, Cint), window, Cint(id))
end

"""
    f3d_ext_clear_lines(window)

Remove ALL line sets added to the window. No-op if none. `f3d_ext` symbol.
"""
function f3d_ext_clear_lines(window)
    ccall((:f3d_ext_clear_lines, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_set_edge_visibility(window, actor_index, on; r=-1.0, g=-1.0, b=-1.0, width=0.0)

Per-actor edge (wireframe) visibility — gap #6. Stock `render.show_edges` is global;
this shows/hides a coloured wireframe for ONE imported actor (or all) by index into the
coloring-actor list (import order). `actor_index = -1` applies to every actor.

It draws a separate flat-shaded (LightingOff) wireframe overlay rather than toggling the
actor's native edges — f3d renders the coloring actors as PBR, whose edge pass ignores
edge colour (edges come out a dim grey). The overlay gives a crisp, caller-chosen colour,
persists across renders, and is independent of the global `render.show_edges` option. It
shares the source points and mirrors the source actor's transform at call time (lines up
with a `render.model_scale` exaggeration; re-call after the scale changes). `on != 0`
replaces any existing per-actor wireframe; `on = 0` removes it. Negative `r/g/b` → white;
`width <= 0` → 1. Returns the number of actors changed (0 on error / out-of-range index).
`f3d_ext` symbol.
"""
function f3d_ext_set_edge_visibility(window, actor_index, on; r = -1.0, g = -1.0, b = -1.0, width = 0.0)
    ccall((:f3d_ext_set_edge_visibility, libf3d), Cint,
          (Ptr{f3d_window_t}, Cint, Cint, Cdouble, Cdouble, Cdouble, Cdouble),
          window, Cint(actor_index), Cint(on), Cdouble(r), Cdouble(g), Cdouble(b), Cdouble(width))
end

"""
    f3d_ext_add_cell_edges(window, actor_index, cell_ids; r=-1.0, g=-1.0, b=-1.0, width=1.0)

Wireframe overlay on a SUBSET of one mesh's faces (per-cell edges) — gap #6. Copies the
given 0-based `cell_ids` from the imported actor at `actor_index` (sharing its points)
into a separate wireframe actor, so edges show on a region without enabling edges for the
whole mesh. The overlay mirrors the source actor's transform at call time (lines up with a
`render.model_scale` exaggeration); call again after the scale changes to refresh.
Negative `r/g/b` → white. Returns an overlay id (>= 1) for
[`f3d_ext_remove_cell_edges`](@ref), or 0 on error. `f3d_ext` symbol.
"""
function f3d_ext_add_cell_edges(window, actor_index, cell_ids; r = -1.0, g = -1.0, b = -1.0, width = 1.0)
    ids = Csize_t.(cell_ids)
    GC.@preserve ids ccall((:f3d_ext_add_cell_edges, libf3d), Cint,
        (Ptr{f3d_window_t}, Cint, Ptr{Csize_t}, Csize_t, Cdouble, Cdouble, Cdouble, Cdouble),
        window, Cint(actor_index), pointer(ids), Csize_t(length(ids)),
        Cdouble(r), Cdouble(g), Cdouble(b), Cdouble(width))
end

"""
    f3d_ext_remove_cell_edges(window, id)

Remove one cell-edge overlay added with [`f3d_ext_add_cell_edges`](@ref) by its `id`.
No-op if unknown. `f3d_ext` symbol.
"""
function f3d_ext_remove_cell_edges(window, id)
    ccall((:f3d_ext_remove_cell_edges, libf3d), Cvoid, (Ptr{f3d_window_t}, Cint), window, Cint(id))
end

"""
    f3d_ext_clear_cell_edges(window)

Remove ALL cell-edge overlays from the window. No-op if none. `f3d_ext` symbol.
"""
function f3d_ext_clear_cell_edges(window)
    ccall((:f3d_ext_clear_cell_edges, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_enable_rubber_band_pick(window, callback, user_data, r=0.83, g=0.83, b=0.83)

Install a rubber-band area point selector (DISARMED). Selection mode starts off:
right-drag keeps its normal f3d behaviour until armed via Ctrl+B (or
[`f3d_ext_set_rubber_band_armed`](@ref)). While armed, right-drag a box; on release
the enclosed points are toggled into a persistent selection, highlighted with the
`(r,g,b)` overlay colour (each in `[0,1]`, default light grey), and
`callback` (a C function pointer of signature
`void(const size_t* ids, size_t count, void* user_data)`) is invoked with the full
selection. Ctrl+Z undoes. Intended for POINT CLOUDS (the frustum pick also returns
occluded points, so it is unsuitable for solid surfaces). `f3d_ext` symbol. Returns
1 on success, 0 if no interactor/renderer.
"""
function f3d_ext_enable_rubber_band_pick(window, callback, user_data, r = 0.83, g = 0.83, b = 0.83)
    ccall((:f3d_ext_enable_rubber_band_pick, libf3d), Cint,
          (Ptr{f3d_window_t}, Ptr{Cvoid}, Ptr{Cvoid}, Cdouble, Cdouble, Cdouble),
          window, callback, user_data, Cdouble(r), Cdouble(g), Cdouble(b))
end

"""
    f3d_ext_set_rubber_band_armed(window, armed)

Arm (`armed != 0`) or disarm rubber-band selection mode programmatically; same as
the Ctrl+B toggle. No-op if the selector is not enabled. `f3d_ext` symbol.
"""
function f3d_ext_set_rubber_band_armed(window, armed)
    ccall((:f3d_ext_set_rubber_band_armed, libf3d), Cvoid, (Ptr{f3d_window_t}, Cint), window, Cint(armed))
end

"""
    f3d_ext_get_rubber_band_armed(window)

Return 1 if rubber-band selection mode is armed, else 0. `f3d_ext` symbol.
"""
function f3d_ext_get_rubber_band_armed(window)
    ccall((:f3d_ext_get_rubber_band_armed, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_disable_rubber_band_pick(window)

Remove the rubber-band selector and its overlay. `f3d_ext` symbol.
"""
function f3d_ext_disable_rubber_band_pick(window)
    ccall((:f3d_ext_disable_rubber_band_pick, libf3d), Cvoid, (Ptr{f3d_window_t},), window)
end

"""
    f3d_ext_area_pick_points(window, x0, y0, x1, y1, count)

Hardware area pick: returns a heap array of `count[]` point ids inside the display
rectangle [x0,x1]x[y0,y1] (display coords, origin bottom-left). Free with
[`f3d_ext_free_ids`](@ref). `f3d_ext` symbol.
"""
function f3d_ext_area_pick_points(window, x0, y0, x1, y1, count)
    ccall((:f3d_ext_area_pick_points, libf3d), Ptr{Csize_t}, (Ptr{f3d_window_t}, Cint, Cint, Cint, Cint, Ptr{Csize_t}), window, x0, y0, x1, y1, count)
end

"""
    f3d_ext_free_ids(ids)

Free an id array returned by [`f3d_ext_area_pick_points`](@ref). `f3d_ext` symbol.
"""
function f3d_ext_free_ids(ids)
    ccall((:f3d_ext_free_ids, libf3d), Cvoid, (Ptr{Csize_t},), ids)
end

"""
    f3d_window_set_size(window, width, height)

Set the size of the window.

# Arguments
* `window`: Window handle.
* `width`: Window width in pixels.
* `height`: Window height in pixels.
"""
function f3d_window_set_size(window, width, height)
    ccall((:f3d_window_set_size, libf3d), Cvoid, (Ptr{f3d_window_t}, Cint, Cint), window, width, height)
end

"""
    f3d_window_get_width(window)

Get the width of the window.

# Arguments
* `window`: Window handle.
# Returns
Window width in pixels.
"""
function f3d_window_get_width(window)
    ccall((:f3d_window_get_width, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_get_height(window)

Get the height of the window.

# Arguments
* `window`: Window handle.
# Returns
Window height in pixels.
"""
function f3d_window_get_height(window)
    ccall((:f3d_window_get_height, libf3d), Cint, (Ptr{f3d_window_t},), window)
end

"""
    f3d_window_set_position(window, x, y)

Set the position of the window.

# Arguments
* `window`: Window handle.
* `x`: X position in pixels.
* `y`: Y position in pixels.
"""
function f3d_window_set_position(window, x, y)
    ccall((:f3d_window_set_position, libf3d), Cvoid, (Ptr{f3d_window_t}, Cint, Cint), window, x, y)
end

"""
    f3d_window_set_icon(window, icon, icon_size)

Set the icon to be shown by a window manager.

# Arguments
* `window`: Window handle.
* `icon`: Icon data as unsigned char array.
* `icon_size`: Size of icon data in bytes.
"""
function f3d_window_set_icon(window, icon, icon_size)
    ccall((:f3d_window_set_icon, libf3d), Cvoid, (Ptr{f3d_window_t}, Ptr{Cuchar}, Csize_t), window, icon, icon_size)
end

"""
    f3d_window_set_window_name(window, window_name)

Set the window name to be shown by a window manager.

# Arguments
* `window`: Window handle.
* `window_name`: Window name string.
"""
function f3d_window_set_window_name(window, window_name)
    ccall((:f3d_window_set_window_name, libf3d), Cvoid, (Ptr{f3d_window_t}, Cstring), window, window_name)
end

"""
    f3d_window_get_world_from_display(window, display_point, world_point)

Convert a point in display coordinate to world coordinate.

# Arguments
* `window`: Window handle.
* `display_point`: Display coordinate point [x, y, z].
* `world_point`: Output world coordinate point [x, y, z].
"""
function f3d_window_get_world_from_display(window, display_point, world_point)
    ccall((:f3d_window_get_world_from_display, libf3d), Cvoid, (Ptr{f3d_window_t}, Ptr{Cdouble}, Ptr{Cdouble}), window, display_point, world_point)
end

"""
    f3d_window_get_display_from_world(window, world_point, display_point)

Convert a point in world coordinate to display coordinate.

# Arguments
* `window`: Window handle.
* `world_point`: World coordinate point [x, y, z].
* `display_point`: Output display coordinate point [x, y, z].
"""
function f3d_window_get_display_from_world(window, world_point, display_point)
    ccall((:f3d_window_get_display_from_world, libf3d), Cvoid, (Ptr{f3d_window_t}, Ptr{Cdouble}, Ptr{Cdouble}), window, world_point, display_point)
end

const f3d_engine_t = Cvoid

const f3d_options_t = Cvoid

"""
    f3d_backend_info_t

Structure representing a rendering backend with its availability.

| Field     | Note                                              |
| :-------- | :------------------------------------------------ |
| name      | Backend name (e.g., "GLX", "EGL", "WGL", etc.)    |
| available | Non-zero if backend is available, zero otherwise  |
"""
struct f3d_backend_info_t
    name::Cstring
    available::Cint
end

"""
    f3d_module_info_t

Structure representing a module with its availability.

| Field     | Note                                             |
| :-------- | :----------------------------------------------- |
| name      | Module name                                      |
| available | Non-zero if module is available, zero otherwise  |
"""
struct f3d_module_info_t
    name::Cstring
    available::Cint
end

"""
    f3d_lib_info_t

Structure providing information about the libf3d.

| Field          | Note                                        |
| :------------- | :------------------------------------------ |
| version        | Version string                              |
| version\\_full | Full version string                         |
| build\\_date   | Build date                                  |
| build\\_system | Build system                                |
| compiler       | Compiler used                               |
| modules        | NULL-terminated array of modules            |
| vtk\\_version  | VTK version                                 |
| copyrights     | NULL-terminated array of copyright strings  |
| license        | License text                                |
"""
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

"""
    f3d_reader_info_t

Structure providing information about a reader.

| Field                   | Note                                      |
| :---------------------- | :---------------------------------------- |
| name                    | Reader name                               |
| description             | Reader description                        |
| extensions              | NULL-terminated array of file extensions  |
| mime\\_types            | NULL-terminated array of MIME types       |
| plugin\\_name           | Plugin name                               |
| has\\_scene\\_reader    | Non-zero if has scene reader              |
| has\\_geometry\\_reader | Non-zero if has geometry reader           |
"""
struct f3d_reader_info_t
    name::Cstring
    description::Cstring
    extensions::Ptr{Cstring}
    mime_types::Ptr{Cstring}
    plugin_name::Cstring
    has_scene_reader::Cint
    has_geometry_reader::Cint
end

"""
    f3d_engine_create(offscreen)

@{

` Engine factory methods`

Create an engine with an automatic window.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Arguments
* `offscreen`: If non-zero, the window will be hidden.
# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create(offscreen)
    ccall((:f3d_engine_create, libf3d), Ptr{f3d_engine_t}, (Cint,), offscreen)
end

# no prototype is found for this function at engine_c_api.h:91:28, please use with caution
"""
    f3d_engine_create_none()

Create an engine with no window.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_none()
    ccall((:f3d_engine_create_none, libf3d), Ptr{f3d_engine_t}, ())
end

"""
    f3d_engine_create_glx(offscreen)

Create an engine with a GLX window (Linux only).

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Arguments
* `offscreen`: If non-zero, the window will be hidden.
# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_glx(offscreen)
    ccall((:f3d_engine_create_glx, libf3d), Ptr{f3d_engine_t}, (Cint,), offscreen)
end

"""
    f3d_engine_create_wgl(offscreen)

Create an engine with a WGL window (Windows only).

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Arguments
* `offscreen`: If non-zero, the window will be hidden.
# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_wgl(offscreen)
    ccall((:f3d_engine_create_wgl, libf3d), Ptr{f3d_engine_t}, (Cint,), offscreen)
end

# no prototype is found for this function at engine_c_api.h:120:28, please use with caution
"""
    f3d_engine_create_egl()

Create an engine with an offscreen EGL window.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_egl()
    ccall((:f3d_engine_create_egl, libf3d), Ptr{f3d_engine_t}, ())
end

# no prototype is found for this function at engine_c_api.h:129:28, please use with caution
"""
    f3d_engine_create_osmesa()

Create an engine with an offscreen OSMesa window.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_osmesa()
    ccall((:f3d_engine_create_osmesa, libf3d), Ptr{f3d_engine_t}, ())
end

"""
    f3d_engine_create_external(get_proc_address)

Create an engine with an external window.

A context to retrieve OpenGL symbols is required. The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Arguments
* `get_proc_address`: Function pointer for OpenGL symbol resolution.
# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external(get_proc_address)
    ccall((:f3d_engine_create_external, libf3d), Ptr{f3d_engine_t}, (f3d_context_function_t,), get_proc_address)
end

# no prototype is found for this function at engine_c_api.h:149:28, please use with caution
"""
    f3d_engine_create_external_glx()

Create an engine with an external GLX context (Linux only).

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external_glx()
    ccall((:f3d_engine_create_external_glx, libf3d), Ptr{f3d_engine_t}, ())
end

# no prototype is found for this function at engine_c_api.h:158:28, please use with caution
"""
    f3d_engine_create_external_wgl()

Create an engine with an external WGL context (Windows only).

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external_wgl()
    ccall((:f3d_engine_create_external_wgl, libf3d), Ptr{f3d_engine_t}, ())
end

# no prototype is found for this function at engine_c_api.h:167:28, please use with caution
"""
    f3d_engine_create_external_cocoa()

Create an engine with an external COCOA context (macOS only).

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external_cocoa()
    ccall((:f3d_engine_create_external_cocoa, libf3d), Ptr{f3d_engine_t}, ())
end

# no prototype is found for this function at engine_c_api.h:176:28, please use with caution
"""
    f3d_engine_create_external_egl()

Create an engine with an external EGL context.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external_egl()
    ccall((:f3d_engine_create_external_egl, libf3d), Ptr{f3d_engine_t}, ())
end

# no prototype is found for this function at engine_c_api.h:185:28, please use with caution
"""
    f3d_engine_create_external_osmesa()

Create an engine with an external OSMesa context.

The returned engine must be deleted with [`f3d_engine_delete`](@ref)().

# Returns
Engine handle, NULL on failure.
"""
function f3d_engine_create_external_osmesa()
    ccall((:f3d_engine_create_external_osmesa, libf3d), Ptr{f3d_engine_t}, ())
end

"""
    f3d_engine_delete(engine)

Destroy an engine and free associated resources.

# Arguments
* `engine`: Engine handle.
"""
function f3d_engine_delete(engine)
    ccall((:f3d_engine_delete, libf3d), Cvoid, (Ptr{f3d_engine_t},), engine)
end

"""
    f3d_engine_set_cache_path(engine, cache_path)

Set the cache path directory.

# Arguments
* `engine`: Engine handle.
* `cache_path`: Cache path string.
# Returns
1 on success, 0 on failure.
"""
function f3d_engine_set_cache_path(engine, cache_path)
    ccall((:f3d_engine_set_cache_path, libf3d), Cint, (Ptr{f3d_engine_t}, Cstring), engine, cache_path)
end

"""
    f3d_engine_set_options(engine, options)

Set options for the engine.

This will copy the provided options into the engine.

# Arguments
* `engine`: Engine handle.
* `options`: Options handle to copy from.
"""
function f3d_engine_set_options(engine, options)
    ccall((:f3d_engine_set_options, libf3d), Cvoid, (Ptr{f3d_engine_t}, Ptr{f3d_options_t}), engine, options)
end

"""
    f3d_engine_get_options(engine)

Get the options object from the engine.

# Arguments
* `engine`: Engine handle.
# Returns
Options handle (not owned by caller, managed by engine).
"""
function f3d_engine_get_options(engine)
    ccall((:f3d_engine_get_options, libf3d), Ptr{f3d_options_t}, (Ptr{f3d_engine_t},), engine)
end

"""
    f3d_engine_get_window(engine)

Get the window from the engine.

# Arguments
* `engine`: Engine handle.
# Returns
Window handle (not owned by caller).
"""
function f3d_engine_get_window(engine)
    ccall((:f3d_engine_get_window, libf3d), Ptr{f3d_window_t}, (Ptr{f3d_engine_t},), engine)
end

"""
    f3d_engine_get_scene(engine)

Get the scene from the engine.

# Arguments
* `engine`: Engine handle.
# Returns
Scene handle (not owned by caller).
"""
function f3d_engine_get_scene(engine)
    ccall((:f3d_engine_get_scene, libf3d), Ptr{f3d_scene_t}, (Ptr{f3d_engine_t},), engine)
end

"""
    f3d_engine_get_interactor(engine)

Get the interactor from the engine.

# Arguments
* `engine`: Engine handle.
# Returns
Interactor handle (not owned by caller).
"""
function f3d_engine_get_interactor(engine)
    ccall((:f3d_engine_get_interactor, libf3d), Ptr{f3d_interactor_t}, (Ptr{f3d_engine_t},), engine)
end

"""
    f3d_engine_get_rendering_backend_list(count)

@{

` Rendering backends`

List rendering backends supported by libf3d.

Returns a map of backend names with boolean flags indicating availability. The returned array of key-value pairs is NULL-terminated and must be freed by the caller using [`f3d_engine_free_backend_list`](@ref)().

# Arguments
* `count`: Pointer to store the number of backends (optional, can be NULL).
# Returns
NULL-terminated array of backend name/availability pairs.
"""
function f3d_engine_get_rendering_backend_list(count)
    ccall((:f3d_engine_get_rendering_backend_list, libf3d), Ptr{f3d_backend_info_t}, (Ptr{Cint},), count)
end

"""
    f3d_engine_load_plugin(path_or_name)

@{

` Plugin management`

Load a plugin.

# Arguments
* `path_or_name`: Plugin path or name.
# Returns
1 on success, 0 on failure.
"""
function f3d_engine_load_plugin(path_or_name)
    ccall((:f3d_engine_load_plugin, libf3d), Cint, (Cstring,), path_or_name)
end

# no prototype is found for this function at engine_c_api.h:271:19, please use with caution
"""
    f3d_engine_autoload_plugins()

Automatically load all static plugins.
"""
function f3d_engine_autoload_plugins()
    ccall((:f3d_engine_autoload_plugins, libf3d), Cvoid, ())
end

"""
    f3d_engine_get_plugins_list(plugin_path)

List plugins based on associated json files located in the given directory.

Listed plugins can be loaded using [`f3d_engine_load_plugin`](@ref) function. The returned array is NULL-terminated and must be freed by the caller using [`f3d_engine_free_string_array`](@ref)().

# Arguments
* `plugin_path`: Path to the directory containing plugin json files.
# Returns
NULL-terminated array of plugin name strings, or NULL if the directory doesn't exist.
"""
function f3d_engine_get_plugins_list(plugin_path)
    ccall((:f3d_engine_get_plugins_list, libf3d), Ptr{Cstring}, (Cstring,), plugin_path)
end

# no prototype is found for this function at engine_c_api.h:296:21, please use with caution
"""
    f3d_engine_get_all_reader_option_names()

@{

` Reader options`

Get all plugin option names that can be set using [`f3d_engine_set_reader_option`](@ref).

This vector can be expanded when loading plugins using [`f3d_engine_load_plugin`](@ref). The returned array is NULL-terminated and must be freed by the caller using [`f3d_engine_free_string_array`](@ref)().

# Returns
NULL-terminated array of option name strings.
"""
function f3d_engine_get_all_reader_option_names()
    ccall((:f3d_engine_get_all_reader_option_names, libf3d), Ptr{Cstring}, ())
end

"""
    f3d_engine_set_reader_option(name, value)

Set a specific reader option.

# Arguments
* `name`: Option name.
* `value`: Option value.
# Returns
1 on success, 0 on failure.
"""
function f3d_engine_set_reader_option(name, value)
    ccall((:f3d_engine_set_reader_option, libf3d), Cint, (Cstring, Cstring), name, value)
end

"""
    f3d_engine_free_backend_list(backends)

Free a backend list returned by [`f3d_engine_get_rendering_backend_list`](@ref)().

# Arguments
* `backends`: Backend list to free.
"""
function f3d_engine_free_backend_list(backends)
    ccall((:f3d_engine_free_backend_list, libf3d), Cvoid, (Ptr{f3d_backend_info_t},), backends)
end

# no prototype is found for this function at engine_c_api.h:324:30, please use with caution
"""
    f3d_engine_get_lib_info()

@{

` Library information`

Get information about the libf3d.

The returned structure must be freed by the caller using [`f3d_engine_free_lib_info`](@ref)().

# Returns
Library information structure.
"""
function f3d_engine_get_lib_info()
    ccall((:f3d_engine_get_lib_info, libf3d), Ptr{f3d_lib_info_t}, ())
end

"""
    f3d_engine_free_lib_info(info)

Free a lib info structure returned by [`f3d_engine_get_lib_info`](@ref)().

# Arguments
* `info`: Lib info structure to free.
"""
function f3d_engine_free_lib_info(info)
    ccall((:f3d_engine_free_lib_info, libf3d), Cvoid, (Ptr{f3d_lib_info_t},), info)
end

"""
    f3d_engine_get_readers_info(count)

Get information about the supported readers.

The returned array is NULL-terminated and must be freed by the caller using [`f3d_engine_free_readers_info`](@ref)().

# Arguments
* `count`: Pointer to store the number of readers (optional, can be NULL).
# Returns
NULL-terminated array of reader information structures.
"""
function f3d_engine_get_readers_info(count)
    ccall((:f3d_engine_get_readers_info, libf3d), Ptr{f3d_reader_info_t}, (Ptr{Cint},), count)
end

"""
    f3d_engine_free_readers_info(readers)

Free a readers info array returned by [`f3d_engine_get_readers_info`](@ref)().

# Arguments
* `readers`: Readers info array to free.
"""
function f3d_engine_free_readers_info(readers)
    ccall((:f3d_engine_free_readers_info, libf3d), Cvoid, (Ptr{f3d_reader_info_t},), readers)
end

"""
    f3d_engine_free_string_array(array)

@{

` Utility functions`

Free a NULL-terminated string array.

# Arguments
* `array`: String array to free.
"""
function f3d_engine_free_string_array(array)
    ccall((:f3d_engine_free_string_array, libf3d), Cvoid, (Ptr{Cstring},), array)
end

"""
    f3d_log_verbose_level_t

Enumeration of verbose levels.
"""
@enum f3d_log_verbose_level_t::UInt32 begin
    F3D_LOG_DEBUG = 0
    F3D_LOG_INFO = 1
    F3D_LOG_WARN = 2
    F3D_LOG_ERROR = 3
    F3D_LOG_QUIET = 4
end

"""
    f3d_log_print(level, message)

Log a message at the specified verbose level.

# Arguments
* `level`: The verbose level for the message.
* `message`: The message string.
"""
function f3d_log_print(level, message)
    ccall((:f3d_log_print, libf3d), Cvoid, (f3d_log_verbose_level_t, Cstring), level, message)
end

"""
    f3d_log_debug(message)

Log a debug message.

# Arguments
* `message`: The message string.
"""
function f3d_log_debug(message)
    ccall((:f3d_log_debug, libf3d), Cvoid, (Cstring,), message)
end

"""
    f3d_log_info(message)

Log an info message.

# Arguments
* `message`: The message string.
"""
function f3d_log_info(message)
    ccall((:f3d_log_info, libf3d), Cvoid, (Cstring,), message)
end

"""
    f3d_log_warn(message)

Log a warning message.

# Arguments
* `message`: The message string.
"""
function f3d_log_warn(message)
    ccall((:f3d_log_warn, libf3d), Cvoid, (Cstring,), message)
end

"""
    f3d_log_error(message)

Log an error message.

# Arguments
* `message`: The message string.
"""
function f3d_log_error(message)
    ccall((:f3d_log_error, libf3d), Cvoid, (Cstring,), message)
end

# typedef void ( * f3d_log_forward_fn_t ) ( f3d_log_verbose_level_t level , const char * message )
"""
Callback function type for log forwarding.

# Arguments
* `level`: The verbose level of the log message.
* `message`: The log message string.
"""
const f3d_log_forward_fn_t = Ptr{Cvoid}

"""
    f3d_log_set_use_coloring(use)

Set the coloring usage, if applicable (e.g., console output).

# Arguments
* `use`: If non-zero, coloring will be used.
"""
function f3d_log_set_use_coloring(use)
    ccall((:f3d_log_set_use_coloring, libf3d), Cvoid, (Cint,), use)
end

"""
    f3d_log_set_verbose_level(level, force_std_err)

Set the verbose level.

By default, only warnings and errors are written to stderr, debug and info are written to stdout. If force\\_std\\_err is non-zero, all messages including debug and info are written to stderr.

# Arguments
* `level`: The verbose level to set.
* `force_std_err`: If non-zero, all messages are written to stderr.
"""
function f3d_log_set_verbose_level(level, force_std_err)
    ccall((:f3d_log_set_verbose_level, libf3d), Cvoid, (f3d_log_verbose_level_t, Cint), level, force_std_err)
end

"""
    f3d_log_get_verbose_level()

Get the current verbose level.

# Returns
The current verbose level.
"""
function f3d_log_get_verbose_level()
    ccall((:f3d_log_get_verbose_level, libf3d), f3d_log_verbose_level_t, ())
end

"""
    f3d_log_forward(callback)

Set a callback function to forward log messages.

The callback will be invoked with the level and the message string whenever a message is logged, regardless of the verbose level. Set to NULL to disable forwarding.

# Arguments
* `callback`: The callback function, or NULL to disable forwarding.
"""
function f3d_log_forward(callback)
    ccall((:f3d_log_forward, libf3d), Cvoid, (f3d_log_forward_fn_t,), callback)
end

# no prototype is found for this function at options_c_api.h:22:29, please use with caution
"""
    f3d_options_create()

@{

` Options lifecycle`

Create a new options object.

The returned options object must be freed with [`f3d_options_delete`](@ref)().

# Returns
Options handle.
"""
function f3d_options_create()
    ccall((:f3d_options_create, libf3d), Ptr{f3d_options_t}, ())
end

"""
    f3d_options_delete(options)

Delete an options object.

# Arguments
* `options`: Options handle to delete.
"""
function f3d_options_delete(options)
    ccall((:f3d_options_delete, libf3d), Cvoid, (Ptr{f3d_options_t},), options)
end

"""
    f3d_options_set_as_bool(options, name, value)

@{

` Option setters`

Set an option value as a boolean.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `value`: Boolean value (0 for false, non-zero for true).
"""
function f3d_options_set_as_bool(options, name, value)
    ccall((:f3d_options_set_as_bool, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Cint), options, name, value)
end

"""
    f3d_options_set_as_int(options, name, value)

Set an option value as an integer.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `value`: Integer value.
"""
function f3d_options_set_as_int(options, name, value)
    ccall((:f3d_options_set_as_int, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Cint), options, name, value)
end

"""
    f3d_options_set_as_double(options, name, value)

Set an option value as a double.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `value`: Double value.
"""
function f3d_options_set_as_double(options, name, value)
    ccall((:f3d_options_set_as_double, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Cdouble), options, name, value)
end

"""
    f3d_options_set_as_string(options, name, value)

Set an option value as a string.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `value`: String value.
"""
function f3d_options_set_as_string(options, name, value)
    ccall((:f3d_options_set_as_string, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Cstring), options, name, value)
end

"""
    f3d_options_set_as_double_vector(options, name, values, count)

Set an option value as a double vector.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `values`: Array of double values.
* `count`: Number of values in the array.
"""
function f3d_options_set_as_double_vector(options, name, values, count)
    ccall((:f3d_options_set_as_double_vector, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Ptr{Cdouble}, Csize_t), options, name, values, count)
end

"""
    f3d_options_set_as_int_vector(options, name, values, count)

Set an option value as an integer vector.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `values`: Array of integer values.
* `count`: Number of values in the array.
"""
function f3d_options_set_as_int_vector(options, name, values, count)
    ccall((:f3d_options_set_as_int_vector, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Ptr{Cint}, Csize_t), options, name, values, count)
end

"""
    f3d_options_get_as_bool(options, name)

@{

` Option getters`

Get an option value as a boolean.

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
Boolean value (0 for false, non-zero for true).
"""
function f3d_options_get_as_bool(options, name)
    ccall((:f3d_options_get_as_bool, libf3d), Cint, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_get_as_int(options, name)

Get an option value as an integer.

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
Integer value.
"""
function f3d_options_get_as_int(options, name)
    ccall((:f3d_options_get_as_int, libf3d), Cint, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_get_as_double(options, name)

Get an option value as a double.

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
Double value.
"""
function f3d_options_get_as_double(options, name)
    ccall((:f3d_options_get_as_double, libf3d), Cdouble, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_get_as_string(options, name)

Get an option value as a string.

The returned string is heap-allocated and must be freed with [`f3d_options_free_string`](@ref)().

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
String value.
"""
function f3d_options_get_as_string(options, name)
    ccall((:f3d_options_get_as_string, libf3d), Cstring, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_get_as_string_representation(options, name)

Get an option value as a string representation.

The returned string is heap-allocated and must be freed with [`f3d_options_free_string`](@ref)().

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
String representation of the option value.
"""
function f3d_options_get_as_string_representation(options, name)
    ccall((:f3d_options_get_as_string_representation, libf3d), Cstring, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_set_as_string_representation(options, name, str)

Set an option value from a string representation.

Parses the string and sets the option to the appropriate type.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `str`: String representation of the value.
"""
function f3d_options_set_as_string_representation(options, name, str)
    ccall((:f3d_options_set_as_string_representation, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Cstring), options, name, str)
end

"""
    f3d_options_free_string(str)

Free a string returned by an options function.

Use this to free strings returned by [`f3d_options_get_as_string`](@ref)() and [`f3d_options_get_as_string_representation`](@ref)().

# Arguments
* `str`: String to free.
"""
function f3d_options_free_string(str)
    ccall((:f3d_options_free_string, libf3d), Cvoid, (Cstring,), str)
end

"""
    f3d_options_get_as_double_vector(options, name, values, count)

Get an option value as a double vector.

The caller must provide a pre-allocated array large enough to hold the values.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `values`: Pre-allocated array to store the double values.
* `count`: Pointer to store the number of values retrieved.
"""
function f3d_options_get_as_double_vector(options, name, values, count)
    ccall((:f3d_options_get_as_double_vector, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Ptr{Cdouble}, Ptr{Csize_t}), options, name, values, count)
end

"""
    f3d_options_get_as_int_vector(options, name, values, count)

Get an option value as an integer vector.

The caller must provide a pre-allocated array large enough to hold the values.

# Arguments
* `options`: Options handle.
* `name`: Option name.
* `values`: Pre-allocated array to store the integer values.
* `count`: Pointer to store the number of values retrieved.
"""
function f3d_options_get_as_int_vector(options, name, values, count)
    ccall((:f3d_options_get_as_int_vector, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Ptr{Cint}, Ptr{Csize_t}), options, name, values, count)
end

"""
    f3d_options_toggle(options, name)

@{

` Option manipulation`

Toggle a boolean option value.

# Arguments
* `options`: Options handle.
* `name`: Option name.
"""
function f3d_options_toggle(options, name)
    ccall((:f3d_options_toggle, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_is_same(options, other, name)

Check if an option value is the same in two options objects.

# Arguments
* `options`: Options handle.
* `other`: Other options handle to compare with.
* `name`: Option name.
# Returns
1 if the values are the same, 0 otherwise.
"""
function f3d_options_is_same(options, other, name)
    ccall((:f3d_options_is_same, libf3d), Cint, (Ptr{f3d_options_t}, Ptr{f3d_options_t}, Cstring), options, other, name)
end

"""
    f3d_options_has_value(options, name)

Check if an option has a value set.

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
1 if the option has a value, 0 otherwise.
"""
function f3d_options_has_value(options, name)
    ccall((:f3d_options_has_value, libf3d), Cint, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_copy(options, other, name)

Copy an option value from another options object.

# Arguments
* `options`: Destination options handle.
* `other`: Source options handle to copy from.
* `name`: Option name.
"""
function f3d_options_copy(options, other, name)
    ccall((:f3d_options_copy, libf3d), Cvoid, (Ptr{f3d_options_t}, Ptr{f3d_options_t}, Cstring), options, other, name)
end

"""
    f3d_options_get_all_names(count)

Get all option names.

The returned array is heap-allocated and must be freed with [`f3d_options_free_names`](@ref)().

# Arguments
* `count`: Pointer to store the count of names.
# Returns
Array of option names.
"""
function f3d_options_get_all_names(count)
    ccall((:f3d_options_get_all_names, libf3d), Ptr{Cstring}, (Ptr{Csize_t},), count)
end

"""
    f3d_options_get_names(options, count)

Get option names that have values.

The returned array is heap-allocated and must be freed with [`f3d_options_free_names`](@ref)().

# Arguments
* `options`: Options handle.
* `count`: Pointer to store the count of names.
# Returns
Array of option names.
"""
function f3d_options_get_names(options, count)
    ccall((:f3d_options_get_names, libf3d), Ptr{Cstring}, (Ptr{f3d_options_t}, Ptr{Csize_t}), options, count)
end

"""
    f3d_options_get_closest_option(options, option, closest, distance)

Get the closest option name and its Levenshtein distance.

# Arguments
* `options`: Options handle.
* `option`: Option name to match.
* `closest`: Output parameter for the closest option name. Caller must free with [`f3d_options_free_string`](@ref)().
* `distance`: Output parameter for the Levenshtein distance.
"""
function f3d_options_get_closest_option(options, option, closest, distance)
    ccall((:f3d_options_get_closest_option, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring, Ptr{Cstring}, Ptr{Cuint}), options, option, closest, distance)
end

"""
    f3d_options_free_names(names, count)

Free an array of option names.

# Arguments
* `names`: Array of names to free.
* `count`: Number of names in the array.
"""
function f3d_options_free_names(names, count)
    ccall((:f3d_options_free_names, libf3d), Cvoid, (Ptr{Cstring}, Csize_t), names, count)
end

"""
    f3d_options_is_optional(options, name)

Check if an option is optional.

# Arguments
* `options`: Options handle.
* `name`: Option name.
# Returns
1 if the option is optional, 0 otherwise.
"""
function f3d_options_is_optional(options, name)
    ccall((:f3d_options_is_optional, libf3d), Cint, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_reset(options, name)

Reset an option to its default value.

# Arguments
* `options`: Options handle.
* `name`: Option name.
"""
function f3d_options_reset(options, name)
    ccall((:f3d_options_reset, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_remove_value(options, name)

Remove an option value if it is optional.

# Arguments
* `options`: Options handle.
* `name`: Option name.
"""
function f3d_options_remove_value(options, name)
    ccall((:f3d_options_remove_value, libf3d), Cvoid, (Ptr{f3d_options_t}, Cstring), options, name)
end

"""
    f3d_options_parse_bool(str)

@{

` Parsing and formatting`

Parse a string as a boolean.

# Arguments
* `str`: String to parse.
# Returns
1 for true, 0 for false.
"""
function f3d_options_parse_bool(str)
    ccall((:f3d_options_parse_bool, libf3d), Cint, (Cstring,), str)
end

"""
    f3d_options_parse_int(str)

Parse a string as an integer.

# Arguments
* `str`: String to parse.
# Returns
Parsed integer value.
"""
function f3d_options_parse_int(str)
    ccall((:f3d_options_parse_int, libf3d), Cint, (Cstring,), str)
end

"""
    f3d_options_parse_double(str)

Parse a string as a double.

# Arguments
* `str`: String to parse.
# Returns
Parsed double value.
"""
function f3d_options_parse_double(str)
    ccall((:f3d_options_parse_double, libf3d), Cdouble, (Cstring,), str)
end

"""
    f3d_options_parse_string(str)

Parse a string as a string (returns a copy).

# Arguments
* `str`: String to parse.
# Returns
Parsed string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_parse_string(str)
    ccall((:f3d_options_parse_string, libf3d), Cstring, (Cstring,), str)
end

"""
    f3d_options_parse_double_vector(str, values, count)

Parse a string as a double vector.

# Arguments
* `str`: String to parse.
* `values`: Pre-allocated array to store the double values.
* `count`: Pointer to store the number of values retrieved.
"""
function f3d_options_parse_double_vector(str, values, count)
    ccall((:f3d_options_parse_double_vector, libf3d), Cvoid, (Cstring, Ptr{Cdouble}, Ptr{Csize_t}), str, values, count)
end

"""
    f3d_options_parse_int_vector(str, values, count)

Parse a string as an integer vector.

# Arguments
* `str`: String to parse.
* `values`: Pre-allocated array to store the integer values.
* `count`: Pointer to store the number of values retrieved.
"""
function f3d_options_parse_int_vector(str, values, count)
    ccall((:f3d_options_parse_int_vector, libf3d), Cvoid, (Cstring, Ptr{Cint}, Ptr{Csize_t}), str, values, count)
end

"""
    f3d_options_format_bool(value)

Format a boolean as a string.

# Arguments
* `value`: Boolean value.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_bool(value)
    ccall((:f3d_options_format_bool, libf3d), Cstring, (Cint,), value)
end

"""
    f3d_options_format_int(value)

Format an integer as a string.

# Arguments
* `value`: Integer value.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_int(value)
    ccall((:f3d_options_format_int, libf3d), Cstring, (Cint,), value)
end

"""
    f3d_options_format_double(value)

Format a double as a string.

# Arguments
* `value`: Double value.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_double(value)
    ccall((:f3d_options_format_double, libf3d), Cstring, (Cdouble,), value)
end

"""
    f3d_options_format_string(value)

Format a string (returns a copy).

# Arguments
* `value`: String value.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_string(value)
    ccall((:f3d_options_format_string, libf3d), Cstring, (Cstring,), value)
end

"""
    f3d_options_format_double_vector(values, count)

Format a double vector as a string.

# Arguments
* `values`: Array of double values.
* `count`: Number of values in the array.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_double_vector(values, count)
    ccall((:f3d_options_format_double_vector, libf3d), Cstring, (Ptr{Cdouble}, Csize_t), values, count)
end

"""
    f3d_options_format_int_vector(values, count)

Format an integer vector as a string.

# Arguments
* `values`: Array of integer values.
* `count`: Number of values in the array.
# Returns
Formatted string. Caller must free with [`f3d_options_free_string`](@ref)().
"""
function f3d_options_format_int_vector(values, count)
    ccall((:f3d_options_format_int_vector, libf3d), Cstring, (Ptr{Cint}, Csize_t), values, count)
end

"""
    f3d_utils_known_folder_t

Enumeration of supported Windows known folders.
"""
@enum f3d_utils_known_folder_t::UInt32 begin
    F3D_UTILS_KNOWN_FOLDER_ROAMINGAPPDATA = 0
    F3D_UTILS_KNOWN_FOLDER_LOCALAPPDATA = 1
    F3D_UTILS_KNOWN_FOLDER_PICTURES = 2
end

"""
    f3d_utils_text_distance(str_a, str_b)

Compute the Levenshtein distance between two strings.

# Arguments
* `str_a`: First string.
* `str_b`: Second string.
# Returns
The Levenshtein distance between the two strings.
"""
function f3d_utils_text_distance(str_a, str_b)
    ccall((:f3d_utils_text_distance, libf3d), Cuint, (Cstring, Cstring), str_a, str_b)
end

"""
    f3d_utils_tokenize(str, keep_comments, out_count)

Tokenize a string using the same logic as bash.

The returned array and strings are heap-allocated and must be freed by calling [`f3d_utils_tokens_free`](@ref)().

# Arguments
* `str`: Input string to tokenize.
* `keep_comments`: Non-zero to keep comments, zero to treat '#' as a normal character.
* `out_count`: Pointer to receive the number of tokens.
# Returns
Array of C strings.
"""
function f3d_utils_tokenize(str, keep_comments, out_count)
    ccall((:f3d_utils_tokenize, libf3d), Ptr{Cstring}, (Cstring, Cint, Ptr{Csize_t}), str, keep_comments, out_count)
end

"""
    f3d_utils_tokens_free(tokens, count)

Free an array of tokens allocated by [`f3d_utils_tokenize`](@ref)().

# Arguments
* `tokens`: Array of tokens.
* `count`: Number of tokens in the array.
"""
function f3d_utils_tokens_free(tokens, count)
    ccall((:f3d_utils_tokens_free, libf3d), Cvoid, (Ptr{Cstring}, Csize_t), tokens, count)
end

"""
    f3d_utils_collapse_path(path, base_directory)

Collapse a filesystem path.

Expands '~' to the home directory, makes the path absolute using base\\_directory or the current directory, and normalizes '..' components.

The returned string is heap-allocated and must be freed with [`f3d_utils_string_free`](@ref)().

# Arguments
* `path`: Input path.
* `base_directory`: Base directory for relative paths.
# Returns
Collapsed absolute path string.
"""
function f3d_utils_collapse_path(path, base_directory)
    ccall((:f3d_utils_collapse_path, libf3d), Cstring, (Cstring, Cstring), path, base_directory)
end

"""
    f3d_utils_glob_to_regex(glob, path_separator)

Converts a glob expression to a regular expression.

The returned string is heap-allocated and must be freed with [`f3d_utils_string_free`](@ref)().

# Arguments
* `glob`: Glob expression.
* `path_separator`: Path separator character.
# Returns
Regular expression string.
"""
function f3d_utils_glob_to_regex(glob, path_separator)
    ccall((:f3d_utils_glob_to_regex, libf3d), Cstring, (Cstring, Cchar), glob, path_separator)
end

"""
    f3d_utils_get_env(env)

Get the value of an environment variable.

The returned string is heap-allocated and must be freed with [`f3d_utils_string_free`](@ref)().

# Arguments
* `env`: Environment variable name.
# Returns
Value of the environment variable.
"""
function f3d_utils_get_env(env)
    ccall((:f3d_utils_get_env, libf3d), Cstring, (Cstring,), env)
end

"""
    f3d_utils_get_known_folder(known_folder)

Get a Windows known folder.

The returned string is heap-allocated and must be freed with [`f3d_utils_string_free`](@ref)().

# Arguments
* `known_folder`: Known folder identifier.
# Returns
Folder path.
"""
function f3d_utils_get_known_folder(known_folder)
    ccall((:f3d_utils_get_known_folder, libf3d), Cstring, (f3d_utils_known_folder_t,), known_folder)
end

"""
    f3d_utils_string_free(str)

Free a string returned by any f3d\\_utils\\_* function.

# Arguments
* `str`: String to free.
"""
function f3d_utils_string_free(str)
    ccall((:f3d_utils_string_free, libf3d), Cvoid, (Cstring,), str)
end

# no prototype is found for this function at utils_c_api.h:112:21, please use with caution
"""
    f3d_utils_get_dpi_scale()

Calculate the primary monitor system zoom scale base on DPI.

Only supported on Windows platform.

# Returns
DPI scale in double, or 1.0 on other platforms.
"""
function f3d_utils_get_dpi_scale()
    ccall((:f3d_utils_get_dpi_scale, libf3d), Cdouble, ())
end
