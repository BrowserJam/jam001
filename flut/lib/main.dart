import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String theSite = '''

''';

void main() {
  runApp(MaterialApp(
    home: HTMLRendererApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class HTMLRendererApp extends StatefulWidget {
  @override
  _HTMLRendererAppState createState() => _HTMLRendererAppState();
}

class _HTMLRendererAppState extends State<HTMLRendererApp> {
  final TextEditingController _urlController = TextEditingController( text: 'https://info.cern.ch/');
  String? _htmlContent;
  Uri? _baseUri;
  bool _isLoading = false;
  List<Uri> _history = [];
  int _currentHistoryIndex = -1;

  @override
  void initState() {
    super.initState();
    // Set initial content and base URL
    _htmlContent = theSite;
    _baseUri = Uri.parse('https://info.cern.ch/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flut Browser'),
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _canGoBack() ? _goBack : null,
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: _canGoForward() ? _goForward : null,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAddressBar(),
          Expanded(
            child: Stack(
              children: [
                _htmlContent != null
                    ? SingleChildScrollView(
                        child: HTMLRendererWidget(
                          html: _htmlContent!,
                          onUrlTap: (url) => _handleLinkTap(url),
                        ),
                      )
                    : const Center(child: Text('Enter a URL and press "Go"')),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                // Loading spinner
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'Enter URL',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _fetchHtmlContent,
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHtmlContent() async {
    final url = _urlController.text;
    if (url.isNotEmpty) {
      try {
        setState(() {
          _isLoading = true; // Show loading indicator
        });

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          setState(() {
            _htmlContent = response.body;
            _baseUri = Uri.parse(url);
            _addToHistory(_baseUri!);
          });
        } else {
          setState(() {
            _htmlContent = 'Failed to load page: ${response.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _htmlContent = 'Failed to load page: $e';
        });
      } finally {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  void _handleLinkTap(String url) {
    final resolvedUrl = _resolveUrl(url);
      _fetchAndRender(resolvedUrl);
  }

  Uri _resolveUrl(String url) {
    try {
      final parsedUrl = Uri.parse(url);
      if (parsedUrl.hasScheme && parsedUrl.hasAuthority) {
        return parsedUrl;
      }

      if (_baseUri == null) {
        final currentAddressBarUrl = _urlController.text;
        if (currentAddressBarUrl.isNotEmpty) {
          _baseUri = Uri.parse(currentAddressBarUrl);
        } else {
          throw ArgumentError(
              'Base URL is not set, and no URL found in address bar.');
        }
      }

      final resolvedUri = _baseUri!.resolveUri(parsedUrl);
      return resolvedUri;
    } catch (e) {
      print('Error parsing or resolving URL: $e');
      return Uri();
    }
  }

  Future<void> _openLinkInNewTab(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print('Could not launch $url');
    }
  }

  Future<void> _fetchAndRender(Uri url) async {
    try {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _htmlContent = response.body;
          _baseUri = url;
          _addToHistory(url);
        });
      } else {
        print('Failed to fetch page: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to fetch page: $e');
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _addToHistory(Uri uri) {
    if (_currentHistoryIndex == -1 ||
        _history.isEmpty ||
        _history[_currentHistoryIndex] != uri) {
      if (_currentHistoryIndex < _history.length - 1) {
        _history = _history.sublist(
            0, _currentHistoryIndex + 1); // Trim forward history
      }
      _history.add(uri);
      _currentHistoryIndex++;
      _urlController.text = uri.toString(); // Update address bar
    }
  }

  bool _canGoBack() => _currentHistoryIndex > 0;

  bool _canGoForward() => _currentHistoryIndex < _history.length - 1;

  void _goBack() {
    if (_canGoBack()) {
      _currentHistoryIndex--;
      final previousUri = _history[_currentHistoryIndex];
      _fetchAndRender(previousUri);
    }
  }

  void _goForward() {
    if (_canGoForward()) {
      _currentHistoryIndex++;
      final nextUri = _history[_currentHistoryIndex];
      _fetchAndRender(nextUri);
    }
  }
}

class HTMLRendererWidget extends StatelessWidget {
  final String html;
  final void Function(String url) onUrlTap;

  const HTMLRendererWidget({
    super.key,
    required this.html,
    required this.onUrlTap,
  });

  @override
  Widget build(BuildContext context) {
    final parser = HTMLParser();
    final root = parser.parse(html);

    return LayoutBuilder(
      builder: (context, constraints) {
        final renderer =
            CanvasHTMLRenderer(root, constraints.maxWidth, onUrlTap: onUrlTap);
        final size = renderer.computeSize(constraints);

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            renderer.handleTap(details.localPosition);
          },
          child: CustomPaint(
            painter: renderer,
            size: Size(constraints.maxWidth, size.height),
          ),
        );
      },
    );
  }
}

class HTMLParser {
  Node parse(String html) {
    final root = Node(type: 'root', children: []);
    final stack = <Node>[root];
    var i = 0;
    var currentText = '';

    void addTextNode() {
      if (currentText.isNotEmpty) {
        String normalizedText = _collapseWhitespace(currentText);
        if (normalizedText.isNotEmpty) {
          stack.last.children.add(Node(type: 'text', text: normalizedText));
        }
        currentText = '';
      }
    }

    while (i < html.length) {
      if (html[i] == '<') {
        addTextNode();

        if (html.startsWith('<!--', i)) {
          final endComment = html.indexOf('-->', i + 4);
          if (endComment == -1) break;
          i = endComment + 3;
          continue;
        }

        if (i + 1 < html.length && html[i + 1] == '/') {
          final endIndex = html.indexOf('>', i);
          if (endIndex != -1) {
            final tag = html.substring(i + 2, endIndex).trim().toLowerCase();

            // Handle auto-closing of <dd> or <dt> when a new <dt> or <dd> is encountered
            if (stack.last.type == tag ||
                _isAutoCloseableTag(stack.last.type, tag)) {
              stack.removeLast();
            }

            i = endIndex + 1;
            continue;
          } else {
            break;
          }
        }

        final endIndex = html.indexOf('>', i);
        if (endIndex != -1) {
          final tagContent = html.substring(i + 1, endIndex);
          final spaceIndex = tagContent.indexOf(RegExp(r'\s'));
          final tag = (spaceIndex == -1
                  ? tagContent
                  : tagContent.substring(0, spaceIndex))
              .toLowerCase();
          final attributes = _parseAttributes(
              spaceIndex == -1 ? '' : tagContent.substring(spaceIndex + 1));
          final node = Node(type: tag, attributes: attributes, children: []);

          if (tag == 'dt' || tag == 'dd') {
            while (stack.isNotEmpty &&
                (stack.last.type == 'dt' || stack.last.type == 'dd')) {
              stack.removeLast();
            }
          }

          stack.last.children.add(node);

          if (!_isSelfClosingTag(tag)) {
            stack.add(node);
          }

          i = endIndex + 1;
          continue;
        } else {
          break;
        }
      } else {
        currentText += html[i];
        i++;
      }
    }

    addTextNode();

    return root;
  }

  bool _isSelfClosingTag(String tag) {
    return ['br', 'hr', 'img', 'input', 'meta', 'link'].contains(tag);
  }

  bool _isAutoCloseableTag(String openTag, String closeTag) {
    if (['dt', 'dd'].contains(openTag) && ['dt', 'dd'].contains(closeTag)) {
      return true;
    }
    return false;
  }

  String _collapseWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, String> _parseAttributes(String attributeString) {
    final attributes = <String, String>{};
    int i = 0;

    while (i < attributeString.length) {
      while (i < attributeString.length && attributeString[i].trim().isEmpty) {
        i++;
      }
      if (i >= attributeString.length) break;

      int nameStart = i;
      while (i < attributeString.length &&
          attributeString[i] != '=' &&
          attributeString[i].trim().isNotEmpty) {
        i++;
      }
      String name =
          attributeString.substring(nameStart, i).trim().toLowerCase();

      if (i >= attributeString.length || attributeString[i] != '=') {
        attributes[name] = '';
        continue;
      }

      i++;
      while (i < attributeString.length && attributeString[i].trim().isEmpty) {
        i++;
      }

      String value = '';
      if (i < attributeString.length) {
        if (attributeString[i] == '"' || attributeString[i] == "'") {
          String quote = attributeString[i];
          i++;
          int valueStart = i;
          while (i < attributeString.length && attributeString[i] != quote) {
            i++;
          }
          value = attributeString.substring(valueStart, i);
          i++;
        } else {
          int valueStart = i;
          while (i < attributeString.length &&
              attributeString[i].trim().isNotEmpty &&
              attributeString[i] != '>') {
            i++;
          }
          value = attributeString.substring(valueStart, i);
        }
      }

      attributes[name] = value;
    }

    return attributes;
  }
}

class Node {
  final String type;
  final String? text;
  final Map<String, String> attributes;
  final List<Node> children;

  Node({
    required this.type,
    this.text,
    this.attributes = const {},
    this.children = const [],
  });
}

class CanvasHTMLRenderer extends CustomPainter {
  final Node root;
  final double maxWidth;
  final double baseFontSize;
  final double lineHeight;
  final void Function(String url) onUrlTap;
  final List<LinkBox> _linkBoxes = [];

  CanvasHTMLRenderer(this.root, this.maxWidth,
      {required this.onUrlTap, this.baseFontSize = 16, this.lineHeight = 1.5});

  Size computeSize(BoxConstraints constraints) {
    _linkBoxes.clear();
    double height = _measureNode(root, constraints.maxWidth);
    return Size(constraints.maxWidth, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _linkBoxes.clear();
    _paintNode(canvas, root, Offset.zero, size.width);
  }

  double _measureNode(Node node, double maxWidth,
      {int index = 0, List<Node>? siblings}) {
    if (_isBlockElement(node.type) || node.type == 'root') {
      double height = 0;
      int i = 0;
      while (i < node.children.length) {
        Node child = node.children[i];
        siblings = node.children;
        double indent = 0;
        Map<String, double> margins = _getMargins(child, i, siblings);
        height += margins['marginTop'] ?? 0.0;
        if (child.type == 'dd') {
          indent = baseFontSize * 2;
        }
        if (_isBlockElement(child.type)) {
          height += _measureNode(child, maxWidth - indent,
              index: i, siblings: siblings);
        } else {
          List<Node> inlineNodes = [];
          while (i < node.children.length &&
              !_isBlockElement(node.children[i].type)) {
            inlineNodes.add(node.children[i]);
            i++;
          }
          TextStyle blockStyle = _getTextStyle(node);
          TextSpan textSpan = _buildTextSpanFromNodes(
              inlineNodes, blockStyle, const Offset(1, 1));
          TextPainter textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(maxWidth: maxWidth - indent);
          height += textPainter.height;
          continue;
        }
        height += margins['marginBottom'] ?? 0.0;
        i++;
      }
      return height;
    } else {
      return 0;
    }
  }

  double _paintNode(Canvas canvas, Node node, Offset offset, double maxWidth,
      {int index = 0, List<Node>? siblings}) {
    if (node.type == "title" ||
        (node.type == "text" && node.text != null && node.text!.isEmpty)) {
      return 0;
    }
    if (_isBlockElement(node.type) || node.type == 'root') {
      double y = offset.dy;
      int i = 0;
      while (i < node.children.length) {
        Node child = node.children[i];
        siblings = node.children;
        double indent = 0;
        Map<String, double> margins = _getMargins(child, i, siblings);
        y += margins['marginTop'] ?? 0.0;

        if (child.type == 'dd') {
          indent = baseFontSize * 2;
          y = _paintNode(
              canvas, child, Offset(offset.dx + indent, y), maxWidth - indent);
        } else if (child.type == 'dt') {
          y = _paintNode(canvas, child, Offset(offset.dx, y), maxWidth,
              index: i, siblings: siblings);
        } else if (child.type == 'ul' || child.type == 'ol') {
          y = _paintList(
              canvas, child, Offset(offset.dx + indent, y), maxWidth - indent);
        } else if (_isBlockElement(child.type)) {
          y = _paintNode(
              canvas, child, Offset(offset.dx + indent, y), maxWidth - indent,
              index: i, siblings: siblings);
        } else {
          List<Node> inlineNodes = [];
          while (i < node.children.length &&
              !_isBlockElement(node.children[i].type)) {
            inlineNodes.add(node.children[i]);
            i++;
          }
          TextStyle blockStyle = _getTextStyle(node);
          TextSpan textSpan = _buildTextSpanFromNodes(
              inlineNodes,
              blockStyle.merge(TextStyle(
                fontSize: baseFontSize,
                height: lineHeight,
                color: Colors.black,
              )),
              Offset(offset.dx + indent, y));
          TextPainter textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(maxWidth: maxWidth - offset.dx - indent);
          textPainter.paint(canvas, Offset(offset.dx + indent, y));
          y += textPainter.height;
          continue;
        }
        y += margins['marginBottom'] ?? 0.0;
        i++;
      }
      return y;
    } else {
      return offset.dy;
    }
  }

  double _paintList(Canvas canvas, Node node, Offset offset, double maxWidth) {
    double y = offset.dy;
    int i = 0;
    int itemNumber = 1;
    while (i < node.children.length) {
      Node child = node.children[i];
      if (child.type == 'li') {
        double bulletIndent = baseFontSize * 0.5;
        TextSpan bulletSpan;
        if (node.type == 'ul') {
          bulletSpan = TextSpan(
            text: '•',
            style: TextStyle(
                fontSize: baseFontSize * 1.2,
                color: Colors.black,
                fontWeight: FontWeight.bold),
          );
        } else {
          bulletSpan = TextSpan(
            text: '$itemNumber.',
            style: TextStyle(
                fontSize: baseFontSize,
                color: Colors.black,
                fontWeight: FontWeight.bold),
          );
          itemNumber++;
        }

        TextPainter bulletPainter = TextPainter(
          text: bulletSpan,
          textDirection: TextDirection.ltr,
        );
        bulletPainter.layout();
        bulletPainter.paint(
            canvas, Offset(offset.dx, y + (lineHeight - 1) * baseFontSize / 2));

        double contentIndent = bulletIndent + baseFontSize;
        y = _paintNode(canvas, child, Offset(offset.dx + contentIndent, y),
            maxWidth - contentIndent);
      }
      i++;
    }
    return y;
  }

  TextSpan _buildTextSpanFromNodes(
      List<Node> nodes, TextStyle parentStyle, Offset offset) {
    List<InlineSpan> children = [];
    double currentX = offset.dx;
    for (var node in nodes) {
      TextSpan span =
          _buildTextSpan(node, parentStyle, Offset(currentX, offset.dy));
      children.add(span);
      currentX += _measureTextSpan(span);
    }
    return TextSpan(style: parentStyle, children: children);
  }

  TextSpan _buildTextSpan(Node node, TextStyle parentStyle, Offset offset) {
    TextStyle currentStyle = parentStyle.merge(_getTextStyle(node));

    if (node.type == 'text') {
      return TextSpan(text: node.text, style: currentStyle);
    } else if (node.type == 'a' && node.attributes.containsKey('href')) {
      final url = node.attributes['href']!;
      final linkText =
          node.children.isNotEmpty && node.children[0].type == 'text'
              ? node.children[0].text!
              : '';

      final textPainter = TextPainter(
        text: TextSpan(
            text: linkText,
            style: currentStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            )),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final linkBox = LinkBox(
        Rect.fromLTWH(
            offset.dx, offset.dy, textPainter.width, textPainter.height),
        url,
      );
      _linkBoxes.add(linkBox);

      return TextSpan(
        text: linkText,
        style: currentStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      );
    } else {
      List<InlineSpan> children = [];
      for (var child in node.children) {
        children.add(_buildTextSpan(child, currentStyle, offset));
      }
      return TextSpan(style: currentStyle, children: children);
    }
  }

  double _measureTextSpan(TextSpan span) {
    final textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

  bool _isBlockElement(String tag) {
    return [
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'ul',
      'ol',
      'li',
      'dl',
      'dt',
      'dd',
      'br',
      'hr',
      'nextid',
      'html',
      'body',
      'header',
      'title',
    ].contains(tag);
  }

  TextStyle _getTextStyle(Node node) {
    switch (node.type) {
      case 'h1':
        return TextStyle(
            fontSize: baseFontSize * 2.5, fontWeight: FontWeight.bold);
      case 'h2':
        return TextStyle(
            fontSize: baseFontSize * 2.0, fontWeight: FontWeight.bold);
      case 'h3':
        return TextStyle(
            fontSize: baseFontSize * 1.75, fontWeight: FontWeight.bold);
      case 'h4':
        return TextStyle(
            fontSize: baseFontSize * 1.5, fontWeight: FontWeight.bold);
      case 'h5':
        return TextStyle(
            fontSize: baseFontSize * 1.25, fontWeight: FontWeight.bold);
      case 'h6':
        return TextStyle(
            fontSize: baseFontSize * 1.1, fontWeight: FontWeight.bold);
      case 'dt':
        return const TextStyle(fontWeight: FontWeight.bold);
      case 'dd':
        return TextStyle(fontSize: baseFontSize);
      case 'a':
        return const TextStyle(
            color: Colors.blue, decoration: TextDecoration.underline);
      default:
        return TextStyle(
            fontSize: baseFontSize,
            color: Colors.black); // Default color is black
    }
  }

  Map<String, double> _getMargins(Node node, int index, List<Node> siblings) {
    double marginTop = 0.0;
    double marginBottom = 0.0;
    double smallMargin = baseFontSize * 0.25;
    double normalMargin = baseFontSize * 0.5;

    if (node.type.startsWith('h')) {
      marginTop = normalMargin;
      marginBottom = normalMargin;
    } else if (node.type == 'p') {
      marginTop = 0.0;
      marginBottom = normalMargin;
    } else if (node.type == 'dt') {
      if (index + 1 < siblings.length && siblings[index + 1].type == 'dd') {
        marginBottom = 0.0;
      } else {
        marginBottom = smallMargin;
      }
    } else if (node.type == 'dd') {
      if (index > 0 && siblings[index - 1].type == 'dt') {
        marginTop = 0.0;
      } else {
        marginTop = smallMargin;
      }
      marginBottom = smallMargin;
    } else if (node.type == 'dl') {
      marginTop = smallMargin;
      marginBottom = smallMargin;
    }

    return {'marginTop': marginTop, 'marginBottom': marginBottom};
  }

  @override
  bool shouldRepaint(covariant CanvasHTMLRenderer oldDelegate) {
    return oldDelegate.root != root ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.baseFontSize != baseFontSize ||
        oldDelegate.lineHeight != lineHeight;
  }

  void handleTap(Offset tapPosition) {
    for (var linkBox in _linkBoxes) {
      if (linkBox.rect.contains(tapPosition)) {
        onUrlTap(linkBox.url);
        break;
      }
    }
  }
}

class LinkBox {
  final Rect rect;
  final String url;

  LinkBox(this.rect, this.url);
}
