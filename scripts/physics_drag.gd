extends Node2D

@export var document: Document
@export var address_box: TextEdit
@export var enable_links: CheckBox

var selected_body: RigidBody2D = null
var drag_position: Vector2 = Vector2.ZERO

func _on_mouse_down(event: InputEventMouseButton):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = event.position
	var result = space_state.intersect_point(query)

	if len(result) > 0:
		selected_body = result[0]['collider']
		drag_position = selected_body.global_transform.inverse() * event.position

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
