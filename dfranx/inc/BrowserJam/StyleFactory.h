//
// Created by dario on 15.9.2024..
//

#ifndef __BROWSERJAM_STYLEFACTORY_H__
#define __BROWSERJAM_STYLEFACTORY_H__

#include <memory>
#include <map>
#include <string>

#include "Color.h"
#include "DisplayType.h"
#include "FontDescription.h"
#include "TextSize.h"
#include "Thickness.h"
#include <BrowserJam/StyleProperty.h>


namespace sb
{
    class Style;
    class PageElement;
    enum StylePropertyId : int;
    struct Color;
    enum DisplayType: int;
    enum FontStyle: int;
    enum FontStretch: int;
    struct TextSize;
    enum Cursor: int;
    struct Thickness;

    class StyleFactory
    {
    public:
        StyleFactory() = default;

        void LoadDefaultStyles(const char* css, unsigned int css_length);

        // Get the default style with all properties for the given element
        std::shared_ptr<Style> ComputeStyle(PageElement* element);

        // Get the default value for given property
        std::unique_ptr<BoxedValue> GetDefaultValue(StylePropertyId property_id) const;

        static std::string GetDefaultCSS();

    private:
        void InitMetadata();

        void ParseProperty(Style* style, const std::string& name, const std::string& value);

        TextSize ParseSize(const std::string& value);
        Color ParseColor(const std::string& value);
        DisplayType ParseDisplay(const std::string& value);
        TextDecoration ParseTextDecoration(const std::string& value);
        Cursor ParseCursor(const std::string& value);
        FontStyle ParseFontStyle(const std::string& value);
        FontStretch ParseFontStretch(const std::string& value);
        FontWeight ParseFontWeight(const std::string& value);
        std::wstring ParseFontFamily(const std::string& value);
        Thickness ParseThickness(const std::string& value);

    private:
        std::map<StylePropertyId, StylePropertyMetadata> mMetadata;
        std::map<std::string, std::shared_ptr<Style>> mStyles;
    };
}

#endif //__BROWSERJAM_STYLEFACTORY_H__
