function test_mesh_pts()
	# Create engine
	engine = F3D.f3d_engine_create(0)
	if engine == C_NULL
		println("[ERROR] Failed to create engine")
		return 1
	end
	println("✓ Created engine")

	#F3D.f3d_log_set_verbose_level(F3D.F3D_LOG_DEBUG, 0)
	F3D.f3d_engine_autoload_plugins()

	# Get scene
	scene = F3D.f3d_engine_get_scene(engine)
	if scene == C_NULL
		println("[ERROR] Failed to get scene")
		F3D.f3d_engine_delete(engine)
		return 1
	end
	println("✓ Got scene")

	points = Float32[ 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0 ] 
	normals = Float32[ 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1 ]
	texcoords = Float32[ 0, 0, 0, 1, 1, 0, 1, 1 ]
	sides = UInt32[ 3, 3 ]
	faces = UInt32[ 0, 1, 2, 1, 3, 2 ]
	GC.@preserve points normals texcoords sides faces begin
	# Test mesh from memory
	mesh = Ref(F3D.f3d_mesh_t(
	           Base.unsafe_convert(Ptr{Float32}, points), 12,
	           #Base.unsafe_convert(Ptr{Float32}, normals), 12,
	           C_NULL, 0,
	           #Base.unsafe_convert(Ptr{Float32}, texcoords), 8,
	           C_NULL, 0,
	           #Base.unsafe_convert(Ptr{UInt32}, sides), 2,
	           Base.unsafe_convert(Ptr{UInt32}, UInt32[]), 0,
	           #Base.unsafe_convert(Ptr{UInt32}, faces), 6
	           Base.unsafe_convert(Ptr{UInt32}, UInt32[]), 0,
	           ))
	end
	F3D.f3d_scene_add_mesh(scene, mesh)

	# Get interactor
	interactor = F3D.f3d_engine_get_interactor(engine)
	if interactor == C_NULL
		println("[ERROR] Failed to get interactor")
		F3D.f3d_engine_delete(engine)
		return 1
	end
	
	F3D.f3d_interactor_start(interactor, 1.0 / 30.0) 

end