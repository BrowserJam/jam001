using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Net;
using CommunityToolkit.Maui.Core.Extensions;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiBrowser.Browser.Layout;
using MauiBrowser.Browser.Renderer;
using MauiBrowser.Services.Html;
using MauiBrowser.Services.Http;
using Size = MauiBrowser.Browser.Layout.Size;

namespace MauiBrowser.ViewModels;

public partial class MainPageViewModel : ObservableObject
{
    [ObservableProperty] private Size? _canvasSize;

    [ObservableProperty] private ObservableCollection<IRenderCommand> _displayList = new();

    public string Url { get; set; } = "info.cern.ch/hypertext/WWW/TheProject.html";

    private readonly IHttpRequestService _httpRequestService;
    private readonly IHtmlParser _htmlParser;
    private CancellationToken _pageLoadCancellationToken;
    private HtmlNode? _htmlRootNode;

    public MainPageViewModel(IHttpRequestService requestService, IHtmlParser htmlParser)
    {
        _httpRequestService = requestService;
        _htmlParser = htmlParser;
    }

    [RelayCommand]
    private async Task CanvasSizeChanged()
    {
        if (CanvasSize is not null && _htmlRootNode is null)
        {
            await LoadPage();
        }
        else
        {
            var documentLayout = CreateLayoutTree();
            UpdateDisplayList(documentLayout);
        }
    }

    [RelayCommand]
    private async Task LoadPage()
    {
        if (CanvasSize is null)
            return;

        var url = _httpRequestService.ParseToUrl(Url);
        if (url is null)
        {
            Trace.TraceWarning($"Invalid url to request {Url}");
            return;
        }

        _pageLoadCancellationToken = new CancellationToken();
        Trace.TraceInformation($"Trying to request {url.ToString()}");
        var result = await _httpRequestService.GetRequestAsync(url, _pageLoadCancellationToken);
        if (result.StatusCode == HttpStatusCode.OK)
            Trace.TraceInformation(result.ToString());
        else
            Trace.TraceWarning(result.ToString());

        var content = await result.Content.ReadAsStringAsync(_pageLoadCancellationToken);
        _htmlRootNode = _htmlParser.ParseHtml(content);
        //_htmlParser.PrintTree(_htmlRootNode);
        var documentLayout = CreateLayoutTree();
        UpdateDisplayList(documentLayout);
    }

    private DocumentLayout? CreateLayoutTree()
    {
        if (_htmlRootNode is null || CanvasSize is null)
            return null;

        var documentRoot = new DocumentLayout(_htmlRootNode, CanvasSize);
        documentRoot.Layout();
        //PrintTree(documentRoot);
        return documentRoot;
    }

    private void UpdateDisplayList(DocumentLayout? documentRoot)
    {
        if (documentRoot is null)
            return;
        
        var displayList = new List<IRenderCommand>();
        GetChildrenDisplayList(documentRoot, displayList);

        DisplayList = displayList.ToObservableCollection();
    }

    public void PrintTree(AbstractLayout node, int indent = 0)
    {
        Trace.IndentLevel = indent;
        Trace.WriteLine(node.ToString());
        foreach (var child in node.Children)
            PrintTree(child, indent + 1);

        Trace.IndentLevel = 0;
    }

    private void GetChildrenDisplayList(AbstractLayout layoutObject, List<IRenderCommand> commands)
    {
        commands.AddRange(layoutObject.Paint());
        foreach (var layoutObjectChild in layoutObject.Children)
            GetChildrenDisplayList(layoutObjectChild, commands);
    }
}