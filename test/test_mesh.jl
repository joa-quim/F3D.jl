function test_mesh()
	println("Testing F3D Mesh C API...")

	# Create engine
	engine = F3D.f3d_engine_create(0)
	if engine == C_NULL
		println("[ERROR] Failed to create engine")
		return 1
	end
	println("✓ Created engine")

	F3D.f3d_log_set_verbose_level(F3D.F3D_LOG_DEBUG, 0)
	F3D.f3d_engine_autoload_plugins()

	# Get scene
	scene = F3D.f3d_engine_get_scene(engine)
	if scene == C_NULL
		println("[ERROR] Failed to get scene")
		F3D.f3d_engine_delete(engine)
		return 1
	end
	println("✓ Got scene")

	F3D.f3d_scene_add(scene,joinpath(@__DIR__, "cow.vtp"))

	# Get interactor
	interactor = F3D.f3d_engine_get_interactor(engine)
	if interactor == C_NULL
		println("[ERROR] Failed to get interactor")
		F3D.f3d_engine_delete(engine)
		return 1
	end
	
	F3D.f3d_interactor_start(interactor, 1.0 / 30.0) 

end