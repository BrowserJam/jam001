extends Control

var start_url = "http://info.cern.ch/hypertext/WWW/TheProject.html"

var history = [start_url]
var current_history_index = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Url.grab_focus()
	%Url.text = start_url
	%Url.text_submitted.connect(func(new_text:String):
		request_url(new_text)
		)
	$VBoxContainer/Navigation/ButtonBack.pressed.connect(func():
		if current_history_index > 0:
			current_history_index -= 1
			request_url(history[current_history_index])
		)

	$HTTPRequest.request_completed.connect(self._http_request_completed)
	#request_url(%Url.text)

	%RichTextLabel.meta_clicked.connect(self._on_link_clicked)

	# EXAMPLE
	var file_path = "res://example.txt"
	var file = FileAccess.open(file_path, FileAccess.READ).get_as_text()
	print(file)
	parse_website(file)
	

func parse_website(text:String):
	# Look if there is a <title> element somewhere in the text and set the window title to its content, and remove the tag and its context from it 
	if "<title" in text.to_lower():
		get_window().title = extract_tag_content(text, "TITLE")
		text = text.replace(extract_tag_content(text, "TITLE"), "")	

	var body_content = ""
	if "<body" in text.to_lower():
		body_content = extract_tag_content(text, "BODY").replace('\n', ' ')
	else:
		body_content = text

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
				var attributes = parse_attributes(l)
				
				l = "[color='00abc7'][url='" + attributes.get('href', '#') + "']"
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


	print(final_rich_text)



func request_url(path: String) -> void:
	# History
	if path != history[current_history_index]:
		history = history.slice(0, current_history_index + 1)
		history.append(path)
		current_history_index += 1
	%Url.text = path
	
	# Clear the content before making a new request
	%RichTextLabel.text = ""
	var error = $HTTPRequest.request(path)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _http_request_completed(result, response_code, headers, body):
	print("Request completed")
	print("Response code:", response_code)
	print("Result:", result)
	print("Headers:", headers)
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


func _on_link_clicked(meta: String) -> void:
	print("Meta clicked:", meta)
	var current_url = "http://info.cern.ch/hypertext/WWW/"
	var target = current_url
	if meta.begins_with("http://"):
		target = meta
	elif meta.begins_with("/"):
		var domain = current_url.split("/")[0] + "//" + current_url.split("/")[2]
		target = domain + meta
	elif meta.begins_with("../"):
		var path_parts = current_url.split("/")
		var new_path_parts = []
		for part in path_parts:
			if part != "":
				new_path_parts.append(part)
		for _i in range(meta.count("../")):
			if new_path_parts.size() > 0:
				new_path_parts.pop_back()
		target = "/".join(new_path_parts) + "/" + meta.trim_prefix("../")
	else:
		target = current_url + meta
	# Ensure the target URL always has two '/' after 'http:'
	if not target.begins_with("http://"):
		target = target.replace("http:/", "http://")
	request_url(target)


func parse_attributes(tag_string: String) -> Dictionary:
	var result = {}
	
	# Remove < and > from the tag
	tag_string = tag_string.strip_edges().trim_prefix("<").trim_suffix(">")
	
	# Split the tag into parts
	var parts = tag_string.split(" ")
	
	# The first part is the tag name
	if parts.size() > 0:
		result["tag_name"] = parts[0].to_lower()
	
	# Process each attribute
	var current_key = ""
	var in_quote = false
	var quote_char = ''
	
	for part in parts.slice(1):  # Start from index 1 to skip the tag name
		if "=" in part and not in_quote:
			var key_value = part.split("=", true, 1)  # Split on first '=' only
			current_key = key_value[0].to_lower()
			var value = key_value[1].strip_edges()
			
			if value.begins_with("\"") or value.begins_with("'"):
				in_quote = true
				quote_char = value[0]
				value = value.substr(1)
			
			if value.ends_with(quote_char):
				in_quote = false
				value = value.substr(0, value.length() - 1)
			
			if not in_quote:
				result[current_key] = value
			else:
				result[current_key] = value + " "
		elif in_quote:
				if part.ends_with(quote_char):
					in_quote = false
					result[current_key] += part.substr(0, part.length() - 1)
				else:
					result[current_key] += part + " "
	
	# Trim any trailing spaces from attribute values
	for key in result.keys():
		if typeof(result[key]) == TYPE_STRING:
			result[key] = result[key].strip_edges()
	
	return result
