//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_DOCUMENT_H__
#define __BROWSERJAM_DOCUMENT_H__

#include <BrowserJam/FontDescription.h>
#include <BrowserJam/StyleFactory.h>

#include <d2d1.h>
#include <map>
#include <string>
#include <vector>
#include <functional>


struct myhtml_tree_node;
struct myhtml_tree;

namespace sb
{
    class Renderer;
    class PageElement;
    struct Rect;

    class Document
    {
    public:
        Document(Renderer* renderer);

        void LoadDefaultStyles(const char* css, unsigned int css_length);
        void LoadHTML(const char* html, unsigned int html_length);

        void OnMouseMove(float x, float y);
        void OnMouseDown(float x, float y);

        void Shutdown();

        void InvalidateLayout();

        void Render();

        Rect GetBounds() const;

        inline Cursor GetMouseCursor() const { return mCursor; }
        void SetMouseCursor(Cursor cursor);

        ID2D1SolidColorBrush* CreateSolidColorBrush(unsigned int rgba);
        IDWriteTextFormat* CreateTextFormat(const wchar_t* name, float size, FontWeight weight,
        FontStyle style, FontStretch stretch);
        void GetFontInformation(const wchar_t* name, float size, FontWeight weight,
            FontStyle style, FontStretch stretch, float& horizAdvance, float& vertAdvance,
            IDWriteFontFace** fontFace);

        inline StyleFactory& GetStyleFactory() { return mStyleFactory; }
        inline Renderer* GetRenderer() const { return mRenderer; }

        std::function<void(const std::string&)> Redirect;

        void SetRoot(PageElement* root) { mRoot = root; }

    private:
        void ProcessHTMLNode(struct myhtml_tree* tree, struct myhtml_tree_node* node, PageElement* parent);
        void PostProcess();

        void RemoveHTMLWhiteSpaces(std::string& content) const;
        bool IsInlineTag(PageElement* element) const;

        void DeleteElement(PageElement* element);

    protected:
        Renderer* mRenderer;
        PageElement* mRoot;
        StyleFactory mStyleFactory;

        Cursor mCursor;

    private:
        struct Font
        {
            IDWriteTextFormat* dwriteFormat;

            IDWriteFontFace* dwriteFontFace;
            float verticalAdvance;
            float horizontalAdvance;

            std::wstring name;
            float size;
            FontWeight weight;
            FontStyle style;
            FontStretch stretch;
        };
        std::vector<Font> mFontCache;

        std::map<unsigned int, ID2D1SolidColorBrush*> mBrushCache;
    };
}

#endif //__BROWSERJAM_DOCUMENT_H__
