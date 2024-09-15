using System.Net;

namespace MauiBrowser.Services.Http;

public class HttpRequestService : IHttpRequestService
{
    public async Task<HttpResponseMessage> GetRequestAsync(Uri url, CancellationToken cancellationToken)
    {
        var httpClient = new HttpClient()
        {
            DefaultRequestVersion = HttpVersion.Version10,
            DefaultVersionPolicy = HttpVersionPolicy.RequestVersionExact
        };

        var message = await httpClient.GetAsync(url, cancellationToken);
        return message;
    }
    
    public Uri? ParseToUrl(string url)
    {
        if (!url.StartsWith(Uri.UriSchemeHttps) && !url.StartsWith(Uri.UriSchemeHttps))
            url = url.Insert(0, Uri.UriSchemeHttps + "://");
        
        var isValid = Uri.TryCreate(url, UriKind.RelativeOrAbsolute, out var finalUrl)
                      && (finalUrl.Scheme == Uri.UriSchemeHttp
                          || finalUrl.Scheme == Uri.UriSchemeHttps);
        if (isValid)
            return finalUrl;
        return null;
    }
}