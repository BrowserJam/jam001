class Parser {
	private var current:Int;
	private var title:String;
	private var tokens:Array<Token>;

	public function new(tokens:Array<Token>) {
		this.current = 0;
		this.title = "";
		this.tokens = tokens;
	}

	private function consume():Token {
		var token = this.peek();
		this.current += 1;
		return token;
	}

	private function is_auto_closing(from:Tag, to:Tag):Bool {
		if (from == null || to == null) {
			return false;
		}

		return switch [from, to] {
			case [Dd, Dt], [Dt, Dd]:
				true;

			default:
				false;
		};
	}

	private function is_eof():Bool {
		return this.current >= this.tokens.length;
	}

	private function last():Token {
		return this.tokens[this.current - 1];
	}

	public function parse():Document {
		if (this.peek().match(TagBegin(Title, _))) {
			this.parse_title();
		}

		var children = new Array<Node>();

		while (!this.is_eof()) {
			this.parse_node(null, children);
		}

		return {
			title: this.title,
			children: children,
		};
	}

	private function parse_node(from:Tag, children:Array<Node>):Bool {
		switch (this.peek()) {
			case TagBegin(tag, attributes):
				if (this.is_auto_closing(from, tag)) {
					return false;
				}

				this.consume();
				var sub_children = new Array<Node>();

				while (!this.is_eof()) {
					if (!this.parse_node(tag, sub_children)) {
						break;
					}
				}

				children.push(Tag(tag, attributes, sub_children));

			case TagEnd(_):
				this.consume();
				return false;

			case Text(value):
				this.consume();
				children.push(Text(value));
		}

		return true;
	}

	private function parse_title():Void {
		this.consume();

		switch (this.peek()) {
			case Text(value):
				this.consume();
				this.title = value;

			default:
		}
	}

	private function peek():Token {
		return this.tokens[this.current];
	}
}
