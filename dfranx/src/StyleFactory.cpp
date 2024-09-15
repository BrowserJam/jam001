#include <BrowserJam/StyleFactory.h>
#include <BrowserJam/StyleProperty.h>
#include <BrowserJam/Style.h>
#include <BrowserJam/Tools.h>
#include <BrowserJam/Cursor.h>
#include <BrowserJam/Elements/PageElement.h>

#include <iostream>
#include <string>
#include <sstream>
#include <string.h>


using namespace sb;



#define DEFINE_METADATA(id, inh, def) mMetadata[id] = { id, inh, Box(def) };

void StyleFactory::InitMetadata()
{
    mMetadata.clear();

    DEFINE_METADATA(StylePropertyId_Margin, false, Thickness());
    DEFINE_METADATA(StylePropertyId_Padding, false, Thickness());
    DEFINE_METADATA(StylePropertyId_Border, false, Thickness());
    DEFINE_METADATA(StylePropertyId_Display, false, DisplayType_Block);
    DEFINE_METADATA(StylePropertyId_TextDecoration, false, TextDecoration_None);
    DEFINE_METADATA(StylePropertyId_FontFamily, true, std::wstring(L"Times New Roman"));
    DEFINE_METADATA(StylePropertyId_FontSize, true, 16.0f);
    DEFINE_METADATA(StylePropertyId_FontWeight, true, FontWeight_Normal);
    DEFINE_METADATA(StylePropertyId_FontStyle, true, FontStyle_Normal);
    DEFINE_METADATA(StylePropertyId_FontStretch, true, FontStretch_Normal);
    DEFINE_METADATA(StylePropertyId_Color, true, Color::Black());
    DEFINE_METADATA(StylePropertyId_BorderRadius, false, 0.0f);
    DEFINE_METADATA(StylePropertyId_BorderColor, false, Color::Black());
    DEFINE_METADATA(StylePropertyId_BackgroundColor, false, Color::Black());
    DEFINE_METADATA(StylePropertyId_Cursor, true, Cursor_Default);
}

std::unique_ptr<BoxedValue> StyleFactory::GetDefaultValue(StylePropertyId id) const
{
    auto it = mMetadata.find(id);
    assert(it != mMetadata.end());

    return it->second.defaultValue->Clone();
}

std::string StyleFactory::GetDefaultCSS()
{
    return R"(body {
    display: block;
    margin: 8px;
}

p {
    display: block;
    margin-block-start: 1em;
    margin-block-end: 1em;
}

a {
    display: inline;
    color: #0000EE;
    cursor: pointer;
    text-decoration: underline;
}

div {
    display: block;
}

h1 {
    display: block;
    font-size: 2em;
    margin-block-start: 0.67em;
    margin-block-end: 0.67em;
    font-weight: bold;
}

h2 {
    display: block;
    font-size: 1.5em;
    margin-block-start: 0.83em;
    margin-block-end: 0.83em;
    font-weight: bold;
}

h3 {
    display: block;
    font-size: 1.17em;
    margin-block-start: 1em;
    margin-block-end: 1em;
    font-weight: bold;
}

h4 {
    display: block;
    margin-block-start: 1.33em;
    margin-block-end: 1.33em;
    font-weight: bold;
}

h5 {
    display: block;
    font-size: 0.83em;
    margin-block-start: 1.67em;
    margin-block-end: 1.67em;
    font-weight: bold;
}

h6 {
    display: block;
    font-size: 0.67em;
    margin-block-start: 2.33em;
    margin-block-end: 2.33em;
    font-weight: bold;
}

dd {
    display: block;
    margin-inline-start: 40px;
}

dl {
    display: block;
    margin-block-start: 1em;
    margin-block-end: 1em;
}

dt {
    display: block;
})";
}

bool IsLayoutProperty(StylePropertyId id)
{
    return id == StylePropertyId_Display ||
            id == StylePropertyId_Margin ||
            id == StylePropertyId_Padding;
}

std::shared_ptr<Style> StyleFactory::ComputeStyle(PageElement* element)
{
    std::shared_ptr<Style> style;

    // Try to find style for this element, if not, create an empty style
    auto it = mStyles.find(element->GetTag());
    if (it != mStyles.end())
    {
        style = it->second->Clone();
    }
    else
    {
        style = std::make_shared<Style>(this);
    }

    bool isTextElement = (element->GetTag() == "");

    // Check for inheritable properties that aren't set in this style
    for (const auto& metadata : mMetadata)
    {
        if (metadata.second.isInheritable || (isTextElement && !IsLayoutProperty(metadata.first)))
        {
            if (!style->Has(metadata.first)) // It's inheritable and not set
            {
                // Go upwards in the tree and try to find the style that has the property set
                PageElement* cur = element->GetParent();
                while (cur != nullptr)
                {
                    auto sit = mStyles.find(cur->GetTag());
                    if (sit != mStyles.end())
                    {
                        if (sit->second->Has(metadata.first))
                        {
                            style->Set(metadata.first, sit->second->Get(metadata.first)->Clone());
                            break;
                        }
                    }
                    cur = cur->GetParent();
                }
            }
        }
    }

    return style;
}

