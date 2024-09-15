#include <BrowserJam/Document.h>
#include <BrowserJam/Renderer.h>
#include <BrowserJam/Tools.h>
#include <BrowserJam/Cursor.h>
#include <BrowserJam/Elements/PageElement.h>
#include <BrowserJam/Elements/TextElement.h>

#include <iostream>
#include <queue>
#include <unordered_set>

#include <myhtml/api.h>
#include <SDL2/SDL.h>


using namespace sb;


Document::Document(Renderer* renderer): mRenderer(renderer), mRoot(nullptr), mCursor(Cursor_Default)
{
}

void Document::LoadDefaultStyles(const char* css, unsigned int css_length)
{
    mStyleFactory.LoadDefaultStyles(css, css_length);
}

void Document::LoadHTML(const char* html, unsigned int html_length)
{
    Shutdown(); // Clear old data

    myhtml_t* myhtml = myhtml_create();
    myhtml_init(myhtml, MyHTML_OPTIONS_DEFAULT, 1, 0);

    // Initialize the tree
    myhtml_tree_t* tree = myhtml_tree_create();
    myhtml_tree_init(tree, myhtml);

    // Parse HTML code
    myhtml_parse(tree, MyENCODING_UTF_8, html, html_length);

    // Try to find <body/>
    myhtml_tree_node_t* body = nullptr;

    myhtml_collection_t* collection = myhtml_get_nodes_by_tag_id(tree, NULL, MyHTML_TAG_BODY, NULL);
    if (collection && collection->list && collection->length)
    {
        body = collection->list[0];
    }
    else
    {
        body = myhtml_tree_get_document(tree);
    }

    ProcessHTMLNode(tree, body, nullptr);

    // Release resources
    myhtml_collection_destroy(collection);
    myhtml_tree_destroy(tree);
    myhtml_destroy(myhtml);

    // Do some post processing
    PostProcess();
}

void Document::OnMouseMove(float x, float y)
{
    if (mRoot) mRoot->OnMouseMove(x, y);
}

void Document::OnMouseDown(float x, float y)
{
    if (mRoot) mRoot->OnMouseDown(x, y);
}

void Document::ProcessHTMLNode(struct myhtml_tree* tree, struct myhtml_tree_node* node, PageElement* parent)
{
    while (node)
    {
        myhtml_tag_id_t tagId = myhtml_node_tag_id(node);
        const char* tagName = myhtml_tag_name_by_id(tree, tagId, NULL);

        if (tagId == MyHTML_TAG__UNDEF || tagId == MyHTML_TAG_COMMENT ||
            tagId == MyHTML_TAG__DOCTYPE || tagId == MyHTML_TAG_HEADER)
        {
            node = myhtml_node_next(node);
            continue;
        }

        PageElement* element = nullptr;
        if (tagId == MyHTML_TAG__TEXT)
        {
            std::string content = myhtml_node_text(node, NULL);
            Trim(content);

            if (!content.empty())
            {
                RemoveHTMLWhiteSpaces(content); // Remove newlines, multiple spaces, etc...

                element = new TextElement(std::wstring(content.begin(), content.end()).data(),
                    "", this, parent);
            }
        }
        else
        {
            element = new PageElement(tagName, this, parent);


            myhtml_tree_attr_t *attr = myhtml_node_attribute_first(node);

            while (attr)
            {
                const char *name = myhtml_attribute_key(attr, NULL);
                if(name)
                {
                    const char *value = myhtml_attribute_value(attr, NULL);
                    if(value)
                    {
                        element->GetAttributes()[name] = value;
                    }
                }
                attr = myhtml_attribute_next(attr);
            }
        }

        if (tagId == MyHTML_TAG_BODY)
        {
            SetRoot(element);
        }

        if (parent && element)
        {
            parent->GetChildren().push_back(element);
        }
        if (element)
        {
            // Recursively go to the child
            ProcessHTMLNode(tree, myhtml_node_child(node), element);
        }

        // Move to the sibling
        node = myhtml_node_next(node);
    }
}

