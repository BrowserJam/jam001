extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Url.grab_focus()
	%Url.text = "http://info.cern.ch/hypertext/WWW/TheProject.html"
	#%Url.text_submitted.connect(func(new_text:String):
	#	request_url(new_text)
	#	)

	#$HTTPRequest.request_completed.connect(self._http_request_completed)
	#request_url(%Url.text)

	# EXAMPLE
	var file_path = "res://example.txt"
	var file = FileAccess.open(file_path, FileAccess.READ).get_as_text()
	print(file)
	parse_website(file)
	

func parse_website(text:String):
	get_window().title = extract_tag_content(extract_tag_content(text, "HEADER"), "TITLE")
	var body_content = extract_tag_content(text, "BODY").replace('\n', ' ')
	# print(body_content)
	print(tokenize(body_content))

	var final_rich_text :String = ""
	var is_title = false
	var is_paragraph = false
	var is_link = false
	var is_dd = false

	for l in tokenize(body_content):
		if "</a>" in l.to_lower():
			if is_link:
				l = "[/url][/color]"
				final_rich_text += l
				is_link = false
		elif "</" in l and ">" in l:
			# Closing tags
			if is_title:
				l = "[/b][/font_size]\n\n" 
				final_rich_text += l
				is_title = false
			if is_paragraph:
				l = "\n"
				final_rich_text += l
				is_paragraph = false
			
			
		elif "<" in l and ">" in l:
			# Starting tags
			if "h1" in l.to_lower():
				is_title = true
				l = "[font_size=30][b]"
				final_rich_text += l
			if "<p>" in l.to_lower():
				is_paragraph = true
				l = "\n\n"
				final_rich_text += l
			if "dl" in l.to_lower():
				is_paragraph = false
				l = "\n"
				final_rich_text += l
			if "a " in l.to_lower():
				l = "[color='00abc7'][url]"
				is_link = true
				final_rich_text += l
			if "dt" in l.to_lower():
				l = "\n"
				final_rich_text += l
			if "dd" in l.to_lower():
				l = "\n[indent]"
				final_rich_text += l
				is_dd = true

		else:
			# Regular text
			final_rich_text += l

		if is_dd:
			l = "[/indent]"
			final_rich_text += l
			is_dd = false
	
	# Ugly removing of empty white characters at the start of lines:
	final_rich_text = final_rich_text.replace("\n ", "\n") # this probably should trim start of lines instead of this, but I can do it later™

	var n = %RichTextLabel
	n.fit_content = true
	n.bbcode_enabled = true
	n.selection_enabled = true
	n.set('theme_override_colors/default_color', Color(0, 0, 0))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.text = final_rich_text
	n.set("size_flags_horizontal", Control.SIZE_EXPAND_FILL)
	%Content.add_child(n) # Add the label to the VBoxContainer


	print(final_rich_text)



func request_url(path: String) -> void:
	# Clear the content before making a new request
	for c in %Content.get_children():
		c.queue_free()
	var error = $HTTPRequest.request(path)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _http_request_completed(_result, _response_code, _headers, body):
	parse_website(body.get_string_from_utf8())



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


func tokenize(html_string: String) -> Array:
	var lines = []
	var current_line = ""
	var in_tag = false
	var in_quote = false
	var quote_char = ''

	for c in html_string:
		if c == '<' and not in_quote:
			if current_line.strip_edges() != "":
				lines.append(current_line)
				current_line = ""
			in_tag = true
			current_line += c
		elif c == '>' and not in_quote:
			current_line += c
			lines.append(current_line)
			current_line = ""
			in_tag = false
		elif c in ['"', "'"] and in_tag:
			if not in_quote:
				in_quote = true
				quote_char = c
			elif c == quote_char:
				in_quote = false
			current_line += c
		elif c == '\n' and not in_tag:
			if current_line.strip_edges() != "":
				lines.append(current_line)
				current_line = ""
		else:
			current_line += c

	# Add any remaining content
	if current_line.strip_edges() != "":
		lines.append(current_line)

	return lines
