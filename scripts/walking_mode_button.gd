extends Button

@export var walking_scene: PackedScene
@export var address_box: TextEdit

func _pressed() -> void:
	Globals.address = address_box.text
	get_tree().change_scene_to_packed(walking_scene)
