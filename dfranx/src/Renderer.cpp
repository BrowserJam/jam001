#include <BrowserJam/Renderer.h>
#include <BrowserJam/Tools.h>

#include <iostream>


using namespace sb;


Renderer::Renderer(): mD2DFactory(nullptr), mRenderTarget(nullptr), mDWriteFactory(nullptr)
{
}

bool Renderer::Create(HWND hWnd)
{
    // Create Direct2D factory
    HRESULT hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &mD2DFactory);
    if (FAILED(hr))
    {
        std::cout << "Failed to create D2D1 factory" << std::endl;
        return false;
    }

    // Obtain the size of the drawing area
    RECT rc;
    GetClientRect(hWnd, &rc);

    // Create a Direct2D render target
    hr = mD2DFactory->CreateHwndRenderTarget(
        D2D1::RenderTargetProperties(),
        D2D1::HwndRenderTargetProperties(
            hWnd,
            D2D1::SizeU(
                rc.right - rc.left,
                rc.bottom - rc.top)
        ),
        &mRenderTarget
    );
    if (FAILED(hr))
    {
        std::cout << "Failed to create D2D1 Render Target" << std::endl;
        return false;
    }

    // Initialize DirectWrite for text rendering
    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown**>(&mDWriteFactory));
    if (FAILED(hr))
    {
        std::cout << "Failed to create DirectWrite factory" << std::endl;
        return false;
    }

    return true;
}

void Renderer::Shutdown()
{
    SafeRelease(&mRenderTarget);
    SafeRelease(&mDWriteFactory);
    SafeRelease(&mD2DFactory);
}
