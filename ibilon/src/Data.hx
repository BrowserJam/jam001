enum Block {
	Default;
	Header;
	Link(url:String);
	Row(margin:Bool);
	Text(text:String);
}

typedef Document = {
	title:String,
	children:Array<Node>,
}

enum Node {
	Tag(tag:Tag, attributes:Map<String, String>, children:Array<Node>);
	Text(text:String);
}

enum Tag {
	A;
	Dd;
	Dl;
	Dt;
	H1;
	P;
	Title;
	Unknown;
}

enum Token {
	TagBegin(tag:Tag, attributes:Map<String, String>);
	TagEnd(tag:Tag);
	Text(value:String);
}
