class_name Style

static func _copy_style(parent_style: Style) -> Style:
	var style = Style.new()
	style.font_size = parent_style.font_size
	style.text_color = parent_style.text_color
	# NOTE: Margin not inherited.
	return style

static func apply_default_style_for_element(tag_name: String, parent_style: Style) -> Style:
	var style = _copy_style(parent_style)
	match tag_name:
		'body':
			style.margin_top = 10
			style.margin_bottom = 10
			style.margin_left = 10
			style.margin_right = 10
		'h1':
			style.font_size = 30
			style.margin_top = 20
			style.margin_bottom = 20
		'a':
			style.text_color = Color.BLUE
		'p', 'dl':
			style.margin_top = 10
			style.margin_bottom = 10
		'dd':
			style.margin_left = 40
	return style

var font_size: float = 16
var text_color: Color = Color.BLACK

var margin_top: float = 0
var margin_bottom: float = 0
var margin_left: float = 0
var margin_right: float = 0
