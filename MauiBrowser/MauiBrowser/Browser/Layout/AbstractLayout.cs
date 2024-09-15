using MauiBrowser.Browser.Renderer;
using MauiBrowser.Services.Html;

namespace MauiBrowser.Browser.Layout;

public class Point
{
    public float X { get; set; }
    public float Y { get; set; }

    public Point()
    {
    }

    public Point(float x, float y)
    {
        X = x;
        Y = y;
    }
}

public class Size
{
    public int Width { get; set; }
    public int Height { get; set; }

    public Size()
    {
    }

    public Size(int width, int height)
    {
        Width = width;
        Height = height;
    }
}

public abstract class AbstractLayout
{
    public HtmlNode HtmlNode { get; }

    public List<AbstractLayout> Children { get; } = new();

    public Point Position { get; set; } = new();

    public Size Size { get; set; } = new();

    public AbstractLayout(HtmlNode htmlNode)
    {
        HtmlNode = htmlNode;
    }

    public abstract void Layout();

    public abstract List<IRenderCommand> Paint();
}