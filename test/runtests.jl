using Test
using F3D

# All ccall-wrapped functions and types are available via F3D since libf3d.jl is included there.

@testset "F3D C API Tests" begin

# ============================================================
# test_utils_c_api
# ============================================================
@testset "Utils" begin
    @test F3D.f3d_utils_text_distance("kitten", "sitting") == 3
    @test F3D.f3d_utils_text_distance("same", "same") == 0

    # tokenize
    cmd = "one two \"three four\" # comment"
    tok_count = Ref{Csize_t}(0)
    tokens_ptr = F3D.f3d_utils_tokenize(cmd, Cint(1), tok_count)
    @test tokens_ptr != C_NULL
    @test tok_count[] == 3
    tok_strings = unsafe_wrap(Array, tokens_ptr, tok_count[])
    @test unsafe_string(tok_strings[1]) == "one"
    @test unsafe_string(tok_strings[2]) == "two"
    @test unsafe_string(tok_strings[3]) == "three four"
    F3D.f3d_utils_tokens_free(tokens_ptr, tok_count[])

    # collapse_path
    collapsed = F3D.f3d_utils_collapse_path(".", C_NULL)
    @test collapsed != C_NULL
    @test length(unsafe_string(collapsed)) > 0
    F3D.f3d_utils_string_free(collapsed)

    # glob_to_regex
    regex = F3D.f3d_utils_glob_to_regex("*.txt", Cchar('/'))
    @test regex != C_NULL
    @test length(unsafe_string(regex)) > 0
    F3D.f3d_utils_string_free(regex)

    # get_env
    env_val = F3D.f3d_utils_get_env("PATH")
    @test env_val != C_NULL
    F3D.f3d_utils_string_free(env_val)

    # get_known_folder (platform-specific)
    if Sys.iswindows()
        kf = F3D.f3d_utils_get_known_folder(F3D.F3D_UTILS_KNOWN_FOLDER_ROAMINGAPPDATA)
        @test kf != C_NULL
        @test length(unsafe_string(kf)) > 0
        F3D.f3d_utils_string_free(kf)
    else
        kf = F3D.f3d_utils_get_known_folder(F3D.F3D_UTILS_KNOWN_FOLDER_ROAMINGAPPDATA)
        @test kf == C_NULL
    end
end

# ============================================================
# test_types_c_api
# ============================================================
@testset "Types" begin
    # Color
    color = Ref(F3D.f3d_color_t((0.0, 0.0, 0.0)))
    F3D.f3d_color_set(color, 1.0, 0.5, 0.25)
    @test F3D.f3d_color_r(color) == 1.0
    @test F3D.f3d_color_g(color) == 0.5
    @test F3D.f3d_color_b(color) == 0.25

    # Direction
    dir = Ref(F3D.f3d_direction_t((0.0, 0.0, 0.0)))
    F3D.f3d_direction_set(dir, 1.0, 0.0, 0.0)
    @test F3D.f3d_direction_x(dir) == 1.0
    @test F3D.f3d_direction_y(dir) == 0.0
    @test F3D.f3d_direction_z(dir) == 0.0

    # Transform2D
    transform = Ref(F3D.f3d_transform2d_t(ntuple(_ -> 0.0, 9)))
    F3D.f3d_transform2d_create(transform, 1.0, 1.0, 10.0, 20.0, 45.0)

    # Colormap free with empty colormap
    cmap = Ref(F3D.f3d_colormap_t(C_NULL, 0))
    F3D.f3d_colormap_free(cmap)
    @test true
end

