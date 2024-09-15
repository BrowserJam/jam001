using System.Collections.ObjectModel;
using System.Windows.Input;
using MauiBrowser.Browser.Renderer;
using SkiaSharp;
using SkiaSharp.Views.Maui;
using SkiaSharp.Views.Maui.Controls;
using Size = MauiBrowser.Browser.Layout.Size;

namespace MauiBrowser.Controls;

public class BrowserView : SKCanvasView
{
    public static readonly BindableProperty DisplayListProperty = BindableProperty.Create(
        nameof(DisplayList), typeof(ObservableCollection<IRenderCommand>), typeof(BrowserView),
        propertyChanged: OnDisplayListPropertyChanged);

    public ObservableCollection<IRenderCommand> DisplayList
    {
        get => (ObservableCollection<IRenderCommand>)GetValue(DisplayListProperty);
        set => SetValue(DisplayListProperty, value);
    }

    public static readonly BindableProperty CanvasSizeProperty =
        BindableProperty.Create(
            nameof(CanvasSize),
            typeof(Size),
            typeof(BrowserView),
            propertyChanged: OnCanvasSizeChanged);

    public Size? CanvasSize
    {
        get => (Size)GetValue(CanvasSizeProperty);
        set => SetValue(CanvasSizeProperty, value);
    }

    public static readonly BindableProperty CanvasSizeChangedCommandProperty =
        BindableProperty.Create(
            nameof(CanvasSizeChangedCommand),
            typeof(ICommand),
            typeof(BrowserView));

    public ICommand CanvasSizeChangedCommand
    {
        get => (ICommand)GetValue(CanvasSizeChangedCommandProperty);
        set => SetValue(CanvasSizeChangedCommandProperty, value);
    }

    private static void OnCanvasSizeChanged(BindableObject bindable, object oldValue, object newValue)
    {
        var view = (BrowserView)bindable;
        view.OnCanvasSizeChanged();
    }

    private void OnCanvasSizeChanged()
    {
        CanvasSizeChangedCommand?.Execute(null);
    }

    private static void OnDisplayListPropertyChanged(BindableObject bindable, object oldvalue, object newvalue)
    {
        ((BrowserView)bindable).InvalidateSurface();
    }

    protected override void OnPaintSurface(SKPaintSurfaceEventArgs e)
    {
        base.OnPaintSurface(e);

        var canvas = e.Surface.Canvas;

        if (CanvasSize?.Width != e.Info.Width || CanvasSize?.Height != e.Info.Height)
            CanvasSize = new Size(e.Info.Width, e.Info.Height);

        canvas.Clear();
        canvas.DrawColor(SKColors.White);

        foreach (var renderCommand in DisplayList)
        {
            //Trace.WriteLine(renderCommand.ToString());
            renderCommand.Execute(canvas);
        }
    }
}