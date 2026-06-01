# Julia port of F3D's TestSDKSceneFromMemory.cxx
#
# The C++ test relies on f3d::scene::load_failure_exception being thrown when an
# invalid mesh is added. The C API has no exceptions: f3d_mesh_is_valid validates
# a mesh and returns 0 (invalid) or 1 (valid), filling an error message string.
# So invalid-mesh cases assert is_valid == 0, the valid case asserts == 1, adds it
# to the scene and renders.

using Test
using F3D

# Build an f3d_mesh_t from Julia arrays and run f3d_mesh_is_valid on it.
# Empty arrays are passed as C_NULL / count 0. Returns (valid::Cint, message::String).
function _check_mesh(points, normals, texcoords, sides, faces)
    pts = Float32.(points)
    nrm = Float32.(normals)
    tex = Float32.(texcoords)
    sds = UInt32.(sides)
    fcs = UInt32.(faces)

    GC.@preserve pts nrm tex sds fcs begin
        mesh = Ref(F3D.f3d_mesh_t(
            isempty(pts) ? C_NULL : pointer(pts), Csize_t(length(pts)),
            isempty(nrm) ? C_NULL : pointer(nrm), Csize_t(length(nrm)),
            isempty(tex) ? C_NULL : pointer(tex), Csize_t(length(tex)),
            isempty(sds) ? C_NULL : pointer(sds), Csize_t(length(sds)),
            isempty(fcs) ? C_NULL : pointer(fcs), Csize_t(length(fcs)),
        ))

        err = Ref{Cstring}(C_NULL)
        valid = F3D.f3d_mesh_is_valid(mesh, err)
        msg = err[] == C_NULL ? "" : unsafe_string(err[])
        err[] != C_NULL && F3D.f3d_utils_string_free(err[])
        return valid, msg
    end
end

@testset "Scene from memory" begin
    F3D.f3d_engine_autoload_plugins()

    engine = F3D.f3d_engine_create(Cint(1))
    @test engine != C_NULL

    scene = F3D.f3d_engine_get_scene(engine)
    @test scene != C_NULL

    window = F3D.f3d_engine_get_window(engine)
    @test window != C_NULL
    F3D.f3d_window_set_size(window, Cint(300), Cint(300))

    # Optional texture (matches C++ eng.getOptions().model.color.texture)
    options = F3D.f3d_engine_get_options(engine)
    texpath = joinpath(@__DIR__, "data", "world.png")
    isfile(texpath) && F3D.f3d_options_set_as_string(options, "model.color.texture", texpath)

    # --- Invalid meshes: f3d_mesh_is_valid must return 0 ---

    @testset "invalid number of points" begin
        valid, _ = _check_mesh(
            [0, 0, 0, 0, 1, 0, 1, 0],   # 8 floats, not a multiple of 3
            [], [], [3], [0, 1, 2])
        @test valid == 0
    end

    @testset "empty points" begin
        valid, _ = _check_mesh([], [], [], [], [])
        @test valid == 0
    end

    @testset "invalid number of cell indices" begin
        valid, _ = _check_mesh(
            [0, 0, 0, 0, 1, 0, 1, 0, 0],
            [], [], [3], [0, 1, 2, 3])   # 4 indices, sides sum to 3
        @test valid == 0
    end

    @testset "invalid vertex index" begin
        valid, _ = _check_mesh(
            [0, 0, 0, 0, 1, 0, 1, 0, 0],
            [], [], [3], [0, 1, 4])      # index 4 >= 3 points
        @test valid == 0
    end

    @testset "invalid normals" begin
        valid, _ = _check_mesh(
            [0, 0, 0, 0, 1, 0, 1, 0, 0],
            [1],                          # normals don't match points
            [], [3], [0, 1, 2, 4])
        @test valid == 0
    end

    @testset "invalid texture coordinates" begin
        valid, _ = _check_mesh(
            [0, 0, 0, 0, 1, 0, 1, 0, 0],
            [], [1],                      # texcoords don't match points
            [3], [0, 1, 2, 4])
        @test valid == 0
    end

    # --- Valid mesh: add from memory and render ---

    @testset "add mesh from memory" begin
        points    = Float32[0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0]
        normals   = Float32[0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1]
        texcoords = Float32[0, 0, 0, 1, 1, 0, 1, 1]
        sides     = UInt32[3, 3]
        faces     = UInt32[0, 1, 2, 1, 3, 2]

        valid, msg = _check_mesh(points, normals, texcoords, sides, faces)
        @test valid == 1
        @test isempty(msg)

        GC.@preserve points normals texcoords sides faces begin
            mesh = Ref(F3D.f3d_mesh_t(
                pointer(points), Csize_t(length(points)),
                pointer(normals), Csize_t(length(normals)),
                pointer(texcoords), Csize_t(length(texcoords)),
                pointer(sides), Csize_t(length(sides)),
                pointer(faces), Csize_t(length(faces)),
            ))
            @test F3D.f3d_scene_add_mesh(scene, mesh) == 1
        end
    end

    @testset "render mesh from memory" begin
        F3D.f3d_window_render(window)
        img = F3D.f3d_window_render_to_image(window, Cint(0))
        @test img != C_NULL
        if img != C_NULL
            @test F3D.f3d_image_get_width(img) == 300
            @test F3D.f3d_image_get_height(img) == 300
            F3D.f3d_image_delete(img)
        end
    end

    F3D.f3d_engine_delete(engine)
end
