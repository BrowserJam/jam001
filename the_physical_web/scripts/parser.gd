class_name Parser

const EOF = ''

enum State {
	Text,
	TagName,
	Attribute,
	AttributeName,
	AttributeEquals,
	AttributeValueStart,
	AttributeValueUnquoted,
	AttributeValueQuoted,
	DocType,
}

var _source: String
var _state = State.Text
var _index: int = 0

var _current_token: Token
var _current_attribute_name: String = ''
var _current_attribute_value: String = ''

func _init(source: String) -> void:
	self._source = source
	self._current_token = Token.new()

func _next_char() -> String:
	if _index >= len(_source):
		return EOF
	var c = _source[_index]
	_index += 1
	return c

func _emit_token() -> Token:
	var token = _current_token
	_current_token = Token.new()
	return token

func _on_text() -> Token:
	match _next_char():
		'<':
			_state = State.TagName
			if len(_current_token.text) > 0:
				_current_token.type = Token.Type.Text
				return _emit_token()
		EOF:
			if len(_current_token.text) > 0:
				_current_token.type = Token.Type.Text
				return _emit_token()
		var c:
			_current_token.text += c
	return null

func _on_tag_name() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			_state = State.Attribute
		'/':
			_current_token.is_closing = true
		'!':
			_state = State.DocType
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_token.tag_name += c
	return null

func _on_attibute() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			pass
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_attribute_name = c
			_state = State.AttributeName
	return null

func _on_attibute_name() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			_state = State.AttributeEquals
		'=':
			_state = State.AttributeValueStart
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_attribute_name += c
	return null

func _on_attibute_equals() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			pass
		'=':
			_state = State.AttributeValueStart
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		_:
			assert(false, 'TODO')
	return null

func _on_attibute_value_start() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			pass
		'"':
			_state = State.AttributeValueQuoted
			_current_attribute_value = ''
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_attribute_value = c
			_state = State.AttributeValueUnquoted
	return null

func _on_attibute_value_quoted() -> Token:
	match _next_char():
		'"':
			_current_token.attributes[_current_attribute_name.to_lower()] = _current_attribute_value
			_state = State.Attribute
		'>':
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_attribute_value += c
	return null

func _on_attibute_value_unquoted() -> Token:
	match _next_char():
		' ', '\t', '\n', '\r':
			_current_token.attributes[_current_attribute_name.to_lower()] = _current_attribute_value
			_state = State.Attribute
		'>':
			_current_token.attributes[_current_attribute_name.to_lower()] = _current_attribute_value
			_state = State.Text
			_current_token.type = Token.Type.Tag
			return _emit_token()
		EOF:
			assert(false, 'TODO')
		var c:
			_current_attribute_value += c
	return null

func _on_doc_type() -> Token:
	match _next_char():
		'>':
			_state = State.Text
		EOF:
			assert(false, 'TODO')
	return null

func _parse_char() -> Token:
	match _state:
		State.Text: return _on_text()
		State.TagName: return _on_tag_name()
		State.Attribute: return _on_attibute()
		State.AttributeName: return _on_attibute_name()
		State.AttributeEquals: return _on_attibute_equals()
		State.AttributeValueStart: return _on_attibute_value_start()
		State.AttributeValueQuoted: return _on_attibute_value_quoted()
		State.AttributeValueUnquoted: return _on_attibute_value_unquoted()
		State.DocType: return _on_doc_type()
	return null

func next() -> Token:
	while _index < len(_source):
		var token = _parse_char()
		if token != null:
			return token
	return null