void StyleFactory::LoadDefaultStyles(const char* css, unsigned int css_length)
{
    InitMetadata();

    mStyles.clear();

    uint32_t lastPropNameStartIdx = 0u;
    uint32_t lastPropNameEndIdx = 0u;
    uint32_t lastBlockNameIdx = 0u;
    bool isInBlock = false;

    std::string blockName;
    std::shared_ptr<Style> block;

    // Very simple "CSS parser"
    const char* cur = css;
    while (*cur != 0)
    {
        if (*cur == '{')
        {
            if (isInBlock)
            {
                std::cout << "Invalid CSS" << std::endl;
            }

            block = std::make_shared<Style>(this);
            blockName = std::string(css + lastBlockNameIdx, (cur - css) - lastBlockNameIdx);
            Trim(blockName);

            isInBlock = true;
            lastPropNameStartIdx = (cur - css) + 1;
        }
        else if (*cur == '}')
        {
            mStyles[blockName] = block;

            isInBlock = false;
            lastBlockNameIdx = (cur - css) + 1;
        }
        else if (*cur == ':')
        {
            lastPropNameEndIdx = (cur - css);
        }
        else if (*cur == ';' && isInBlock)
        {
            std::string propName = std::string(css + lastPropNameStartIdx,
                lastPropNameEndIdx - lastPropNameStartIdx);
            Trim(propName);

            std::string propValue = std::string(css + lastPropNameEndIdx + 1,
                (cur - css) - lastPropNameEndIdx - 1);
            Trim(propValue);

            lastPropNameStartIdx = (cur - css) + 1;

            ParseProperty(block.get(), propName, propValue);
        }

        cur++;
    }
}

void StyleFactory::ParseProperty(Style* style, const std::string& name, const std::string& value)
{
    if (name == "display")
    {
        style->Set(StylePropertyId_Display, Box<DisplayType>(ParseDisplay(value)));
    }
    else if (name == "padding")
    {
        style->Set(StylePropertyId_Padding, Box(ParseThickness(value)));
    }
    else if (name == "margin")
    {
        style->Set(StylePropertyId_Margin, Box(ParseThickness(value)));
    }
    else if (name == "margin-block-start")
    {
        Thickness margin;
        if (style->Has(StylePropertyId_Margin))
        {
            margin = Unbox<Thickness>(style->Get(StylePropertyId_Margin));
        }
        margin.top = ParseSize(value).ToPixels();
        style->Set(StylePropertyId_Margin, Box(margin));
    }
    else if (name == "margin-block-end")
    {
        Thickness margin;
        if (style->Has(StylePropertyId_Margin))
        {
            margin = Unbox<Thickness>(style->Get(StylePropertyId_Margin));
        }
        margin.bottom = ParseSize(value).ToPixels();
        style->Set(StylePropertyId_Margin, Box(margin));
    }
    else if (name == "margin-inline-start")
    {
        Thickness margin;
        if (style->Has(StylePropertyId_Margin))
        {
            margin = Unbox<Thickness>(style->Get(StylePropertyId_Margin));
        }
        margin.left = ParseSize(value).ToPixels();
        style->Set(StylePropertyId_Margin, Box(margin));
    }
    else if (name == "margin-inline-end")
    {
        Thickness margin;
        if (style->Has(StylePropertyId_Margin))
        {
            margin = Unbox<Thickness>(style->Get(StylePropertyId_Margin));
        }
        margin.right = ParseSize(value).ToPixels();
        style->Set(StylePropertyId_Margin, Box(margin));
    }
    else if (name == "color")
    {
        style->Set(StylePropertyId_Color, Box(ParseColor(value)));
    }
    else if (name == "background-color")
    {
        style->Set(StylePropertyId_BackgroundColor, Box(ParseColor(value)));
    }
    else if (name == "border-color")
    {
        style->Set(StylePropertyId_BorderColor, Box(ParseColor(value)));
    }
    else if (name == "cursor")
    {
        style->Set(StylePropertyId_Cursor, Box<Cursor>(ParseCursor(value)));
    }
    else if (name == "text-decoration")
    {
        style->Set(StylePropertyId_TextDecoration, Box<TextDecoration>(ParseTextDecoration(value)));
    }
    else if (name == "font-family")
    {
        style->Set(StylePropertyId_FontFamily, Box<std::wstring>(ParseFontFamily(value)));
    }
    else if (name == "font-size")
    {
        style->Set(StylePropertyId_FontSize, Box(ParseSize(value).ToPixels()));
    }
    else if (name == "font-weight")
    {
        style->Set(StylePropertyId_FontWeight, Box<FontWeight>(ParseFontWeight(value)));
    }
    else if (name == "font-style")
    {
        style->Set(StylePropertyId_FontStyle, Box<FontStyle>(ParseFontStyle(value)));
    }
    else if (name == "font-stretch")
    {
        style->Set(StylePropertyId_FontStretch, Box<FontStretch>(ParseFontStretch(value)));
    }
}

