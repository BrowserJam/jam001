extends Node2D

func _create_block_node(block: Layout.BlockNode) -> Node:
	var box = Control.new()
	box.name = block.dom_node.tag_name + "-" + str(randi_range(0, 1000))
	box.position = block.rect.position
	box.size = block.rect.size
	return box

func _apply_label_style(label: Label, fragment: Layout.TextFragment):
	var style = fragment.dom_node.style
	label.set('theme_override_font_sizes/font_size', style.font_size)
	label.set('theme_override_colors/font_color', style.text_color)

func _create_text_fragment_with_rigid_body(parent: Node, fragment: Layout.TextFragment) -> Node:
	var rigid_body = RigidBody2D.new()
	rigid_body.name = fragment.dom_node.tag_name + "-" + str(randi_range(0, 1000))
	rigid_body.position = fragment.rect.position
	rigid_body.input_pickable = true

	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = fragment.rect.size
	shape.translate(fragment.rect.size / 2)

	var label = Label.new()
	label.text = fragment.text
	label.size = fragment.rect.size
	_apply_label_style(label, fragment)

	rigid_body.add_child(label)
	rigid_body.add_child(shape)
	parent.add_child(rigid_body)
	return rigid_body

func _create_block(parent: Node, block: Layout.BlockNode):
	var box = _create_block_node(block)
	parent.add_child(box, true)

	for block_child in block.block_children:
		_create_block(box, block_child)
	for text_fragment in block.text_fragments:
		# _create_text_fragment(box, text_fragment)
		_create_text_fragment_with_rigid_body(box, text_fragment)

func on_refresh() -> void:
	for child in get_children():
		remove_child(child)

	var file = FileAccess.open("res://TheProject.html", FileAccess.READ);
	var source = file.get_as_text()

	var parser = Parser.new(source)
	var dom_tree = DOM.build_dom_tree(parser)
	var layout_tree = Layout.build_layout_tree(dom_tree)
	layout_tree.layout(1000)
	_create_block(self, layout_tree)

func _ready():
	on_refresh()
