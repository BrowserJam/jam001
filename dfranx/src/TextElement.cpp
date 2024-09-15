#include <BrowserJam/Elements/TextElement.h>
#include <BrowserJam/Document.h>
#include <BrowserJam/Renderer.h>
#include <BrowserJam/StyleFactory.h>
#include <BrowserJam/Tools.h>

#include <d2d1.h>
#include <limits>
#include <iostream>


using namespace sb;

TextElement::TextElement(const wchar_t* text, const char* tag, Document* doc, PageElement* parent):
    PageElement(tag, doc, parent), mDWFormat(nullptr), mHorizontalAdvance(0.0f)
{
    SetText(text);
}

Point TextElement::Arrange(const Rect& availableSpace, Point cursor, float blockAdvance)
{
    auto dwFactory = mDocument->GetRenderer()->GetWriteFactory();

    mStyle = mDocument->GetStyleFactory().ComputeStyle(this);
    if (!mStyle->Has(StylePropertyId_Display))
    {
        mStyle->Set(StylePropertyId_Display, Box<DisplayType>(DisplayType_Inline));
    }

    mLayoutBounds = availableSpace;
    mContentBounds = mLayoutBounds;

    Color textColor = Unbox<Color>(mStyle->GetOrDefaultValue(StylePropertyId_Color).get());
    std::wstring fontFamily = Unbox<std::wstring>(mStyle->GetOrDefaultValue(StylePropertyId_FontFamily).get());
    float fontSize = Unbox<float>(mStyle->GetOrDefaultValue(StylePropertyId_FontSize).get());
    FontWeight fontWeight = Unbox<FontWeight>(mStyle->GetOrDefaultValue(StylePropertyId_FontWeight).get());
    FontStyle fontStyle = Unbox<FontStyle>(mStyle->GetOrDefaultValue(StylePropertyId_FontStyle).get());
    FontStretch fontStretch = Unbox<FontStretch>(mStyle->GetOrDefaultValue(StylePropertyId_FontStretch).get());
    TextDecoration textDecoration = Unbox<TextDecoration>(mStyle->GetOrDefaultValue(StylePropertyId_TextDecoration).get());

    mBrush = mDocument->CreateSolidColorBrush(textColor.AsUInt32());
    mDWFormat = mDocument->CreateTextFormat(fontFamily.data(), fontSize, fontWeight, fontStyle,
        fontStretch);

    IDWriteFontFace* fontFace = nullptr;
    mDocument->GetFontInformation(fontFamily.data(), fontSize, fontWeight, fontStyle, fontStretch,
        mHorizontalAdvance, mVerticalAdvance, &fontFace);

    // Create text layout
    dwFactory->CreateTextLayout(mText.data(), mText.length(), mDWFormat,
        std::numeric_limits<float>::infinity(), std::numeric_limits<float>::infinity(), &mDWLayout);
    mDWLayout->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);

    if (textDecoration == TextDecoration_Underline)
    {
        DWRITE_TEXT_RANGE range;
        range.startPosition = 0;
        range.length = mText.length();
        mDWLayout->SetUnderline(true, range);
    }
    else if (textDecoration == TextDecoration_LineThrough)
    {
        DWRITE_TEXT_RANGE range;
        range.startPosition = 0;
        range.length = mText.length();
        mDWLayout->SetStrikethrough(true, range);
    }

    DWRITE_TEXT_METRICS metrics;
    mDWLayout->GetMetrics(&metrics);

    mLayoutBounds.x = cursor.x;
    mLayoutBounds.y = cursor.y;
    mLayoutBounds.width = metrics.width + mHorizontalAdvance;
    mLayoutBounds.height = metrics.height;

    mContentBounds = mLayoutBounds;

    return { mLayoutBounds.x + mLayoutBounds.width, mLayoutBounds.y };
}

void TextElement::Render()
{
    auto rt = mDocument->GetRenderer()->GetRenderTarget();

    rt->DrawTextLayout({ mContentBounds.x, mContentBounds.y },
        mDWLayout, mBrush, D2D1_DRAW_TEXT_OPTIONS_NONE);

    PageElement::Render();
}