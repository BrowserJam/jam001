using MauiBrowser.Browser.Renderer;
using MauiBrowser.Services.Html;

namespace MauiBrowser.Browser.Layout;

public class DocumentLayout : AbstractLayout
{
    public static Point Margin { get; set; } = new(Constants.FontSize, Constants.FontSize * 2f);

    private readonly Size _canvasSize;

    public DocumentLayout(HtmlNode htmlNode, Size canvasSize) : base(htmlNode)
    {
        _canvasSize = canvasSize;
    }

    public override void Layout()
    {
        var child = new BlockLayout(HtmlNode, this, null);
        Children.Add(child);
        Size.Width = (int)(_canvasSize.Width - (2f * Margin.X));
        Position = Margin;
        child.Layout();
        Size.Height = child.Size.Height;
    }

    public override List<IRenderCommand> Paint()
    {
        return [];
    }

    public override string ToString()
    {
        return "DocumentLayout()";
    }
}