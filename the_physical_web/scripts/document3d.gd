extends Node3D

@export var http_request: HTTPRequest
@export var player: Player

const SCALE = 0.2
const TEXT_BIAS = 0.01

var current_address: String

func _create_block_node(block: Layout.BlockNode) -> Node3D:
	var box = Node3D.new()
	box.name = block.dom_node.tag_name + "-" + str(randi_range(0, 1000))
	box.position = Vector3(block.rect.position.x * SCALE, 0, block.rect.position.y * SCALE)
	return box

func _apply_text(text: Label3D, fragment: Layout.TextFragment):
	text.text = fragment.text
	text.font_size = fragment.dom_node.style.font_size * SCALE * 200
	text.modulate = fragment.dom_node.style.text_color
	text.shaded = true
	text.double_sided = false

func _create_text_fragment_mesh(parent: Node, fragment: Layout.TextFragment):
	var box = MeshInstance3D.new()
	box.name = 'Mesh'
	box.mesh = BoxMesh.new()
	box.mesh.size = Vector3(fragment.rect.size.x * SCALE, fragment.rect.size.y * SCALE, fragment.rect.size.y * SCALE)
	parent.add_child(box)

	var text_front = Label3D.new()
	_apply_text(text_front, fragment)
	text_front.position.z = fragment.rect.size.y * SCALE / 2 + TEXT_BIAS
	box.add_child(text_front)

	var text_back = Label3D.new()
	_apply_text(text_back, fragment)
	text_back.position.z = -fragment.rect.size.y * SCALE / 2 - TEXT_BIAS
	text_back.rotate(Vector3(0, 1, 0), deg_to_rad(180))
	box.add_child(text_back)

	var text_top = Label3D.new()
	_apply_text(text_top, fragment)
	text_top.position.y = fragment.rect.size.y * SCALE / 2 + TEXT_BIAS
	text_top.rotate(Vector3(1, 0, 0), deg_to_rad(-90))
	box.add_child(text_top)

	var text_bottom = Label3D.new()
	_apply_text(text_bottom, fragment)
	text_bottom.position.y = -fragment.rect.size.y * SCALE / 2 - TEXT_BIAS
	text_bottom.rotate(Vector3(1, 0, 0), deg_to_rad(90))
	box.add_child(text_bottom)

func _create_text_fragment(parent: Node, fragment: Layout.TextFragment):
	var size = Vector3(fragment.rect.size.x * SCALE, fragment.rect.size.y * SCALE, fragment.rect.size.y * SCALE)

	var rigid_body = RigidBody3D.new()
	rigid_body.position = Vector3(fragment.rect.position.x * SCALE, 0, fragment.rect.position.y * SCALE) + size / 2
	rigid_body.mass = 0.1
	parent.add_child(rigid_body)

	var shape = CollisionShape3D.new()
	shape.name = 'Shape'
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	rigid_body.add_child(shape)

	if fragment.dom_node.tag_name == 'a' and 'href' in fragment.dom_node.attributes:
		var link = Link.new()
		link.name = 'Link'
		link.href = fragment.dom_node.attributes['href']
		rigid_body.add_child(link)

	_create_text_fragment_mesh(rigid_body, fragment)

func _create_block(parent: Node, block: Layout.BlockNode) -> Node3D:
	var box = _create_block_node(block)
	parent.add_child(box, true)

	for block_child in block.block_children:
		_create_block(box, block_child)
	for text_fragment in block.text_fragments:
		_create_text_fragment(box, text_fragment)
	return box

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var source = body.get_string_from_utf8()

	var parser = Parser.new(source)
	var dom_tree = DOM.build_dom_tree(parser)
	var layout_tree = Layout.build_layout_tree(dom_tree)
	layout_tree.layout(1000)
	_create_block(self, layout_tree)

func _load_page(address: String):
	for child in get_children():
		remove_child(child)

	print('Load ', address)
	http_request.cancel_request()
	http_request.request(address)
	current_address = address

func on_refresh() -> void:
	_load_page(Globals.address)

func _on_link_collided(link: Link):
	var href = link.href
	if not href.begins_with('http'):
		var address = current_address.strip_edges().trim_prefix('/')
		var base = '/'.join(address.split('/').slice(0, -1))
		href = base + '/' + href
	_load_page(href)

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	player.on_link_collided.connect(_on_link_collided)
	on_refresh()
