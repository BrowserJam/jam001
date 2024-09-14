extends Node2D

@export var document: Document
@export var address_box: TextEdit
@export var enable_links: CheckBox

@export var explosion: PackedScene

var selected_body: RigidBody2D = null
var drag_position: Vector2 = Vector2.ZERO
var did_move: bool = false
var time_down

func _apply_explosive_force(node: Node, position: Vector2):
	if node is RigidBody2D:
		var body = node as RigidBody2D
		var shape = body.get_node('Shape').shape as RectangleShape2D
		var center = body.global_position + shape.size / 2
		var direction = (center - position).normalized()
		var distance = center.distance_to(position)
		var force = direction * (9999999 / (distance*distance))
		body.apply_impulse(force, center)
	for child in node.get_children():
		_apply_explosive_force(child, position)

func _explode(position: Vector2):
	var explosion = explosion.instantiate() as CPUParticles2D
	explosion.position = position
	explosion.emitting = true
	explosion.finished.connect(func (): remove_child(explosion))
	add_child(explosion)
	_apply_explosive_force(self, position)

func _on_mouse_down(event: InputEventMouseButton):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = event.position
	var result = space_state.intersect_point(query)

	if len(result) > 0:
		selected_body = result[0]['collider']
		drag_position = selected_body.global_transform.inverse() * event.position

	if event.button_index == 2:
		_explode(event.position)

	did_move = false
	time_down = Time.get_ticks_msec()

func follow_link(href: String):
	if not href.begins_with('http'):
		var address = address_box.text.strip_edges().trim_prefix('/')
		var base = '/'.join(address.split('/').slice(0, -1))
		href = base + '/' + href

	address_box.text = href
	document.on_refresh()

func _on_mouse_up(event: InputEventMouseButton):
	if selected_body == null:
		return

	if not did_move or (Time.get_ticks_msec() - time_down) < 200:
		var link = selected_body.get_node('Link')
		if link != null and enable_links.button_pressed:
			follow_link(link.href)
	selected_body = null

func _process(delta: float):
	if selected_body == null:
		return

	var mouse_position = get_viewport().get_mouse_position()
	var anchor_position = selected_body.global_transform * drag_position
	var force = mouse_position - anchor_position
	selected_body.apply_impulse(force, anchor_position - selected_body.global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			_on_mouse_down(event as InputEventMouseButton)
		else:
			_on_mouse_up(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		did_move = true
