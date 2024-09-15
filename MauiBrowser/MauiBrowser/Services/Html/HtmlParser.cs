using System.Diagnostics;
using System.Text;
using MauiBrowser.Browser;

namespace MauiBrowser.Services.Html;

public class HtmlParser : IHtmlParser
{
    private static readonly HashSet<string> ImplicitClosureElements =
    [
        "p", "li", "dt", "dd", "nextid"
    ];

    private readonly LinkedList<HtmlNode> _unfinishedNodes = new();

    public HtmlNode ParseHtml(string html)
    {
        _unfinishedNodes.Clear();

        var textBuilder = new StringBuilder();
        var inTag = false;
        foreach (var c in html)
        {
            if (c == '<')
            {
                inTag = true;
                if (textBuilder.Length > 0)
                {
                    AddText(textBuilder.ToString());
                    textBuilder.Clear();
                }
            }
            else if (c == '>')
            {
                inTag = false;
                AddElement(textBuilder.ToString());
                textBuilder.Clear();
            }
            else
            {
                textBuilder.Append(c);
            }
        }

        if (!inTag && textBuilder.Length > 0)
        {
            AddElement(textBuilder.ToString());
            textBuilder.Clear();
        }


        // Finish any unfinished nodes
        while (_unfinishedNodes.Count > 1)
        {
            var node = _unfinishedNodes.Last();
            _unfinishedNodes.RemoveLast();
            var parent = _unfinishedNodes.Last();
            parent.Children.Add(node);
        }

        var root = _unfinishedNodes.Last();
        _unfinishedNodes.RemoveLast();

        return root;
    }

    public void PrintTree(HtmlNode htmlNode, int indent = 0)
    {
        Trace.IndentLevel = indent;
        Trace.WriteLine(htmlNode.ToString());
        foreach (var child in htmlNode.Children)
        {
            PrintTree(child, indent + 1);
        }

        Trace.IndentLevel = 0;
    }

    private void AddText(string text)
    {
        // Ignore whitespaces for now
        if (string.IsNullOrWhiteSpace(text))
            return;

        ValidateForMalformedElements();
        var parent = _unfinishedNodes.Last();
        var node = new TextHtmlNode(text, parent);
        parent.Children.Add(node);
    }

    private void AddElement(string text)
    {
        // Ignore !doctype
        if (text.StartsWith('!'))
            return;

        ValidateForMalformedElements(text);

        // Is finished element
        if (text.StartsWith('/'))
        {
            // Last element - is root and has no parent.
            if (_unfinishedNodes.Count == 1)
                return;

            var elementName = text.TrimStart('/').ToLower();
            CloseAnyRequiredOpenElements(elementName);

            var node = _unfinishedNodes.Last();
            _unfinishedNodes.RemoveLast();
            var parent = _unfinishedNodes.Last();
            parent.Children.Add(node);
        }
        else
        {
            var parts = text.ReplaceLineEndings(" ").Split(' ');
            var elementName = parts.First().ToLower();
            var attributes = GetAttributes(parts.Skip(1));

            // Check for self-closing attributes
            if (HtmlSpec.SelfClosingElements.Contains(elementName))
            {
                var parent = _unfinishedNodes.Last();
                var node = new ElementHtmlNode(elementName, attributes, parent);
                parent.Children.Add(node);
            }
            else
            {
                // Unfinished element

                CloseAnyRequiredOpenElements(elementName);

                // Note: First element has no unfinished parent
                var parent = _unfinishedNodes.LastOrDefault();
                var element = new ElementHtmlNode(elementName, attributes, parent);
                _unfinishedNodes.AddLast(element);
            }
        }
    }

    private void CloseAnyRequiredOpenElements(string elementName)
    {
        if (HtmlSpec.BlockElements.Contains(elementName))
        {
            for (var node = _unfinishedNodes.Last; node != null; node = node.Previous)
            {
                var element = (ElementHtmlNode)node.Value;
                if (ImplicitClosureElements.Contains(element.Name))
                {
                    _unfinishedNodes.RemoveLast();
                    var parent = _unfinishedNodes.Last();
                    parent.Children.Add(node.Value);
                }
            }
        }
    }

    private void ValidateForMalformedElements(string? elementName = null)
    {
        var openElements = _unfinishedNodes
            .Where(node => node.Type == NodeType.Element)
            .Select(node => ((ElementHtmlNode)node).Name).ToList();

        // Add missing html element
        if (openElements.Count == 0 && (elementName != null && !elementName.StartsWith("html")))
            AddElement("html");
    }

    private Dictionary<string, string> GetAttributes(IEnumerable<string> parts)
    {
        var attributeMap = new Dictionary<string, string>();
        foreach (var attribute in parts)
        {
            // eg. charset="utf-8"
            if (attribute.Contains("="))
            {
                var keyValue = attribute.Split('=');
                var key = keyValue.First().ToLower();
                var value = keyValue.Last().Trim('\'').Trim('\"').ToLower();
                attributeMap.Add(key, value);
            }
            else
            {
                // FIXME: Ignore closing slash
                attributeMap.Add(attribute.ToLower(), string.Empty);
            }
        }

        return attributeMap;
    }
}