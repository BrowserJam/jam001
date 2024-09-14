@tool
extends EditorScript

func _create_block_node(block: Layout.BlockNode) -> Node:
	var box = Control.new()
	box.name = block.dom_node.tag_name + "-" + str(randi_range(0, 1000))
	box.position = block.rect.position
	box.size = block.rect.size
	return box

func _create_text_fragment(parent: Node, fragment: Layout.TextFragment) -> Node:
	var label = Label.new()
	label.text = fragment.text
	label.name = fragment.dom_node.tag_name + "-" + str(randi_range(0, 1000))
	label.position = fragment.rect.position
	label.size = fragment.rect.size

	var style = fragment.dom_node.style
	label.set('theme_override_font_sizes/font_size', style.font_size)
	label.set('theme_override_colors/font_color', style.text_color)

	parent.add_child(label, true)
	label.set_owner(get_editor_interface().get_edited_scene_root())
	return label

func _create_block(parent: Node, block: Layout.BlockNode):
	var box = _create_block_node(block)
	parent.add_child(box, true)
	box.set_owner(get_editor_interface().get_edited_scene_root())

	for block_child in block.block_children:
		_create_block(box, block_child)
	for text_fragment in block.text_fragments:
		_create_text_fragment(box, text_fragment)

func _run() -> void:
	var file = FileAccess.open("res://TheProject.html", FileAccess.READ);
	var source = file.get_as_text()

	var parser = Parser.new(source)
	var dom_tree = DOM.build_dom_tree(parser)
	var layout_tree = Layout.build_layout_tree(dom_tree)
	layout_tree.layout(1000)
	layout_tree.debug_print()

	var document_node = get_editor_interface().get_edited_scene_root().get_node('Document')
	_create_block(document_node, layout_tree)
