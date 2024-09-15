#include <iostream>
#include <fstream>
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#include <d2d1.h>
#include <dwrite.h>
#include <wininet.h>

#include <BrowserJam/Renderer.h>
#include <BrowserJam/Document.h>

#include <myhtml/api.h>


#ifdef main
#undef main
#endif

BOOL FileExists(LPCTSTR szPath)
{
    DWORD dwAttrib = GetFileAttributes(szPath);

    return (dwAttrib != INVALID_FILE_ATTRIBUTES &&
           !(dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

std::string GetHtmlFromUrl(HINTERNET hInternet, const std::string& url)
{
    HINTERNET hConnect = InternetOpenUrl(hInternet, url.c_str(), NULL, 0, INTERNET_FLAG_RELOAD, 0);
    if (!hConnect) {
        std::cerr << "InternetOpenUrl failed: " << GetLastError() << std::endl;
        InternetCloseHandle(hInternet);
        return "";
    }

    char buffer[4096];
    DWORD bytesRead;
    std::string htmlContent;

    while (InternetReadFile(hConnect, buffer, sizeof(buffer) - 1, &bytesRead) && bytesRead != 0) {
        buffer[bytesRead] = '\0';  // Null-terminate the buffer
        htmlContent += buffer;
    }

    InternetCloseHandle(hConnect);
    InternetCloseHandle(hInternet);

    return htmlContent;
}

int main(int argc, char* argv[])
{
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        std::cout << "Failed to initialize the SDL2 library\n";
        return -1;
    }

    SDL_Window* window = SDL_CreateWindow("Browser Jam",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        1200, 800,
        SDL_WINDOW_SHOWN);

    if (!window)
    {
        std::cout << "Failed to create window\n";
        return -1;
    }

    HINTERNET hInternet = InternetOpen("Lack Of Time", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    if (!hInternet)
    {
        std::cerr << "InternetOpen failed: " << GetLastError() << std::endl;
        return 0;
    }

    // Get SDL2 window hwnd
    SDL_SysWMinfo systemInfo;
    SDL_VERSION(&systemInfo.version);
    SDL_GetWindowWMInfo(window, &systemInfo);

    HWND hwnd = systemInfo.info.win.window;

    sb::Renderer renderer;
    renderer.Create(hwnd);

    sb::Document document(&renderer);

    if (FileExists("default.css"))
    {
        std::ifstream cssFile("default.css");
        std::string cssContent((std::istreambuf_iterator<char>(cssFile)),
                         std::istreambuf_iterator<char>());
        document.LoadDefaultStyles(cssContent.c_str(), cssContent.size());
    }
    else
    {
        std::string cssContent = sb::StyleFactory::GetDefaultCSS();
        document.LoadDefaultStyles(cssContent.c_str(), cssContent.size());
    }

    std::string currentUrl = "https://info.cern.ch/hypertext/WWW/TheProject.html";

    std::string html = GetHtmlFromUrl(hInternet, currentUrl);
    document.LoadHTML(html.data(), html.size());

    std::string waitingRedirect = "";
    document.Redirect = [&waitingRedirect](const std::string& url)
    {
        waitingRedirect = url;
    };

    document.InvalidateLayout();

    bool isWindowOpen = true;
    while (isWindowOpen)
    {
        SDL_Event e;
        while (SDL_PollEvent(&e) > 0)
        {
            if (e.type == SDL_QUIT)
            {
                isWindowOpen = false;
            }
            else if (e.type == SDL_MOUSEMOTION)
            {
                document.OnMouseMove(e.motion.x, e.motion.y);
            }
            else if (e.type == SDL_MOUSEBUTTONDOWN)
            {
                document.OnMouseDown(e.button.x, e.button.y);
            }

            SDL_UpdateWindowSurface(window);
        }

        document.Render();

        if (!waitingRedirect.empty())
        {
            size_t last = waitingRedirect.find_last_of('/');
            if (last != std::string::npos)
            {
                currentUrl = waitingRedirect.substr(0, last + 1) + waitingRedirect;

                std::string html = GetHtmlFromUrl(hInternet, currentUrl);
                document.LoadHTML(html.data(), html.size());
                document.InvalidateLayout();
            }

            waitingRedirect.clear();
        }
    }

    document.Shutdown();
    renderer.Shutdown();

    return 0;
}