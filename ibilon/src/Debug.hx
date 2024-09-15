function print_document(document:Document):String {
	var output = "Title " + document.title + "\n";

	function print_node(node:Node, indentation:Int):Void {
		for (_ in 0...indentation) {
			output += "\t";
		}

		switch (node) {
			case Tag(tag, attributes, children):
				output += "<" + tag.getName().toLowerCase() + ">";

				for (name => value in attributes) {
					output += " " + name + " = " + value;
				}

				output += "\n";

				for (child in children) {
					print_node(child, indentation + 1);
				}

			case Text(text):
				output += text + "\n";
		}
	}

	for (child in document.children) {
		print_node(child, 0);
	}

	return output;
}

function print_layout(layout:Array<Block>):String {
	var output = "";

	for (block in layout) {
		output += block + "\n";
	}

	return output;
}

function print_tokens(tokens:Array<Token>):String {
	var output = "";

	for (token in tokens) {
		switch (token) {
			case TagBegin(tag, attributes):
				output += "TagBegin <" + tag.getName().toLowerCase() + ">";

				for (name => value in attributes) {
					output += "\n\tAttribute " + name + " = " + value;
				}

			case TagEnd(tag):
				output += "TagEnd </" + tag.getName().toLowerCase() + ">";

			case Text(value):
				output += "Text " + value;
		}

		output += "\n";
	}

	return output + "\n";
}
