//
// Created by dario on 15.9.2024..
//

#ifndef __BROWSERJAM_BOXEDVALUE_H__
#define __BROWSERJAM_BOXEDVALUE_H__

#include <memory>


namespace sb
{
    /// Base class for boxed values
    class BoxedValue
    {
    public:
        virtual ~BoxedValue() = default;

        virtual std::unique_ptr<BoxedValue> Clone() const = 0;
    };


    template <typename T>
    std::unique_ptr<BoxedValue> Box(const T& value);

    template <typename T>
    bool CanUnbox(BoxedValue* val);

    template <typename T>
    const T& Unbox(BoxedValue* boxedValue);
}

#include <BrowserJam/BoxedValue.inl>

#endif //__BROWSERJAM_BOXEDVALUE_H__