# ============================================================
# test_log_c_api
# ============================================================
@testset "Log" begin
    initial_level = F3D.f3d_log_get_verbose_level()

    F3D.f3d_log_set_verbose_level(F3D.F3D_LOG_DEBUG, Cint(0))
    @test F3D.f3d_log_get_verbose_level() == F3D.F3D_LOG_DEBUG

    F3D.f3d_log_set_verbose_level(F3D.F3D_LOG_QUIET, Cint(0))
    @test F3D.f3d_log_get_verbose_level() == F3D.F3D_LOG_QUIET

    F3D.f3d_log_set_verbose_level(initial_level, Cint(0))

    # Coloring toggle
    F3D.f3d_log_set_use_coloring(Cint(1))
    F3D.f3d_log_set_use_coloring(Cint(0))

    # Print at various levels (with quiet so nothing goes to output)
    saved = F3D.f3d_log_get_verbose_level()
    F3D.f3d_log_set_verbose_level(F3D.F3D_LOG_QUIET, Cint(0))
    F3D.f3d_log_print(F3D.F3D_LOG_DEBUG, "Test debug message")
    F3D.f3d_log_print(F3D.F3D_LOG_INFO, "Test info message")
    F3D.f3d_log_print(F3D.F3D_LOG_WARN, "Test warning message")
    F3D.f3d_log_print(F3D.F3D_LOG_ERROR, "Test error message")
    F3D.f3d_log_set_verbose_level(saved, Cint(0))

    # Null message should not crash
    F3D.f3d_log_debug(C_NULL)
    F3D.f3d_log_info(C_NULL)
    F3D.f3d_log_warn(C_NULL)
    F3D.f3d_log_error(C_NULL)

    F3D.f3d_log_forward(C_NULL)
    @test true
end

# ============================================================
# test_engine_c_api
# ============================================================
@testset "Engine" begin
    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    scene = F3D.f3d_engine_get_scene(engine)
    @test scene != C_NULL

    options = F3D.f3d_engine_get_options(engine)
    @test options != C_NULL

    window = F3D.f3d_engine_get_window(engine)
    interactor = F3D.f3d_engine_get_interactor(engine)

    F3D.f3d_engine_set_cache_path(engine, "/tmp/f3d_test_cache")

    F3D.f3d_engine_autoload_plugins()
    F3D.f3d_engine_load_plugin("native")

    backends = F3D.f3d_engine_get_rendering_backend_list(C_NULL)
    F3D.f3d_engine_free_backend_list(backends)

    # Lib info
    lib_info = F3D.f3d_engine_get_lib_info()
    @test lib_info != C_NULL
    info = unsafe_load(lib_info)
    @test info.version != C_NULL
    @test info.vtk_version != C_NULL
    F3D.f3d_engine_free_lib_info(lib_info)

    # Readers info
    reader_count = Ref{Cint}(0)
    readers = F3D.f3d_engine_get_readers_info(reader_count)
    @test readers != C_NULL
    @test reader_count[] > 0
    F3D.f3d_engine_free_readers_info(readers)

    # Set options roundtrip
    new_options = F3D.f3d_engine_get_options(engine)
    F3D.f3d_engine_set_options(engine, new_options)

    # Engine with no window
    engine_none = F3D.f3d_engine_create_none()
    if engine_none != C_NULL
        F3D.f3d_engine_delete(engine_none)
    end

    F3D.f3d_engine_delete(engine)
    @test true
end

