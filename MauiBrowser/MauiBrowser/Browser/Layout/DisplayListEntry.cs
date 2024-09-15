using SkiaSharp;

namespace MauiBrowser.Browser.Layout;

public class DisplayListItem
{
    public required Point Position { get; init; }
    public required string Text { get; init; }
    public required SKPaint Font { get; init; }
}