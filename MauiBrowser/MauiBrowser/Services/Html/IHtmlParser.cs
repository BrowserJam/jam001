using System.Text;
using Microsoft.Extensions.Primitives;

namespace MauiBrowser.Services.Html;

public interface IHtmlParser
{
    HtmlNode ParseHtml(string html);
    void PrintTree(HtmlNode htmlNode, int indent = 0);
}

public abstract class HtmlNode
{
    public readonly NodeType Type;
    public readonly HtmlNode? Parent;
    public readonly List<HtmlNode> Children;

    public HtmlNode(NodeType type, HtmlNode? parent = default)
    {
        Type = type;
        Parent = parent;
        Children = new List<HtmlNode>();
    }
}

public enum NodeType
{
    Text,
    Element
}

public class TextHtmlNode : HtmlNode
{
    public readonly string Text;

    public TextHtmlNode(string text, HtmlNode? parent) : base(NodeType.Text, parent)
    {
        Text = text;
    }

    public override string ToString()
    {
        var builder = new StringBuilder();
        builder.Append("Text<");
        builder.Append(Text.ReplaceLineEndings(" "));
        builder.Append('>');
        return builder.ToString();
    }
}

public class ElementHtmlNode : HtmlNode
{
    public readonly string Name;
    public readonly Dictionary<string, string> Attributes;

    public ElementHtmlNode(string name, HtmlNode? parent) : base(NodeType.Element, parent)
    {
        Name = name;
        Attributes = new Dictionary<string, string>();
    }

    public ElementHtmlNode(string name, Dictionary<string, string> attributes, HtmlNode? parent)
        : base(NodeType.Element, parent)
    {
        Name = name;
        Attributes = attributes;
    }

    public override string ToString()
    {
        var builder = new StringBuilder();
        builder.Append("Element<");
        builder.Append(Name.ReplaceLineEndings(" "));
        if (Attributes.Count > 0)
        {
            builder.Append(";attributes[");
            foreach (var attribute in Attributes)
            {
                builder.Append(attribute.Key.ReplaceLineEndings(" "));
                builder.Append('=');
                builder.Append(attribute.Value.ReplaceLineEndings(" "));
                builder.Append(',');
            }

            builder.Remove(builder.Length - 1, 1);
            builder.Append(']');
        }

        builder.Append('>');
        return builder.ToString();
    }
}