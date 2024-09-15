class_name Token

enum Type {
	Text,
	Tag,
}

var type: Type
var text: String = ''
var tag_name: String = ''
var attributes: Dictionary = {}
var is_closing: bool = false

func _to_string() -> String:
	match type:
		Type.Text: return 'Text(%s)' % text
		Type.Tag:
			if is_closing:
				return 'ClosingTag(name=%s)' % tag_name
			else:
				return 'OpenTag(name=%s)' % tag_name
		_: return 'Unknown'
