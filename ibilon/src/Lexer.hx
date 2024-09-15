class Lexer {
	private static var TAGS = [
		"a" => A,
		"dd" => Dd,
		"dl" => Dl,
		"dt" => Dt,
		"h1" => H1,
		"p" => P,
		"title" => Title,
	];

	private var content:String;
	private var current:Int;
	private var tokens:Array<Token>;

	public function new(content:String) {
		this.content = content.replace("\n", " ");
		this.current = 0;
		this.tokens = new Array<Token>();
	}

	private function consume():Char {
		var char = this.peek();
		this.current += 1;
		return char;
	}

	private function is_eof():Bool {
		return this.current >= this.content.length;
	}

	private function last():Char {
		return Char.at(this.content, this.current - 1);
	}

	public function lex():Array<Token> {
		while (!this.is_eof()) {
			this.skip_whitespace();
			var char = this.consume();

			if (char == '<' && this.peek().is_letter()) {
				this.lex_tag_begin();
			} else if (char == '<' && this.peek() == '/') {
				this.lex_tag_end();
			} else {
				this.lex_text();
			}
		}

		return tokens;
	}

	private function lex_attribute_name():String {
		var name = "";

		while (!this.is_eof() && !(this.peek() == '=' || this.peek() == '>')) {
			name += this.consume();
		}

		this.skip_whitespace();
		return name.toLowerCase();
	}

	private function lex_attribute_value():String {
		this.skip_whitespace();
		var value = "";

		if (this.match('"')) {
			while (!this.is_eof() && !this.match('"')) {
				value += this.consume();
			}
		} else {
			while (!this.is_eof() && !(this.peek() == '>' || this.peek().is_whitespace())) {
				value += this.consume();
			}
		}

		this.skip_whitespace();
		return value;
	}

	private function lex_tag_begin():Void {
		var name = this.lex_tag_name();
		var attributes = new Map<String, String>();

		while (!this.is_eof() && !this.match('>')) {
			var name = this.lex_attribute_name();
			var value = this.match('=') ? this.lex_attribute_value() : "";
			attributes.set(name, value);
		}

		if (name != Unknown) {
			this.tokens.push(TagBegin(name, attributes));
		}
	}

	private function lex_tag_end():Void {
		this.consume(); // '/'
		var name = this.lex_tag_name();
		this.match('>');

		if (name != Unknown) {
			this.tokens.push(TagEnd(name));
		}
	}

	private function lex_tag_name():Tag {
		var name = "";

		while (!this.is_eof() && this.peek().is_identifier()) {
			name += this.consume();
		}

		this.skip_whitespace();
		name = name.toLowerCase();

		if (Lexer.TAGS.exists(name)) {
			return Lexer.TAGS.get(name);
		}

		return Unknown;
	}

	private function lex_text():Void {
		var text:String = this.last();

		while (!this.is_eof() && this.peek() != '<') {
			text += this.consume();
		}

		this.skip_whitespace();

		if (text.length > 0) {
			this.tokens.push(Text(text));
		}
	}

	private function match(char:String):Bool {
		if (this.peek() == char) {
			this.consume();
			return true;
		}

		return false;
	}

	private function peek():Char {
		return Char.at(this.content, this.current);
	}

	private function skip_whitespace():Void {
		while (!this.is_eof() && this.peek().is_whitespace()) {
			this.consume();
		}
	}
}