# ============================================================
# test_options_c_api
# ============================================================
@testset "Options" begin
    standalone = F3D.f3d_options_create()
    F3D.f3d_options_delete(standalone)

    engine = F3D.f3d_engine_create_none()
    @test engine != C_NULL

    options = F3D.f3d_engine_get_options(engine)
    @test options != C_NULL

    # Set various types
    F3D.f3d_options_set_as_bool(options, "model.scivis.cells", Cint(1))
    F3D.f3d_options_set_as_int(options, "model.scivis.component", Cint(2))
    F3D.f3d_options_set_as_double(options, "render.line_width", 3.5)
    F3D.f3d_options_set_as_string(options, "render.effect.final_shader", "test.glsl")

    vec_values = Cdouble[1.0, 2.0, 3.0]
    F3D.f3d_options_set_as_double_vector(options, "render.background.color", vec_values, Csize_t(3))

    int_vec_values = Cint[1, 2]
    F3D.f3d_options_set_as_int_vector(options, "scene.animation.indices", int_vec_values, Csize_t(2))

    # Get various types
    @test F3D.f3d_options_get_as_bool(options, "model.scivis.cells") == 1
    @test F3D.f3d_options_get_as_int(options, "model.scivis.component") == 2
    @test F3D.f3d_options_get_as_double(options, "render.line_width") == 3.5

    str_val = F3D.f3d_options_get_as_string(options, "render.effect.final_shader")
    if str_val != C_NULL
        F3D.f3d_options_free_string(str_val)
    end

    out_vec = zeros(Cdouble, 3)
    out_count = Ref{Csize_t}(0)
    F3D.f3d_options_get_as_double_vector(options, "render.background.color", out_vec, out_count)

    out_int_vec = zeros(Cint, 3)
    out_int_count = Ref{Csize_t}(0)
    F3D.f3d_options_get_as_int_vector(options, "scene.animation.indices", out_int_vec, out_int_count)

    # Toggle
    F3D.f3d_options_toggle(options, "model.scivis.cells")

    # Copy / is_same
    engine2 = F3D.f3d_engine_create_none()
    if engine2 != C_NULL
        options2 = F3D.f3d_engine_get_options(engine2)
        if options2 != C_NULL
            F3D.f3d_options_is_same(options, options2, "model.scivis.cells")
            F3D.f3d_options_copy(options2, options, "model.scivis.cells")
        end
        F3D.f3d_engine_delete(engine2)
    end

    # has_value
    F3D.f3d_options_has_value(options, "model.scivis.cells")

    # get_all_names
    all_count = Ref{Csize_t}(0)
    all_names = F3D.f3d_options_get_all_names(all_count)
    if all_names != C_NULL
        F3D.f3d_options_free_names(all_names, all_count[])
    end

    # get_names
    names_count = Ref{Csize_t}(0)
    names = F3D.f3d_options_get_names(options, names_count)
    if names != C_NULL
        F3D.f3d_options_free_names(names, names_count[])
    end

    # is_optional
    F3D.f3d_options_is_optional(options, "render.show_edges")

    # reset / remove_value
    F3D.f3d_options_reset(options, "model.scivis.cells")
    F3D.f3d_options_remove_value(options, "render.show_edges")

    # String representation
    str_repr = F3D.f3d_options_get_as_string_representation(options, "render.line_width")
    if str_repr != C_NULL
        F3D.f3d_options_free_string(str_repr)
    end
    F3D.f3d_options_set_as_string_representation(options, "render.line_width", "5.0")

    # Closest option
    closest = Ref{Cstring}(C_NULL)
    distance = Ref{Cuint}(0)
    F3D.f3d_options_get_closest_option(options, "render.line_wdth", closest, distance)
    if closest[] != C_NULL
        F3D.f3d_options_free_string(closest[])
    end

    # Parse functions
    @test F3D.f3d_options_parse_bool("true") == 1
    @test F3D.f3d_options_parse_int("42") == 42
    @test F3D.f3d_options_parse_double("3.14") ≈ 3.14

    parsed_string = F3D.f3d_options_parse_string("test")
    if parsed_string != C_NULL
        F3D.f3d_options_free_string(parsed_string)
    end

    parsed_dvec = zeros(Cdouble, 3)
    parsed_dvec_count = Ref{Csize_t}(0)
    F3D.f3d_options_parse_double_vector("1.0,2.0,3.0", parsed_dvec, parsed_dvec_count)

    parsed_ivec = zeros(Cint, 3)
    parsed_ivec_count = Ref{Csize_t}(0)
    F3D.f3d_options_parse_int_vector("1,2,3", parsed_ivec, parsed_ivec_count)

    # Format functions
    fmt_bool = F3D.f3d_options_format_bool(Cint(1))
    fmt_bool != C_NULL && F3D.f3d_options_free_string(fmt_bool)

    fmt_int = F3D.f3d_options_format_int(Cint(42))
    fmt_int != C_NULL && F3D.f3d_options_free_string(fmt_int)

    fmt_double = F3D.f3d_options_format_double(3.14)
    fmt_double != C_NULL && F3D.f3d_options_free_string(fmt_double)

    fmt_string = F3D.f3d_options_format_string("test")
    fmt_string != C_NULL && F3D.f3d_options_free_string(fmt_string)

    fmt_dvec_vals = Cdouble[1.0, 2.0, 3.0]
    fmt_dvec_str = F3D.f3d_options_format_double_vector(fmt_dvec_vals, Csize_t(3))
    fmt_dvec_str != C_NULL && F3D.f3d_options_free_string(fmt_dvec_str)

    fmt_ivec_vals = Cint[1, 2, 3]
    fmt_ivec_str = F3D.f3d_options_format_int_vector(fmt_ivec_vals, Csize_t(3))
    fmt_ivec_str != C_NULL && F3D.f3d_options_free_string(fmt_ivec_str)

    F3D.f3d_engine_delete(engine)
    @test true
