import Sys.print;
import sys.io.File;

enum Mode {
	Document;
	Layout;
	Normal;
	Tokens;
}

function main():Void {
	switch (Sys.args()) {
		case []:
			print("Usage: java -jar browser.jar file.html [option]\n\n");
			print("Options:\n");
			print("    --tokens    Debug print the tokens and stop\n");
			print("    --document  Debug print the document and stop\n");
			print("    --layout    Debug print the layout and stop\n");

		case [path]:
			run(path, Normal);

		case [path, option]:
			var mode = switch (option) {
				case "--document":
					Document;

				case "--layout":
					Layout;

				case "--tokens":
					Tokens;

				default:
					print("Unknown option: " + option + "\n");
					Normal;
			};

			run(path, mode);
	}
}

function run(path:String, mode:Mode):Void {
	var file = File.getContent(path);
	var tokens = new Lexer(file).lex();

	if (mode == Tokens) {
		print(Debug.print_tokens(tokens));
		return;
	}

	var document = new Parser(tokens).parse();

	if (mode == Document) {
		print(Debug.print_document(document));
		return;
	}

	var layout = new Arranger(document).layout();

	if (mode == Layout) {
		print(Debug.print_layout(layout));
		return;
	}

	Ui.render(document.title, layout);
}
