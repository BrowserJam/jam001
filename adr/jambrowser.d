/+
	Things that won't work at all rn are dynamic styles like :hover, :focus, etc.

	Replaced elements and inline blocks

	Tables.
+/

import arsd.dom;
import arsd.minigui;
import arsd.textlayouter;
import arsd.http2;

// import arsd.image;
// import arsd.script; // let's have some fun lol

int cssSizeToPixels(string cssSize, int emSize = 16, int hundredPercent = 16) {
	int unitsIdx;
	foreach(idx, char ch; cssSize) {
		if(!(ch >= '0' && ch <= '9') && ch != '.') {
			unitsIdx = cast(int) idx;
			break;
		}
	}

	if(unitsIdx == 0)
		return 0; // i don't wanna mess with it, prolly calc() or --var or something lol

	import std.conv;
	float v = to!float(cssSize[0 .. unitsIdx]);
	switch(cssSize[unitsIdx .. $]) {
		case "px":
		case "":
			return cast(int) v;
		case "em":
		case "rem":
			return cast(int) (v * emSize);
		case "%":
			return cast(int) (v * hundredPercent / 100);
		// in, cm, ch, vw, vh, golly so many css units!!!

		default:
			return cast(int) v;
	}
}

FontWeight cssWeightToSdpy(string weight) {
	switch(weight) {
		case "thin", "100": return FontWeight.thin;
		case "extralight", "200": return FontWeight.thin;
		case "light", "300": return FontWeight.thin;
		case "regular", "400": return FontWeight.thin;
		case "medium", "500": return FontWeight.thin;
		case "semibold", "600": return FontWeight.thin;
		case "bold", "700": return FontWeight.thin;
		case "extrabold", "800": return FontWeight.thin;
		case "heavy", "900": return FontWeight.thin;

		case "normal":
		default:
			return FontWeight.dontcare;
	}
}

/+
	dom.d provides a css style thing that applies a sheet,
	but it doesn't actually do the cascade nor does it give
	a space for other useful info. we're going to extend it to
	do those things.
+/
class ExtendedCssStyle : CssStyle {
	Element e;
	this(Element e) {
		this.e = e;
		super(null /* rule */, e.style);
	}

	override string getValue(string name) {
		auto got = super.getValue(name);
		if(isInheritableCss(name) && got is null && e.parentNode !is null)
			// make those styles cascade! note the recursion here will go all the way up to the root element.
			return e.parentNode.computedStyle.getValue(name);
		return got;
	}
}

bool isInheritableCss(string name) {
	switch(name) {
		case "font-size", "font-weight", "font-style", "font-family":
		case "color":
			return true;
		default: return false;
	}
}

CssStyle ourComputedStyleFactory(Element e) {
	return new ExtendedCssStyle(e);
}

class HtmlViewerWidget : Widget {
	mixin Observable!(Uri, "uri");
	// FIXME: history should also keep scroll position
	Uri[] history;
	size_t currentHistoryIndex;
	Document document;
	string source;

	string defaultStyleSheet() {
		import std.file;
		return readText("default.css");
	}

	void goBack() {
		if(currentHistoryIndex) {
			loadUri(history[--currentHistoryIndex], false);
		}
	}

	void goForward() {
		if(currentHistoryIndex + 1 < history.length) {
			loadUri(history[++currentHistoryIndex], false);
		}
	}

	void loadUri(Uri uri, bool commitHistory = true) {
		document = new Document;
		if(uri.scheme == "file") {
			import std.file;
			if(std.file.exists(uri.path))
				source = readText(uri.path);
			else
				source = "<body>File not found</body>";
		} else {
			auto req = get(uri);
			// i should prolly do this async but meh
			auto res = req.waitForCompletion();
			uri = Uri(req.finalUrl).basedOn(uri);
			source = res.contentText;
		}

		document.parseGarbage("<html>" ~ source ~ "</html>"); // if the document has a proper html tag, this adds another one but that's fairly harmless. if it doesn't, this ensures there is a single root for the parser
		if(commitHistory) {
			if(this.history.length) {
				this.history = this.history[0 .. this.currentHistoryIndex + 1];
				this.history.assumeSafeAppend();
			}
			this.history ~= uri;
			this.currentHistoryIndex = this.history.length - 1;
		}
		this.uri = uri;

		auto oldcsf = computedStyleFactory;
		computedStyleFactory = &ourComputedStyleFactory;
		scope(exit)
			computedStyleFactory = oldcsf;

		auto ss = new StyleSheet(defaultStyleSheet());
		ss.apply(document);

		hid.layoutDocument();
		this.smw.setPosition(0, 0);
		hid.redraw();
	}

	this(Widget parent) {
		smw = new ScrollMessageWidget(this);
		smw.addEventListener("scroll", () {
			hid.redraw();
		});
		hid = new HtmlInnerDisplay(this, smw);
		super(parent);
	}

