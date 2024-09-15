class Arranger {
	private var blocks:Array<Block>;
	private var document:Document;
	private var styled:Bool;

	public function new(document:Document) {
		this.blocks = new Array<Block>();
		this.document = document;
		this.styled = false;
	}

	public function layout():Array<Block> {
		this.layout_children(this.document.children);
		return this.blocks;
	}

	private function layout_children(children:Array<Node>):Void {
		for (child in children) {
			var post_row = false;

			switch (child) {
				case Tag(tag, attributes, sub_children):
					switch (tag) {
						case A:
							this.blocks.push(Link(attributes.get("href")));
							this.styled = true;

						case Dd:
							this.blocks.push(Row(true));
							post_row = true;

						case Dl, Dt, P:
							this.blocks.push(Row(false));
							post_row = true;

						case H1:
							this.blocks.push(Row(false));
							this.blocks.push(Header);
							this.styled = true;
							post_row = true;

						default:
					}

					this.layout_children(sub_children);

					if (post_row) {
						this.blocks.push(Row(false));
					}

				case Text(text):
					this.blocks.push(Text(text));
			}

			if (this.styled) {
				this.blocks.push(Default);
				this.styled = false;
			}
		}
	}
}
