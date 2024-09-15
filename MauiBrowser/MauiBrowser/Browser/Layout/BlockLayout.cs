using System.Diagnostics;
using MauiBrowser.Browser.Renderer;
using MauiBrowser.Browser.Renderer.Commands;
using MauiBrowser.Services.Html;
using SkiaSharp;

namespace MauiBrowser.Browser.Layout;

public class BlockLayout : AbstractLayout
{
    private static readonly SKPaint NormalPaint = new()
    {
        IsAntialias = true,
        Color = SKColors.Black,
        TextSize = 13f,
        Typeface = SKTypeface.FromFamilyName("OpenSans-Regular", SKFontStyle.Normal)
    };

    private static readonly SKPaint HeaderPaint = new()
    {
        IsAntialias = true,
        Color = SKColors.Black,
        TextSize = 32f,
        Typeface = SKTypeface.FromFamilyName("OpenSans-Regular", SKFontStyle.Bold)
    };

    private static readonly SKPaint HyperLinkPaint = new()
    {
        IsAntialias = true,
        Color = SKColors.Blue,
        TextSize = 13f,
        Typeface = SKTypeface.FromFamilyName("OpenSans-Regular", SKFontStyle.Normal),
    };

    private static readonly HashSet<string> LayoutTreeIgnoredElements =
    [
        "header", "head"
    ];

    private static SKPaint _currentPaint = NormalPaint;

    private enum LayoutMode
    {
        Block = 0,
        Inline
    }

    public class Line
    {
        public required float X { get; set; }

        public required string Word { get; set; }

        public required SKPaint Font { get; set; }
    }

    public AbstractLayout Parent { get; }

    public AbstractLayout? Previous { get; set; }

    public List<DisplayListItem> DisplayList { get; }

    public Point Cursor { get; set; }

    public List<Line> Lines { get; }

    public BlockLayout(HtmlNode htmlNode, AbstractLayout parent, AbstractLayout? previous) : base(htmlNode)
    {
        Parent = parent;
        Previous = previous;
        DisplayList = [];
        Lines = [];
        Cursor = DocumentLayout.Margin;
    }

    private LayoutMode Mode
    {
        get
        {
            if (HtmlNode.Type == NodeType.Text)
                return LayoutMode.Inline;

            if (HtmlNode.Type == NodeType.Element)
            {
                foreach (var child in HtmlNode.Children)
                {
                    if (child.Type != NodeType.Element)
                        continue;
                    var childElement = (ElementHtmlNode)child;
                    if (HtmlSpec.BlockElements.Contains(childElement.Name))
                        return LayoutMode.Block;
                }
            }

            if (HtmlNode.Children.Count > 0)
                return LayoutMode.Inline;

            return LayoutMode.Block;
        }
    }

    public override void Layout()
    {
        Position.X = Parent.Position.X;
        Size.Width = Parent.Size.Width;

        if (Previous != null)
            Position.Y = Previous.Position.Y + Previous.Size.Height;
        else
            Position.Y = Parent.Position.Y;

        var mode = Mode;
        if (mode == LayoutMode.Block)
        {
            Previous = null;
            foreach (var child in HtmlNode.Children)
            {
                if (child.Type == NodeType.Element)
                {
                    var element = (ElementHtmlNode)child;
                    if (LayoutTreeIgnoredElements.Contains(element.Name))
                        continue;
                }

                var next = new BlockLayout(child, this, Previous);
                Children.Add(next);
                Previous = next;
            }
        }
        else
        {
            Cursor = new Point();
            Lines.Clear();

            Recurse(HtmlNode);
            Flush();
        }

        foreach (var child in Children)
            child.Layout();

        if (mode == LayoutMode.Block)
            Size.Height = Children.Sum(child => child.Size.Height);
        else
            Size.Height = (int)Cursor.Y;
    }

    public override List<IRenderCommand> Paint()
    {
        var commands = new List<IRenderCommand>();
        if (Mode == LayoutMode.Inline)
        {
            foreach (var displayListItem in DisplayList)
            {
                commands.Add(new DrawTextCommand(displayListItem.Text,
                    new SKPoint(displayListItem.Position.X, displayListItem.Position.Y), displayListItem.Font));
            }
        }

        return commands;
    }

    public override string ToString()
    {
        return
            $"BlockLayout[{Mode}](x={Position.X}, y={Position.Y}, w={Size.Width}, h={Size.Height}), displayListCount={DisplayList.Count}, node={HtmlNode})";
    }

    private void Recurse(HtmlNode? node)
    {
        if (node is null)
            return;

        if (node.Type == NodeType.Text)
        {
            OnTextNode((TextHtmlNode)node);
        }
        else if (node.Type == NodeType.Element)
        {
            var element = (ElementHtmlNode)node;
            OnOpenElement(element);

            foreach (var child in node.Children)
            {
                Recurse(child);
            }

            OnCloseElement(element);
        }
        else
        {
            Debug.Assert(false);
        }
    }

    private void OnTextNode(TextHtmlNode textHtmlNode)
    {
        var words = textHtmlNode.Text.Replace("\n", " ").Split(' ');
        foreach (var word in words)
        {
            if (word.Length == 0)
                continue;

            var wordMeasure = _currentPaint.MeasureText(word);
            if (Cursor.X + wordMeasure > Size.Width)
                Flush();

            Lines.Add(new Line() { X = Cursor.X, Word = word, Font = _currentPaint });
            var spaceMeasure = _currentPaint.MeasureText(" ");
            Cursor.X += wordMeasure + spaceMeasure;
        }
    }

    private void OnOpenElement(ElementHtmlNode elementHtml)
    {
        if (elementHtml.Name == "h1")
        {
            _currentPaint = HeaderPaint;
        }
        else if (elementHtml.Name == "a")
        {
            _currentPaint = HyperLinkPaint;
        }
        else if (elementHtml.Name == "dd")
        {
            Cursor.X += 40;
        }
    }

    private void OnCloseElement(ElementHtmlNode elementHtml)
    {
        _currentPaint = NormalPaint;
    }

    private void Flush()
    {
        if (Lines.Count == 0)
            return;

        foreach (var line in Lines)
        {
            var position = new Point(Position.X + line.X, Position.Y + Cursor.Y);
            DisplayList.Add(new DisplayListItem()
                { Position = position, Text = line.Word, Font = line.Font });
        }

        Lines.Clear();
        Cursor.X = 0;
        Cursor.Y += _currentPaint.TextSize * 1.5f;
    }
}