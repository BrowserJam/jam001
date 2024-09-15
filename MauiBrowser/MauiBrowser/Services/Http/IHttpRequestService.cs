namespace MauiBrowser.Services.Http;

public interface IHttpRequestService
{
    Task<HttpResponseMessage> GetRequestAsync(Uri url, CancellationToken cancellationToken);
    Uri? ParseToUrl(string url);
}