end

# ============================================================
# test_image_c_api
# ============================================================
@testset "Image" begin
    img_empty = F3D.f3d_image_new_empty()
    if img_empty != C_NULL
        F3D.f3d_image_delete(img_empty)
    end

    img = F3D.f3d_image_new_params(UInt32(800), UInt32(600), UInt32(3), F3D.BYTE)
    @test img != C_NULL

    @test F3D.f3d_image_get_width(img) == 800
    @test F3D.f3d_image_get_height(img) == 600
    @test F3D.f3d_image_get_channel_count(img) == 3
    F3D.f3d_image_get_channel_type(img)
    F3D.f3d_image_get_channel_type_size(img)

    content = F3D.f3d_image_get_content(img)
    if content != C_NULL
        F3D.f3d_image_set_content(img, content)
    end

    pixel = zeros(Cdouble, 3)
    F3D.f3d_image_get_normalized_pixel(img, UInt32(0), UInt32(0), pixel)

    # Metadata
    F3D.f3d_image_set_metadata(img, "Author", "TestUser")
    author = F3D.f3d_image_get_metadata(img, "Author")
    @test author != C_NULL

    meta_count = Ref{Cuint}(0)
    metadata_keys = F3D.f3d_image_all_metadata(img, meta_count)
    if metadata_keys != C_NULL
        F3D.f3d_image_free_metadata_keys(metadata_keys, meta_count[])
    end

    # Compare with reference
    ref_img = F3D.f3d_image_new_params(UInt32(800), UInt32(600), UInt32(3), F3D.BYTE)
    if ref_img != C_NULL
        F3D.f3d_image_compare(img, ref_img)
        @test F3D.f3d_image_equals(img, ref_img) == 1
        @test F3D.f3d_image_not_equals(img, ref_img) == 0
        F3D.f3d_image_delete(ref_img)
    end

    # Save to buffer
    buf_size = Ref{Cuint}(0)
    buffer = F3D.f3d_image_save_buffer(img, F3D.PNG, buf_size)
    if buffer != C_NULL
        F3D.f3d_image_free_buffer(buffer)
    end

    # Save to file and reload
    tmp_path = joinpath(tempdir(), "f3d_test_image.png")
    F3D.f3d_image_save(img, tmp_path, F3D.PNG)
    img_from_file = F3D.f3d_image_new_path(tmp_path)
    if img_from_file != C_NULL
        F3D.f3d_image_delete(img_from_file)
    end
    rm(tmp_path; force=true)

    # Supported formats
    @test F3D.f3d_image_get_supported_formats_count() > 0

    # Different channel count
    img2 = F3D.f3d_image_new_params(UInt32(100), UInt32(100), UInt32(4), F3D.BYTE)
    if img2 != C_NULL
        F3D.f3d_image_delete(img2)
    end

    F3D.f3d_image_delete(img)
    @test true
end

# ============================================================
# test_window_c_api
# ============================================================
@testset "Window" begin
    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    window = F3D.f3d_engine_get_window(engine)
    @test window != C_NULL

    wtype = F3D.f3d_window_get_type(window)
    offscreen = F3D.f3d_window_is_offscreen(window)
    camera = F3D.f3d_window_get_camera(window)

    F3D.f3d_window_render(window)

    img = F3D.f3d_window_render_to_image(window, Cint(0))
    if img != C_NULL
        F3D.f3d_image_delete(img)
    end

    F3D.f3d_window_set_size(window, Cint(800), Cint(600))
    @test F3D.f3d_window_get_width(window) == 800
    @test F3D.f3d_window_get_height(window) == 600

    F3D.f3d_window_set_position(window, Cint(100), Cint(100))

    icon_data = UInt8[0xFF, 0xFF, 0xFF, 0xFF]
    F3D.f3d_window_set_icon(window, icon_data, Cuint(sizeof(icon_data)))

    F3D.f3d_window_set_window_name(window, "Test Window")

    # Coordinate conversions (use Cdouble arrays since ccall expects Ptr{Cdouble})
    display_point = Cdouble[400.0, 300.0, 0.0]
    world_point = zeros(Cdouble, 3)
    F3D.f3d_window_get_world_from_display(window, display_point, world_point)

    test_world = Cdouble[0.0, 0.0, 0.0]
    display_out = zeros(Cdouble, 3)
    F3D.f3d_window_get_display_from_world(window, test_world, display_out)

    F3D.f3d_engine_delete(engine)
    @test true
