//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_STYLEPROPERTY_H__
#define __BROWSERJAM_STYLEPROPERTY_H__

#include <BrowserJam/BoxedValue.h>

#include <memory>


namespace sb
{
    enum StylePropertyId: int
    {
        StylePropertyId_Unknown,
        StylePropertyId_Margin,
        StylePropertyId_Padding,
        StylePropertyId_Border,
        StylePropertyId_Color,
        StylePropertyId_BackgroundColor,
        StylePropertyId_BorderColor,
        StylePropertyId_BorderRadius,
        StylePropertyId_Display,
        StylePropertyId_TextDecoration,
        StylePropertyId_FontFamily,
        StylePropertyId_FontSize,
        StylePropertyId_FontWeight,
        StylePropertyId_FontStyle,
        StylePropertyId_FontStretch,
        StylePropertyId_Cursor,
        StylePropertyId_COUNT
    };

    struct StylePropertyMetadata
    {
        StylePropertyId id;
        bool isInheritable;
        std::unique_ptr<BoxedValue> defaultValue;
    };
}

#endif //__BROWSERJAM_STYLEPROPERTY_H__
