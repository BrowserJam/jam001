extends CheckBox

func _wake_up_all(node: Node):
	if node is RigidBody2D:
		var body = node as RigidBody2D
		body.apply_impulse(Vector2.ZERO)
	for child in node.get_children():
		_wake_up_all(child)

func _toggled(toggled_on: bool) -> void:
	PhysicsServer2D.area_set_param(
		get_world_2d().space,
		PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR,
		Vector2(0, 1 if toggled_on else 0),
	)
	_wake_up_all(get_tree().root)