TextSize StyleFactory::ParseSize(const std::string& value)
{
    if (value.find("em") != std::string::npos)
    {
        return TextSize(std::stof(value), TextSizeUnit_Em);
    }
    return TextSize(std::stof(value));
}
Color StyleFactory::ParseColor(const std::string& value)
{
    if (value.empty())
    {
        return Color::Black();
    }
    if (value[0] == '#')
    {
        int color = std::stoi(value.substr(1), 0, 16);
        if (value.length() == 7) // #RRGGBB
        {
            color = (color << 8) | 0xFF;
        }
        else if (value.length() == 4) // #RGB
        {
            // TODO
        }
        return Color(color);
    }
    return Color::Black();
}
DisplayType StyleFactory::ParseDisplay(const std::string& value)
{
    if (value == "inline") return DisplayType_Inline;
    return DisplayType_Block;
}
TextDecoration StyleFactory::ParseTextDecoration(const std::string& value)
{
    if (value == "underline") return TextDecoration_Underline;
    else if (value == "line-through") return TextDecoration_LineThrough;
    return TextDecoration_None;
}
Cursor StyleFactory::ParseCursor(const std::string& value)
{
    if (value == "pointer") return Cursor_Pointer;
    return Cursor_Default;
}
FontStyle StyleFactory::ParseFontStyle(const std::string& value)
{
    if (value == "italic") return FontStyle_Italic;
    else if (value == "oblique") return FontStyle_Oblique;
    return FontStyle_Normal;
}
FontStretch StyleFactory::ParseFontStretch(const std::string& value)
{
    if (value == "ultra-condensed") return FontStretch_UltraCondensed;
    else if (value == "extra-condensed") return FontStretch_ExtraCondensed;
    else if (value == "condensed") return FontStretch_Condensed;
    else if (value == "semi-condensed") return FontStretch_SemiCondensed;
    else if (value == "semi-expanded") return FontStretch_SemiExpanded;
    else if (value == "expanded") return FontStretch_Expanded;
    else if (value == "extra-expanded") return FontStretch_ExtraExpanded;
    else if (value == "ultra-expanded") return FontStretch_UltraExpanded;
    return FontStretch_Normal;
}
FontWeight StyleFactory::ParseFontWeight(const std::string& value)
{
    if (value == "normal") return FontWeight_Normal;
    else if (value == "bold") return FontWeight_Bold;

    int weight = std::stoi(value);
    if (weight >= 1 && weight <= 1000) return static_cast<FontWeight>(weight);

    return FontWeight_Normal;
}
std::wstring StyleFactory::ParseFontFamily(const std::string& value)
{
    if (value.empty()) return L"Times New Roman";
    if (value[0] == '\"')
    {
        size_t pos = value.find('\"', 1);
        std::string sstr = value.substr(1, pos - 1);
        return std::wstring(sstr.begin(), sstr.end());
    }
    return std::wstring(value.begin(), value.end());
}
Thickness StyleFactory::ParseThickness(const std::string& value)
{
    TextSize m[4];

    std::stringstream ss(value);
    std::string tok;
    int n = 0;
    while (std::getline(ss, tok, ' '))
    {
        m[n] = ParseSize(tok);
        n++;
    }

    if (n == 1)
    {
        float px = m[0].ToPixels();
        return Thickness(px, px, px, px);
    }
    else if (n == 2)
    {
        float x = m[0].ToPixels();
        float y = m[1].ToPixels();
        return Thickness(x, y, x, y);
    }
    else if (n == 4)
    {
        float l = m[0].ToPixels();
        float t = m[1].ToPixels();
        float r = m[2].ToPixels();
        float b = m[3].ToPixels();
        return Thickness(l, t, r, b);
    }

    return Thickness();
}