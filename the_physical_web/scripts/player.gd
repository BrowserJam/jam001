class_name Player
extends CharacterBody3D

signal on_link_collided(link: Link)

const GRAVITY_MULTIPLYER = 5.0

const BOB_HEIGHT = 0.02
const BOB_SIDE = 0.04
const BOB_SPEED = 4.0

@export var speed = 180.0
@export var gravity = -9.8
@export var friction = Vector3(0.4, 1, 0.4)
@export var jump_height = 0.0

@export var mouse_sensitivity = 0.007

@export var step_sounds: Array[AudioStream]
@export var min_step_sound_speed = 0.1
@export var step_sound_time = 0.5
var step_timer: float = 0

@onready var camera = $Camera3D
@onready var camera_origin = camera.transform.origin
var bob_time: float = 0.0
var bob_damper: float = 0.0

var in_link_grace: bool = false
var time_of_last_link_collision: int = 0

func _ready():
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_link_collided(link: Link):
	var time_since = Time.get_ticks_msec() - time_of_last_link_collision
	if time_since > 3000:
		on_link_collided.emit(link)

	time_of_last_link_collision = Time.get_ticks_msec()

func _physics_process(delta):
	var forward_axis = Input.get_axis('Back', 'Forward')
	var side_axis = Input.get_axis('Right', 'Left')

	var speed_multiplier = 1
	if Input.is_action_pressed("Run"):
		speed_multiplier = 10

	var force = Vector3(0, gravity * GRAVITY_MULTIPLYER, 0)
	force += transform.basis.z * forward_axis * speed * speed_multiplier
	force += transform.basis.x * side_axis * speed * speed_multiplier
	
	if jump_height > 0 and is_on_floor() and Input.is_action_just_pressed('Jump'):
		force += Vector3(0, jump_height, 0)

	velocity += force * delta
	move_and_slide()
	velocity *= friction

	for index in get_slide_collision_count():
		var collider = get_slide_collision(index).get_collider()
		if collider is RigidBody3D:
			var rigid_body = collider as RigidBody3D
			if rigid_body.has_node('Link'):
				_on_link_collided(rigid_body.get_node('Link') as Link)

	if is_on_floor():
		_bob_camera(delta)

func _input(event):
	if event is InputEventMouseMotion:
		var motion = event.relative * -mouse_sensitivity
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x + rad_to_deg(motion.y), -90, 90)
		rotate_y(motion.x)
	
	if event.is_action('Exit'):
		get_tree().change_scene_to_file('res://document.tscn')

func _bob_camera(delta: float):
	var movement_speed = Vector3(velocity.x, 0, velocity.z).length()
	if bob_damper > movement_speed:
		bob_damper -= delta * 20.0
		bob_damper = max(bob_damper, movement_speed)
	elif bob_damper < movement_speed:
		bob_damper += delta * 5.0
		bob_damper = min(bob_damper, movement_speed)

	var bob_offset = Vector3(sin(bob_time * 0.5) * BOB_SIDE, sin(bob_time) * BOB_HEIGHT, 0)
	camera.transform.origin = camera_origin + bob_offset * bob_damper
	camera.rotation_degrees.z = sin(bob_time * 0.5) * 0.1 * bob_damper
	bob_time += delta * bob_damper * BOB_SPEED
