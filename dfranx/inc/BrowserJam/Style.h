//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_STYLE_H__
#define __BROWSERJAM_STYLE_H__

#include <BrowserJam/BoxedValue.h>
#include <BrowserJam/StyleProperty.h>

#include <map>
#include <assert.h>
#include <memory>


namespace sb
{
    class StyleFactory;

    class Style
    {
    public:
        Style(Style&&) = delete;
        explicit Style(StyleFactory* factory): mFactory(factory) {}

        inline bool Has(StylePropertyId id) const { return mProperties.find(id) != mProperties.end(); }

        inline BoxedValue* Get(StylePropertyId id) const
        {
            assert(Has(id));
            auto it = mProperties.find(id);
            return it->second.get();
        }

        std::unique_ptr<BoxedValue> GetOrDefaultValue(StylePropertyId id) const;

        inline void Set(StylePropertyId id, std::unique_ptr<BoxedValue> value)
        {
            mProperties[id] = std::move(value);
        }

        std::shared_ptr<Style> Clone() const;

    private:
        StyleFactory* mFactory;
        std::map<StylePropertyId, std::unique_ptr<BoxedValue>> mProperties;
    };
}

#endif //__BROWSERJAM_STYLE_H__
