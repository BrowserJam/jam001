//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_RENDERER_H__
#define __BROWSERJAM_RENDERER_H__

#include <windows.h>
#include <d2d1.h>
#include <dwrite.h>


namespace sb
{
    class Renderer
    {
    public:
        Renderer();

        bool Create(HWND hWnd);

        void Shutdown();

        inline ID2D1Factory* Get2DFactory() const { return mD2DFactory; }
        inline IDWriteFactory* GetWriteFactory() const { return mDWriteFactory; }
        inline ID2D1HwndRenderTarget* GetRenderTarget() const { return mRenderTarget; }

    private:
        ID2D1Factory* mD2DFactory;
        ID2D1HwndRenderTarget* mRenderTarget;
        IDWriteFactory* mDWriteFactory;
    };
}

#endif //__BROWSERJAM_RENDERER_H__
