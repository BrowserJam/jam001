//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_PAGEELEMENT_H__
#define __BROWSERJAM_PAGEELEMENT_H__

#include <BrowserJam/Style.h>
#include <BrowserJam/Rect.h>
#include <BrowserJam/Point.h>
#include <BrowserJam/DisplayType.h>

#include <memory>
#include <vector>
#include <string>


namespace sb
{
    class Document;

    class PageElement
    {
    public:
        PageElement(const char* tag, Document* doc, PageElement* parent);

        inline void SetParent(PageElement* parent) { mParent = parent; }
        inline PageElement* GetParent() const { return mParent; }

        inline const std::string& GetTag() const { return mTag; }

        inline std::vector<PageElement*>& GetChildren() { return mChildren; }

        DisplayType GetDisplayType() const;
        inline const Rect& GetLayoutBounds() {return mLayoutBounds; }
        inline const Rect& GetContentBounds() {return mContentBounds; }

        virtual void OnMouseMove(float x, float y);
        virtual void OnMouseDown(float x, float y);

        // Update the layout of this element and it's children
        virtual Point Arrange(const Rect& availableSpace, Point cursor, float blockAdvance);

        // Render the element
        virtual void Render();

        inline std::map<std::string, std::string>& GetAttributes() { return mAttributes; }

    protected:
        std::string mTag;
        Document* mDocument;
        PageElement* mParent;
        std::vector<PageElement*> mChildren;

        std::shared_ptr<Style> mStyle;

        Rect mLayoutBounds;
        Rect mContentBounds;

        std::map<std::string, std::string> mAttributes;
    };
}

#endif //__BROWSERJAM_PAGEELEMENT_H__
