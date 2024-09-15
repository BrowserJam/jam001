using SkiaSharp;

namespace MauiBrowser.Browser.Renderer.Commands;

public class DrawRectCommand : IRenderCommand
{
    private readonly SKRect _rect;
    private readonly SKPaint _paint;

    public DrawRectCommand(SKRect rect, SKColor color)
    {
        _rect = rect;
        _paint = new SKPaint() { Color = color };
    }

    public void Execute(SKCanvas canvas)
    {
        canvas.DrawRect(_rect, _paint);
    }

    public override string ToString()
    {
        return $"DrawRectCommand[Rect: {_rect}]";
    }
}