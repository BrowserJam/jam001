class_name DOM

const SELF_CLOSING_TAGS = [
	'nextid'
]

static func _text_for_rendering(text: String) -> String:
	var result = ''
	var in_whitespace = false
	for c in text:
		if c in [' ', '\t', '\n', '\r']:
			if not in_whitespace:
				result += ' '
			in_whitespace = true
		else:
			result += c
			in_whitespace = false
	return result.strip_edges()

class DomNode:
	var tag_name: String
	var attributes: Dictionary
	var style: Style
	var text: String
	var children: Array[DomNode]

	func _init(tag_name: String, attributes: Dictionary, parent_style: Style):
		self.tag_name = tag_name
		self.attributes = attributes
		self.style = Style.apply_default_style_for_element(tag_name, parent_style)

	func add_child(child: DomNode):
		children.append(child)
	
	func inner_text():
		var result = text
		for child in children:
			result += child.text
		return DOM._text_for_rendering(result)

	func find(of_tag_name: String) -> DomNode:
		if tag_name == of_tag_name:
			return self
		for child in children:
			var found = child.find(of_tag_name)
			if found != null:
				return found
		return null

	func debug_print(indent: int = 0):
		print(' '.repeat(indent * 4) + tag_name)
		for child in children:
			child.debug_print(indent + 1)

static func _should_auto_close(tag_name: String, top_of_stack: String) -> bool:
	const BLOCK = ['p', 'dl']
	const DESCRIPTION_LIST_ITEM = ['dt', 'dd']

	if tag_name in BLOCK and top_of_stack in BLOCK:
		return true
	if tag_name in DESCRIPTION_LIST_ITEM and top_of_stack in DESCRIPTION_LIST_ITEM:
		return true
	return false

static func build_dom_tree(parser: Parser) -> DomNode:
	var root = DomNode.new('root', {}, Style.new())
	var stack: Array[DomNode] = [root]

	while true:
		var token = parser.next()
		if token == null:
			break

		var top_of_stack = stack[len(stack) - 1]
		var tag_name = token.tag_name.to_lower()

		if token.type == Token.Type.Text:
			var text_node = DomNode.new('TEXT', {}, top_of_stack.style)
			text_node.text = token.text
			top_of_stack.add_child(text_node)
			continue

		if token.type == Token.Type.Tag and not token.is_closing:
			if _should_auto_close(tag_name, top_of_stack.tag_name):
				stack.pop_back()
				top_of_stack = stack[len(stack) - 1]

			var node = DomNode.new(tag_name, token.attributes, top_of_stack.style)
			top_of_stack.add_child(node)
			if not tag_name in SELF_CLOSING_TAGS:
				stack.append(node)
			continue

		if token.type == Token.Type.Tag and token.is_closing:
			if top_of_stack.tag_name != tag_name:
				print('Closing wrong tag ' + tag_name + ' insead of ' + top_of_stack.tag_name)
			stack.pop_back()
			continue
	return root