end

# ============================================================
# test_camera_c_api
# ============================================================
@testset "Camera" begin
    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    window = F3D.f3d_engine_get_window(engine)
    @test window != C_NULL

    camera = F3D.f3d_window_get_camera(window)
    @test camera != C_NULL

    # Position (ccall expects Ptr{Cdouble}, so use arrays)
    pos = Cdouble[1.0, 2.0, 3.0]
    F3D.f3d_camera_set_position(camera, pos)
    get_pos = zeros(Cdouble, 3)
    F3D.f3d_camera_get_position(camera, get_pos)

    # Focal point
    focal = Cdouble[0.0, 0.0, 0.0]
    F3D.f3d_camera_set_focal_point(camera, focal)
    get_focal = zeros(Cdouble, 3)
    F3D.f3d_camera_get_focal_point(camera, get_focal)

    # View up
    view_up = Cdouble[0.0, 1.0, 0.0]
    F3D.f3d_camera_set_view_up(camera, view_up)
    get_view_up = zeros(Cdouble, 3)
    F3D.f3d_camera_get_view_up(camera, get_view_up)

    # View angle
    F3D.f3d_camera_set_view_angle(camera, 30.0)
    angle = F3D.f3d_camera_get_view_angle(camera)

    # Camera state (struct with NTuple fields - Ref works here)
    state = Ref(F3D.f3d_camera_state_t(
        (5.0, 5.0, 5.0),   # position
        (0.0, 0.0, 0.0),   # focal_point
        (0.0, 1.0, 0.0),   # view_up
        45.0                # view_angle
    ))
    F3D.f3d_camera_set_state(camera, state)
    get_state = Ref(F3D.f3d_camera_state_t(
        (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 0.0
    ))
    F3D.f3d_camera_get_state(camera, get_state)

    # Camera movements
    F3D.f3d_camera_dolly(camera, 1.5)
    F3D.f3d_camera_pan(camera, 0.1, 0.2, 0.3)
    F3D.f3d_camera_zoom(camera, 0.9)
    F3D.f3d_camera_roll(camera, 10.0)
    F3D.f3d_camera_azimuth(camera, 15.0)
    F3D.f3d_camera_yaw(camera, 20.0)
    F3D.f3d_camera_elevation(camera, 25.0)
    F3D.f3d_camera_pitch(camera, 30.0)

    F3D.f3d_camera_set_current_as_default(camera)
    F3D.f3d_camera_reset_to_default(camera)
    F3D.f3d_camera_reset_to_bounds(camera, 0.9)

    F3D.f3d_engine_delete(engine)
    @test true
end

# ============================================================
# test_scene_c_api
# ============================================================
@testset "Scene" begin
    F3D.f3d_engine_autoload_plugins()

    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    scene = F3D.f3d_engine_get_scene(engine)
    @test scene != C_NULL

    # supports
    F3D.f3d_scene_supports(scene, "test.obj")

    # Add a mesh
    points = Cfloat[0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5, 1.0, 0.0]
    face_sides = Cuint[3]
    face_indices = Cuint[0, 1, 2]

    GC.@preserve points face_sides face_indices begin
        mesh = Ref(F3D.f3d_mesh_t(
            pointer(points), Csize_t(9),
            C_NULL, Csize_t(0),
            C_NULL, Csize_t(0),
            pointer(face_sides), Csize_t(1),
            pointer(face_indices), Csize_t(3)
        ))

        error_msg = Ref{Cstring}(C_NULL)
        valid = F3D.f3d_mesh_is_valid(mesh, error_msg)
        @test valid == 1
        if error_msg[] != C_NULL
            F3D.f3d_utils_string_free(error_msg[])
        end

        F3D.f3d_scene_add_mesh(scene, mesh)
    end

    F3D.f3d_scene_clear(scene)

    # Animation
    F3D.f3d_scene_load_animation_time(scene, 0.5)
    min_time = Ref{Cdouble}(0.0)
    max_time = Ref{Cdouble}(0.0)
    F3D.f3d_scene_animation_time_range(scene, min_time, max_time)
    F3D.f3d_scene_available_animations(scene)

    # Lights
    light_state = Ref(F3D.f3d_light_state_t(
        F3D.F3D_LIGHT_TYPE_HEADLIGHT,
        (0.0, 0.0, 0.0),
        F3D.f3d_color_t((1.0, 1.0, 1.0)),
        (0.0, 0.0, -1.0),
        Cint(0), 1.0, Cint(1)
    ))

    light_idx = F3D.f3d_scene_add_light(scene, light_state)
    @test F3D.f3d_scene_get_light_count(scene) >= 1

    if light_idx >= 0
        get_light = F3D.f3d_scene_get_light(scene, light_idx)
        if get_light != C_NULL
            F3D.f3d_light_state_free(get_light)
        end

        update_light = Ref(F3D.f3d_light_state_t(
            F3D.F3D_LIGHT_TYPE_HEADLIGHT,
            (0.0, 0.0, 0.0),
            F3D.f3d_color_t((1.0, 1.0, 1.0)),
            (0.0, 0.0, -1.0),
            Cint(0), 2.0, Cint(1)
        ))
        F3D.f3d_scene_update_light(scene, light_idx, update_light)
        F3D.f3d_scene_remove_light(scene, light_idx)
    end

    # Light state equality
    light1 = Ref(F3D.f3d_light_state_t(
        F3D.F3D_LIGHT_TYPE_HEADLIGHT,
        (0.0, 0.0, 0.0), F3D.f3d_color_t((1.0, 1.0, 1.0)),
        (0.0, 0.0, -1.0), Cint(0), 1.0, Cint(0)
    ))
    light2 = Ref(F3D.f3d_light_state_t(
        F3D.F3D_LIGHT_TYPE_CAMERA_LIGHT,
        (0.0, 0.0, 0.0), F3D.f3d_color_t((1.0, 1.0, 1.0)),
        (0.0, 0.0, -1.0), Cint(0), 1.0, Cint(0)
    ))
    @test F3D.f3d_light_state_equal(light1, light2) == 0

    F3D.f3d_scene_remove_all_lights(scene)

    F3D.f3d_engine_delete(engine)
    @test true
end

# ============================================================
# test_interactor_c_api
# ============================================================
@testset "Interactor" begin
    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    window = F3D.f3d_engine_get_window(engine)
    if window != C_NULL
        F3D.f3d_window_render(window)
    end

    interactor = F3D.f3d_engine_get_interactor(engine)
    @test interactor != C_NULL

    # Animation controls
    F3D.f3d_interactor_toggle_animation(interactor, F3D.F3D_INTERACTOR_ANIMATION_FORWARD)
    F3D.f3d_interactor_start_animation(interactor, F3D.F3D_INTERACTOR_ANIMATION_BACKWARD)
    F3D.f3d_interactor_is_playing_animation(interactor)
    F3D.f3d_interactor_get_animation_direction(interactor)
    F3D.f3d_interactor_stop_animation(interactor)

    # Camera movement
    F3D.f3d_interactor_enable_camera_movement(interactor)
    F3D.f3d_interactor_disable_camera_movement(interactor)

    # Input triggers
    F3D.f3d_interactor_trigger_mod_update(interactor, F3D.F3D_INTERACTOR_INPUT_CTRL)
    F3D.f3d_interactor_trigger_mouse_button(interactor, F3D.F3D_INTERACTOR_INPUT_PRESS, F3D.F3D_INTERACTOR_MOUSE_LEFT)
    F3D.f3d_interactor_trigger_mouse_button(interactor, F3D.F3D_INTERACTOR_INPUT_RELEASE, F3D.F3D_INTERACTOR_MOUSE_RIGHT)
    F3D.f3d_interactor_trigger_mouse_position(interactor, 100.0, 200.0)
    F3D.f3d_interactor_trigger_mouse_wheel(interactor, F3D.F3D_INTERACTOR_WHEEL_FORWARD)
    F3D.f3d_interactor_trigger_mouse_wheel(interactor, F3D.F3D_INTERACTOR_WHEEL_BACKWARD)
    F3D.f3d_interactor_trigger_keyboard_key(interactor, F3D.F3D_INTERACTOR_INPUT_PRESS, "a")
    F3D.f3d_interactor_trigger_keyboard_key(interactor, F3D.F3D_INTERACTOR_INPUT_RELEASE, "b")
    F3D.f3d_interactor_trigger_text_character(interactor, Cuint(65))

    F3D.f3d_interactor_trigger_event_loop(interactor, 0.016)

    F3D.f3d_interactor_request_render(interactor)
    F3D.f3d_interactor_request_stop(interactor)

    # Commands
    F3D.f3d_interactor_init_commands(interactor)
    F3D.f3d_interactor_trigger_command(interactor, "print Test", Cint(0))
    F3D.f3d_interactor_trigger_command(interactor, "print Test # comment", Cint(1))

    # Bindings
    F3D.f3d_interactor_init_bindings(interactor)

    F3D.f3d_interactor_add_command(interactor, "test_action", C_NULL, C_NULL)
    action_count = Ref{Cint}(0)
    actions = F3D.f3d_interactor_get_command_actions(interactor, action_count)
    if actions != C_NULL
        F3D.f3d_interactor_free_string_array(actions, action_count[])
    end

    # Bind formatting/parsing
    bind = Ref(F3D.f3d_interaction_bind_t(
        F3D.F3D_INTERACTION_BIND_NONE,
        ntuple(i -> i == 1 ? Cchar('t') : Cchar(0), 256)
    ))
    formatted = zeros(UInt8, 512)
    F3D.f3d_interaction_bind_format(bind, pointer(formatted), Cint(512))

    ctrl_bind = Ref(F3D.f3d_interaction_bind_t(
        F3D.F3D_INTERACTION_BIND_CTRL,
        ntuple(i -> i == 1 ? Cchar('A') : Cchar(0), 256)
    ))
    F3D.f3d_interaction_bind_format(ctrl_bind, pointer(formatted), Cint(512))

    parsed_bind = Ref(F3D.f3d_interaction_bind_t(
        F3D.F3D_INTERACTION_BIND_NONE,
        ntuple(_ -> Cchar(0), 256)
    ))
    F3D.f3d_interaction_bind_parse("Shift+B", parsed_bind)

    F3D.f3d_interaction_bind_equals(ctrl_bind, parsed_bind)
    F3D.f3d_interaction_bind_less_than(ctrl_bind, parsed_bind)

    # Add binding
    cmd_str = "test_action"
    GC.@preserve cmd_str begin
        test_commands = Cstring[Base.unsafe_convert(Cstring, cmd_str)]
        F3D.f3d_interactor_add_binding(interactor, bind, pointer(test_commands), Csize_t(1), "test_group")
    end

    group_count = Ref{Cint}(0)
    groups = F3D.f3d_interactor_get_bind_groups(interactor, group_count)
    if groups != C_NULL
        F3D.f3d_interactor_free_string_array(groups, group_count[])
    end

    bind_count = Ref{Cint}(0)
    binds_for_group = F3D.f3d_interactor_get_binds_for_group(interactor, "test_group", bind_count)
    if binds_for_group != C_NULL
        F3D.f3d_interactor_free_bind_array(binds_for_group)
    end

    all_bind_count = Ref{Cint}(0)
    all_binds = F3D.f3d_interactor_get_binds(interactor, all_bind_count)
    if all_binds != C_NULL
        F3D.f3d_interactor_free_bind_array(all_binds)
    end

    doc = Ref(F3D.f3d_binding_documentation_t(
        ntuple(_ -> Cchar(0), 512),
        ntuple(_ -> Cchar(0), 256)
    ))
    F3D.f3d_interactor_get_binding_documentation(interactor, bind, doc)
    F3D.f3d_interactor_get_binding_type(interactor, bind)

    F3D.f3d_interactor_remove_binding(interactor, bind)

    # start_with_callback using a stop callback
    stop_cb = @cfunction(function(user_data::Ptr{Cvoid})
        F3D.f3d_interactor_request_stop(Ptr{F3D.f3d_interactor_t}(user_data))
        return nothing
    end, Cvoid, (Ptr{Cvoid},))
    F3D.f3d_interactor_start_with_callback(interactor, 0.01, stop_cb, Ptr{Cvoid}(interactor))

    F3D.f3d_engine_delete(engine)
    @test true
end

end  # top-level testset