void Document::PostProcess()
{
    std::queue<PageElement*> q;
    q.push(mRoot);

    while (!q.empty())
    {
        PageElement* cur = q.front();
        q.pop();

        auto& children = cur->GetChildren();

        // Add children to the queue first
        for (uint32_t i = 0; i < children.size(); i++)
        {
            q.push(children[i]);
        }

        // Group inline text into <p> elements
        bool isInInlineBlock = false;
        uint32_t inlineBlockStart = 0u;
        for (uint32_t i = 0; i < children.size(); i++)
        {
            bool isInline = IsInlineTag(children[i]);

            if (!isInInlineBlock && isInline)
            {
                inlineBlockStart = i;
                isInInlineBlock = true;
            }
            if (isInInlineBlock && (!isInline || i == children.size() - 1))
            {
                uint32_t inlineBlockEnd = isInline ? (i + 1) : i;

                std::vector<PageElement*> grouped;
                grouped.assign(children.begin() + inlineBlockStart, children.begin() + inlineBlockEnd);

                children.erase(children.begin() + inlineBlockStart, children.begin() + inlineBlockEnd);

                PageElement* p = new PageElement("", this, cur);
                for (auto& el : grouped)
                {
                    el->SetParent(p);
                    p->GetChildren().push_back(el);
                }

                children.insert(children.begin() + inlineBlockStart, p);

                i = inlineBlockStart + 1; // After the newly created <p> element
                isInInlineBlock = false;
            }
        }
    }
}

void Document::RemoveHTMLWhiteSpaces(std::string& content) const
{
    uint32_t whitespace = 0u;

    for (uint32_t i = 0u; i < content.length(); i++)
    {
        if (isspace(content[i]) && (i == 0u || !isspace(content[i - 1])))
        {
            whitespace = i;
        }
        else if (i > 0 && isspace(content[i - 1]) && !isspace(content[i]))
        {
            if (i - whitespace > 1)
            {
                content.erase(content.begin() + whitespace, content.begin() + i);
                content.insert(content.begin() + whitespace, ' ');
                i = whitespace + 1;
            }
            else
            {
                content[whitespace] = ' ';
            }
        }
    }
}

bool Document::IsInlineTag(PageElement* element) const
{
    static const std::unordered_set<std::string> inline_tags = { "a", "abbr", "acronym",
        "b", "bdo", "big", "br", "button", "cite", "code", "dfn", "em", "i",
        "img", "input", "kbd", "label", "map", "object", "output", "q", "select",
        "small", "span", "strong", "sub", "sup", "textarea", "time", "tt", "var" };

    const std::string& tag = element->GetTag();

    return tag.empty() || inline_tags.find(tag) != inline_tags.end();
}

void Document::DeleteElement(PageElement* element)
{
    if (element == nullptr) return;

    for (auto& child : element->GetChildren())
    {
        DeleteElement(child);
    }
    delete element;
}

void Document::Shutdown()
{
    for (auto& font : mFontCache)
    {
        SafeRelease(&font.dwriteFontFace);
        SafeRelease(&font.dwriteFormat);
    }
    mFontCache.clear();

    for (auto& brush : mBrushCache)
    {
        SafeRelease(&brush.second);
    }
    mBrushCache.clear();

    DeleteElement(mRoot);
    mRoot = nullptr;
}

void Document::InvalidateLayout()
{
    mRoot->Arrange(GetBounds(), {0.0f, 0.0f }, 0.0f);
}

void Document::Render()
{
    auto rt = mRenderer->GetRenderTarget();

    // Begin drawing
    rt->BeginDraw();

    // Clear the background
    rt->Clear(D2D1::ColorF(D2D1::ColorF::White));

    // Reset the transform
    rt->SetTransform(D2D1::Matrix3x2F::Identity());

    mRoot->Render();

    // End drawing
    rt->EndDraw();
}

Rect Document::GetBounds() const
{
    D2D1_SIZE_F size = mRenderer->GetRenderTarget()->GetSize();
    return Rect(0.0f, 0.0f, size.width, size.height);
}

void Document::SetMouseCursor(Cursor cursor)
{
    if (GetMouseCursor() == cursor) return;

    SDL_Cursor* c = SDL_CreateSystemCursor(cursor == Cursor_Pointer ? SDL_SYSTEM_CURSOR_HAND : SDL_SYSTEM_CURSOR_ARROW);
    SDL_SetCursor(c);

    mCursor = cursor;
}