	ScrollMessageWidget smw;
	HtmlInnerDisplay hid;
}

class HtmlInnerDisplay : Widget {

	static struct Block {
		TextLayouter layouter;
		Element element;

		this(TextLayouter layouter, Element element) {
			this.layouter = layouter;
			this.element = element;
			assert(layouter !is null);
			assert(element !is null);

			marginTop = cssSizeToPixels(element.computedStyle.marginTop);
			marginBottom = cssSizeToPixels(element.computedStyle.marginBottom);
			marginLeft = cssSizeToPixels(element.computedStyle.marginLeft);
			marginRight = cssSizeToPixels(element.computedStyle.marginRight);
		}

		Point origin;
		int marginTop;
		int marginBottom;
		int marginLeft;
		int marginRight;
	}

	HtmlViewerWidget hmv;
	ScrollMessageWidget smw;
	Block[] blocks;

	override void defaultEventHandler_click(ClickEvent event) {
		auto x = event.clientX;
		auto y = event.clientY;
		x += smw.position().x;
		y += smw.position().y;

		foreach_reverse(block; blocks) {
			if(block.origin.y < y) {
				// we might be in this one, time to find some text
				auto s = cast(HtmlTextStyle) block.layouter.styleAtPoint(Point(x, y) - block.origin);
				if(s !is null && s.domElement !is null) {
					auto ele = s.domElement;
					if(ele.tagName == "a" && ele.attrs.href.length) {
						if(event.button == MouseButton.left)
							hmv.loadUri(Uri(ele.attrs.href).basedOn(hmv.uri));
					}
				}
				return;
			}
		}

	}

	this(HtmlViewerWidget hmv, ScrollMessageWidget parent) {
		this.hmv = hmv;
		this.smw = parent;

		smw.addDefaultWheelListeners(16, 16, 8);
		smw.movementPerButtonClick(16, 16);
		smw.addDefaultKeyboardListeners(16, 16);

		super(parent);
	}

	static class HtmlTextStyle : TextStyle {
		static {
			OperatingSystemFont defaultFontCached;
			OperatingSystemFont defaultFont() {
				if(defaultFontCached is null) {
					defaultFontCached = new OperatingSystemFont();
					defaultFontCached.loadDefault();
				}
				return defaultFontCached;
			}

			OperatingSystemFont[string] fontCache;
			OperatingSystemFont getFont(string family, string size, string weight, string style) {
				auto key = family ~ size ~ weight ~ style;
				if(auto f = key in fontCache)
					return *f;
				auto f = new OperatingSystemFont(family, cssSizeToPixels(size), cssWeightToSdpy(weight), style == "italic");
				fontCache[key] = f;
				return f;

			}
		}

		Element domElement;
		OperatingSystemFont font_;
		Color foregroundColor = Color.black;

		this(Element domElement) {
			this.domElement = domElement;

			if(domElement !is null) {
				auto cs = domElement.computedStyle;
				font_ = getFont(cs.fontFamily, cs.fontSize, cs.fontWeight, cs.fontStyle);
				try {
					foregroundColor = Color.fromString(cs.color);
				} catch(Exception e) {
					// FIXME
				}
			}

			if(font_ is null) {
				font_ = defaultFont;
			}

		}

		override OperatingSystemFont font() {
			return font_;
		}
	}

	void layoutDocument() {
		if(hmv.document is null || hmv.document.mainBody is null)
			return;

		/+
			General plan:

			* Each block element gets its own TextLayouter instance
			* RIP floats, inline-blocks, and inline images as layouter doesn't (yet) do replaced elements :(
		+/

		blocks = null;

		layoutBlockRecursively(hmv.document.mainBody);

		recomputeChildLayout();
	}

	void layoutBlockRecursively(Element currentBlock) {
		Element currentStyleParent;
		TextLayouter.StyleHandle currentStyle;
		TextLayouter l;

		// return true if it had a surprise block in it
		bool layoutChildNode(Element parent) {
			bool hadBlock;
			foreach(element; parent.childNodes) {
				if(element.nodeType == 3) {
					if(l is null) {
						l = new TextLayouter(new HtmlTextStyle(null));
						blocks ~= Block(l, currentBlock);
					}
					if(currentStyleParent !is element.parentNode) {
						currentStyleParent = element.parentNode;
						currentStyle = l.registerStyle(new HtmlTextStyle(currentStyleParent));
					}
					assert(currentStyleParent !is null);

					l.appendText(normalizeWhitespace(element.nodeValue, false), currentStyle);
				} else {
					if(element.computedStyle.display == "block") {
						layoutBlockRecursively(element);
						// we're back to this block, but treat it like a new one again
						currentStyleParent = null;
						l = null;
						hadBlock = true;
					} else {
						if(layoutChildNode(element)) {
							// surprise block in there
							currentStyleParent = null;
							l = null;
							hadBlock = true;
						}
					}
				}
			}
			return hadBlock;
		}

		layoutChildNode(currentBlock);
	}

