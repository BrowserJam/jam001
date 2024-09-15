using SkiaSharp;

namespace MauiBrowser.Browser.Renderer.Commands;

public class DrawTextCommand : IRenderCommand
{
    private readonly string _text;
    private readonly SKPoint _position;
    private readonly SKPaint _font;

    public DrawTextCommand(string text, SKPoint position, SKPaint font)
    {
        _text = text;
        _position = position;
        _font = font;
    }

    public void Execute(SKCanvas canvas)
    {
        canvas.DrawText(_text, _position, _font);
    }
    
    public override string ToString()
    {
        return $"DrawTextCommand[Text: \"{_text}\", Position: X:{_position.X}, Y:{_position.Y}]";
    }
}