ID2D1SolidColorBrush* Document::CreateSolidColorBrush(unsigned int rgba)
{
    auto it = mBrushCache.find(rgba);
    if (it == mBrushCache.end())
    {
        auto rt = mRenderer->GetRenderTarget();

        ID2D1SolidColorBrush** brush = &mBrushCache[rgba];

        // Brush isn't loaded, create it + cache it
        HRESULT hr = rt->CreateSolidColorBrush(
            D2D1::ColorF((rgba & 0xFFFFFF00) >> 8, (rgba & 0xFF) / 255.0f), brush);

        if (FAILED(hr))
        {
            return nullptr;
        }

        return *brush;
    }

    return it->second;
}

IDWriteTextFormat* Document::CreateTextFormat(const wchar_t* name, float size, FontWeight weight,
    FontStyle style, FontStretch stretch)
{
    for (auto& font : mFontCache)
    {
        if (font.name == name && font.size == size && font.weight == weight && font.style == style
            && font.stretch == stretch)
        {
            return font.dwriteFormat;
        }
    }

    Font font;
    font.name = name;
    font.size = size;
    font.weight = weight;
    font.style = style;
    font.stretch = stretch;

    HRESULT hr = mRenderer->GetWriteFactory()->CreateTextFormat(
        name,                                       // Font family name
        NULL,                                       // Font collection (NULL for system fonts)
        static_cast<DWRITE_FONT_WEIGHT>(weight),    // Font weight
        static_cast<DWRITE_FONT_STYLE>(style),      // Font style
        static_cast<DWRITE_FONT_STRETCH>(stretch),  // Font stretch
        size,                                       // Font size
        L"en-us",                                   // Locale
        &font.dwriteFormat
    );

    if (FAILED(hr))
    {
        return nullptr;
    }


    IDWriteFontCollection* fontCollection;
    font.dwriteFormat->GetFontCollection(&fontCollection);

    UINT32 index;
    BOOL exists;
    fontCollection->FindFamilyName(name, &index, &exists);

    IDWriteFontFamily* fontFamily;
    fontCollection->GetFontFamily(index, &fontFamily);

    IDWriteFont* dwfont;
    fontFamily->GetFirstMatchingFont(static_cast<DWRITE_FONT_WEIGHT>(weight),
        static_cast<DWRITE_FONT_STRETCH>(stretch),
        static_cast<DWRITE_FONT_STYLE>(style),
        &dwfont);

    // Create a font face
    dwfont->CreateFontFace(&font.dwriteFontFace);

    // Get the font metrics
    DWRITE_FONT_METRICS fontMetrics;
    font.dwriteFontFace->GetMetrics(&fontMetrics);

    // Get the glyph index for the space character
    uint32_t spaceChar = (uint32_t)' ';
    UINT16 glyphIndex;
    font.dwriteFontFace->GetGlyphIndices(&spaceChar, 1, &glyphIndex);

    // Get the glyph metrics
    DWRITE_GLYPH_METRICS glyphMetrics;
    font.dwriteFontFace->GetDesignGlyphMetrics(&glyphIndex, 1, &glyphMetrics);

    font.horizontalAdvance = glyphMetrics.advanceWidth * font.size / fontMetrics.designUnitsPerEm;

    float ascent = fontMetrics.ascent * font.size / fontMetrics.designUnitsPerEm;
    float descent = fontMetrics.descent * font.size / fontMetrics.designUnitsPerEm;
    float lineGap = fontMetrics.lineGap * font.size / fontMetrics.designUnitsPerEm;
    font.verticalAdvance = ascent + descent + lineGap;

    // Clean up
    SafeRelease(&dwfont);
    SafeRelease(&fontFamily);
    SafeRelease(&fontCollection);

    mFontCache.push_back(font);

    return font.dwriteFormat;
}

void Document::GetFontInformation(const wchar_t* name, float size, FontWeight weight,
    FontStyle style, FontStretch stretch, float& horizAdvance, float& vertAdvance,
    IDWriteFontFace** fontFace)
{
    horizAdvance = 0;
    vertAdvance = 0;
    *fontFace = nullptr;

    for (auto& font : mFontCache)
    {
        if (font.name == name && font.size == size && font.weight == weight && font.style == style
            && font.stretch == stretch)
        {
            horizAdvance = font.horizontalAdvance;
            vertAdvance = font.verticalAdvance;
            *fontFace = font.dwriteFontFace;
            break;
        }
    }
}