	enum padding = 4;
	override void recomputeChildLayout() {
		Point origin = Point(padding, padding);
		int previousMargin = 0;
		foreach(ref block; blocks) {
			auto marginToUse = (block.marginTop > previousMargin) ? block.marginTop : previousMargin;

			origin.y += marginToUse;

			block.layouter.wordWrapWidth = this.width - padding - padding - block.marginLeft - block.marginRight;

			block.origin = origin;
			block.origin.x = block.marginLeft;
			origin.y += block.layouter.height();
			previousMargin = block.marginBottom;
		}

		this.smw.setTotalArea(this.width, origin.y);
		this.smw.setViewableArea(this.width, this.height);
	}

	override void paint(WidgetPainter painter) {
		foreach(block; blocks)
		block.layouter.getDrawableText(delegate bool(txt, styleIn, info, carets...) {
			if(styleIn is null)
				return true;
			auto style = cast(HtmlTextStyle) styleIn;
			assert(style !is null);

			painter.setFont(style.font);

			if(info.selections && info.boundingBox.width > 0) {
				auto color = this.isFocused ? Color(0, 0, 128) : Color(128, 128, 128); // FIXME don't hardcode
				painter.fillColor = color;
				painter.outlineColor = color;
				painter.drawRectangle(Rectangle(info.boundingBox.upperLeft - smw.position() + block.origin, info.boundingBox.size));
				painter.outlineColor = Color.white;
			} else {
				painter.outlineColor = style.foregroundColor;
			}


			import std.string;
			if(txt.strip.length) {
				painter.drawText(info.boundingBox.upperLeft - smw.position() + block.origin, txt.stripRight);
			}

			if(info.boundingBox.upperLeft.y - smw.position().y + block.origin.y > this.height) {
				return false;
			} else {
				return true;
			}
		});
	}
}

class AddressBarButton : Button {
	this(string label, Widget parent) {
		super(label, parent);
	}

	override int maxWidth() {
		return scaleWithDpi(24);
	}
}

class AddressBarWidget : Widget {
	Button back;
	Button forward;
	Button stop;
	Button reload;
	LineEdit url;
	Button go;
	this(BrowserWidget parent) {
		auto hl = new HorizontalLayout(this);
		back = new AddressBarButton("<", hl);
		back.addWhenTriggered(() { parent.Back(); });
		forward = new AddressBarButton(">", hl);
		forward.addWhenTriggered(() { parent.Forward(); });
		stop = new AddressBarButton("X", hl);
		reload = new AddressBarButton("R", hl);
		reload.addWhenTriggered(() { parent.Reload(); });
		url = new LineEdit(hl);
		go = new AddressBarButton("Go", hl);
		go.addWhenTriggered(() { parent.Open(url.content); });

		url.addEventListener((DoubleClickEvent ev) {
			url.selectAll();
			ev.preventDefault();
		});

		url.addEventListener((CharEvent ke) {
			if(ke.character == '\n') {
				auto event = new Event("triggered", go);
				event.dispatch();
				ke.preventDefault();
			}
		});

		super(parent);
		this.tabStop = false;
	}

	override int maxHeight() {
		return scaleWithDpi(24);
	}
}


class BrowserWidget : Widget {
	AddressBarWidget ab;
	HtmlViewerWidget hvw;

	this(Widget parent) {
		ab = new AddressBarWidget(this);
		hvw = new HtmlViewerWidget(this);
		hvw.uri_changed = u => ab.url.content = u;
		super(parent);
		this.tabStop = false;
	}

	@menu("&File") {
		void Open(string url) {
			hvw.loadUri(Uri(url));
		}

		@accelerator("Alt+Left")
		void Back() {
			hvw.goBack();
		}

		@accelerator("Alt+Right")
		void Forward() {
			hvw.goForward();
		}

		@accelerator("F5")
		void Reload() {
			hvw.loadUri(hvw.uri, false);
		}

		@accelerator("Ctrl+W")
		void Quit() {
			this.parentWindow.close();
		}
	}

	@menu("&Edit") {

	}

	@menu("&View") {
		@accelerator("Ctrl+U")
		void ViewSource() {
			auto window = new Window();
			auto td = new TextDisplay(hvw.source, window);
			window.show();
		}

		void ViewDomTree() {
			if(hvw.document is null) {
				messageBox("No document is currently loaded.");
			} else {
				auto window = new Window();
				auto td = new TextDisplay(hvw.document.toPrettyString(), window);
				window.show();
			}
		}
	}
	@menu("&Help") {
		void About() {
			messageBox("lol made for a browser jam");
		}
	}
}

void main() {
	auto window = new MainWindow("Browser Jam");
	auto bw = new BrowserWidget(window);
	window.setMenuAndToolbarFromAnnotatedCode(bw);

	bw.Open("file:///home/me/TheProject.html");

	window.loop();
}
