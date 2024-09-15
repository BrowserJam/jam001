//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_TEXTELEMENT_H__
#define __BROWSERJAM_TEXTELEMENT_H__

#include <BrowserJam/Elements/PageElement.h>

#include <d2d1.h>
#include <dwrite.h>


namespace sb
{
    class TextElement: public PageElement
    {
    public:
        TextElement(const wchar_t* text, const char* tag, Document* doc, PageElement* parent);

        inline const wchar_t* GetText() const { return mText.c_str(); }
        inline void SetText(const wchar_t* text) { mText = text; }

        // Update the layout of this element and it's children
        virtual Point Arrange(const Rect& availableSpace, Point cursor, float blockAdvance) override;

        // Render the element
        virtual void Render() override;

        // Get the size in pixels of a ' ' character
        inline float GetHorizontalAdvance() const { return mHorizontalAdvance; }
        inline float GetVerticalAdvance() const { return mVerticalAdvance; }

    private:
        std::wstring mText;
        IDWriteTextFormat* mDWFormat;
        IDWriteTextLayout* mDWLayout;
        ID2D1SolidColorBrush* mBrush;

        float mHorizontalAdvance;
        float mVerticalAdvance;
    };
}

#endif //__BROWSERJAM_TEXTELEMENT_H__
