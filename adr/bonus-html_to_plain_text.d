/+
	Bonus file showing how the parser can be used to do plain text
	conversions for html emails in terminal too. See the file
	arsd/htmltotext.d for the main conversion.

	Pipe a html file to its stdin, it spits out some plain text in stdout.
+/
module html_to_plain_text;

import arsd.htmltotext;
import arsd.dom;
import std.conv;

import std.stdio;
void main() {
	string stuff;
	foreach(line; stdin.byLine) {
		stuff ~= line ~ "\n";
	}

	auto doc = new Document;
	doc.parseGarbage("<root>" ~ stuff ~ "</root>");

	doc["head"].removeFromTree();
	doc["html, body"].stripOut();

	string[string] linksHash;
	string[] links;
	links ~= "";
	foreach(link; doc.querySelectorAll("a[href]")) {
		if(auto val = link.attrs.href in linksHash)
			link.attrs.href = *val;
		else {
			auto v = to!string(links.length);
			links ~= link.attrs.href;
			linksHash[link.attrs.href] = v;
			link.attrs.href = v;
		}
	}

	auto converter = new HtmlConverter();
	writeln(converter.convert(doc.root, true, 72));

	foreach(idx, link; links)
		if(idx == 0)
			writeln("");
		else
			writeln(idx, ": ", link);
	writeln("");
}
