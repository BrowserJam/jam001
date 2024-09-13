extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Url.grab_focus()
	%Url.text = "http://info.cern.ch/hypertext/WWW/TheProject.html"
	%Url.text_submitted.connect(func(new_text:String):
		request_url(new_text)
		)

	$HTTPRequest.request_completed.connect(self._http_request_completed)
	request_url(%Url.text)


func request_url(path: String) -> void:
	# Clear the content before making a new request
	for c in %Content.get_children():
		c.queue_free()
	var error = $HTTPRequest.request(path)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _http_request_completed(result, response_code, headers, body):
	var text = body.get_string_from_utf8()
	# print(text)
	get_window().title = extract_tag_content(extract_tag_content(text, "HEADER"), "TITLE")
	var body_content = extract_tag_content(text, "BODY").replace('\n', ' ')
	print(body_content)
	var n = RichTextLabel.new()
	n.fit_content = true
	n.set('theme_override_colors/default_color', Color(0, 0, 0))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.text = body_content
	n.set("size_flags_horizontal", Control.SIZE_EXPAND_FILL)
	%Content.add_child(n) # Add the label to the VBoxContainer


func extract_tag_content(html_string: String, tag: String) -> String:
	# Convert both the HTML string and the tag to lowercase for case-insensitive matching
	var lower_html = html_string.to_lower()
	var lower_tag = tag.to_lower()

	var start_tag = "<" + lower_tag
	var end_tag = "</" + lower_tag + ">"

	var start_index = lower_html.find(start_tag)
	if start_index == -1:
		return ""  # Start tag not found

	# Find the closing '>' for the start tag
	start_index = lower_html.find(">", start_index)
	if start_index == -1:
		return ""  # Malformed start tag

	start_index += 1  # Move past the '>'

	var end_index = lower_html.find(end_tag, start_index)
	if end_index == -1:
		return ""  # End tag not found

	# Extract the content using the original HTML string to preserve original case
	return html_string.substr(start_index, end_index - start_index)
