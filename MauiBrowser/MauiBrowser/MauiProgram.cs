using CommunityToolkit.Maui;
using MauiBrowser.Services.Html;
using MauiBrowser.Services.Http;
using MauiBrowser.ViewModels;
using MauiBrowser.Views;
using Microsoft.Extensions.Logging;
using SkiaSharp.Views.Maui.Controls.Hosting;

namespace MauiBrowser;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
        {
            var builder = MauiApp.CreateBuilder();
            builder
                .UseMauiApp<App>()
                .UseMauiCommunityToolkit()
                .UseSkiaSharp()
                .ConfigureFonts(fonts =>
                {
                    fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                    fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                });
    
            builder.Services.AddSingleton<MainPage>();
            builder.Services.AddSingleton<MainPageViewModel>();
            builder.Services.AddSingleton<IHttpRequestService, HttpRequestService>();
            builder.Services.AddTransient<IHtmlParser, HtmlParser>();
    
    #if DEBUG
            builder.Logging.AddDebug();
    #endif
    
            return builder.Build();
        }
}