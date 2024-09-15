class_name Layout

const CHAR_SIZE = 10

const BLOCK_NODES = [
	'body',
	'h1',
	'p',
	'address',

	'dl',
	'dt',
	'dd',
	
	'ul',
	'li',
]

const NON_LAYOUT_NODES = [
	'title',
]

static func _text_size(text: String, style: Style) -> Vector2:
	var font = Label.new().get_theme_default_font()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.font_size)

class InlineNode:
	var text: String
	var dom_node: DOM.DomNode

	func _init(dom_node: DOM.DomNode):
		self.dom_node = dom_node
		self.text = dom_node.inner_text()

	func debug_print(indent: int = 0):
		print(' '.repeat(indent*4) + 'InlineNode')

class TextFragment:
	var dom_node: DOM.DomNode
	var text: String
	var rect: Rect2

	func _init(dom_node: DOM.DomNode, text: String, rect: Rect2):
		self.dom_node = dom_node
		self.text = text
		self.rect = rect

class BlockNode:
	var block_children: Array[BlockNode]
	var inline_children: Array[InlineNode]
	var text_fragments: Array[TextFragment]

	var rect: Rect2
	var dom_node: DOM.DomNode

	func _init(dom_node: DOM.DomNode):
		self.dom_node = dom_node
		self.block_children = []
		self.inline_children = []
		self.text_fragments = []

	func are_children_inline():
		return len(inline_children) > 0

	func _layout_block(max_width: float):
		for child in block_children:
			var style = child.dom_node.style
			child.layout(max_width - style.margin_left - style.margin_right)

		var y = 0
		for child in block_children:
			var style = child.dom_node.style
			y += style.margin_top
			child.rect.position.x = style.margin_left
			child.rect.position.y = y
			y += child.rect.size.y
			y += style.margin_bottom
			rect = rect.merge(child.rect)

	func _layout_inline(max_width: float):
		text_fragments = []

		var x = 0
		var y = 0
		var line_height = 0
		for child in inline_children:
			var style = child.dom_node.style
			var fragment_rect = Rect2(x, y, 0, 0)
			var fragment_text = ''

			var words = child.text.split(' ')
			for i in range(len(words)):
				var word = words[i]
				if i != len(words) - 1:
					word += ' '

				var word_size = Layout._text_size(word, style)
				if x + word_size.x > max_width:
					var fragment = TextFragment.new(child.dom_node, fragment_text, fragment_rect)
					text_fragments.append(fragment)

					x = 0
					y += line_height
					line_height = 0

					fragment_text = ''
					fragment_rect = Rect2(x, y, 0, 0)

				fragment_rect.size.x += word_size.x
				fragment_rect.size.y = max(fragment_rect.size.y, word_size.y)
				fragment_text += word

				x += word_size.x
				line_height = max(line_height, word_size.y)

			var fragment = TextFragment.new(child.dom_node, fragment_text, fragment_rect)
			text_fragments.append(fragment)
			x += 1.5 # Space width
		rect.size.x = x
		rect.size.y = y + line_height

	func layout(max_width: float):
		if are_children_inline():
			_layout_inline(max_width)
		else:
			_layout_block(max_width)

	func debug_print(indent: int = 0):
		print(' '.repeat(indent*4) + 'BlockNode rect=' + str(rect))
		for child in block_children:
			child.debug_print(indent + 1)
		for child in inline_children:
			child.debug_print(indent + 1)

static func _inline_children_to_block(block: BlockNode):
	var inline_block = BlockNode.new(DOM.DomNode.new('INLINE', {}, Style.new()))
	inline_block.inline_children = block.inline_children
	block.inline_children = []
	block.block_children.append(inline_block)
	
static func _build_layout_tree_block(dom_node: DOM.DomNode) -> BlockNode:
	var block = BlockNode.new(dom_node)
	for child in dom_node.children:
		if child.tag_name in BLOCK_NODES:
			if len(block.inline_children) > 0:
				_inline_children_to_block(block)
			block.block_children.append(_build_layout_tree_block(child))
			continue

		if child.tag_name in NON_LAYOUT_NODES:
			continue

		if child.tag_name == 'TEXT' and len(child.text.strip_edges()) == 0:
			continue # Ignore whitespace text.
		block.inline_children.append(InlineNode.new(child))

	if len(block.block_children) > 0 and len(block.inline_children) > 0:
		_inline_children_to_block(block)

	return block

static func build_layout_tree(dom: DOM.DomNode) -> BlockNode:
	var body = dom.find('body')
	if body == null:
		body = dom

	return _build_layout_tree_block(body)
