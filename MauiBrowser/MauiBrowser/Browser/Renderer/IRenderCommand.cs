using SkiaSharp;

namespace MauiBrowser.Browser.Renderer;

public interface IRenderCommand
{
    void Execute(SKCanvas canvas);
}