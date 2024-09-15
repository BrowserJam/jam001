
namespace sb
{
    // Template class to hold a value of type T
    template <typename T>
    class BoxImpl : public BoxedValue
    {
    public:
        explicit BoxImpl(const T& value) : mValue(value) {}

        const T& GetValue() const { return mValue; }

        virtual std::unique_ptr<BoxedValue> Clone() const override
        {
            return std::make_unique<BoxImpl<T>>(mValue);
        }

    private:
        T mValue;
    };

    // Factory function to create a BoxedValue
    template <typename T>
    std::unique_ptr<BoxedValue> Box(const T& value)
    {
        return std::make_unique<BoxImpl<T>>(value);
    }

    // CanUnbox function to check if the value can be unboxed to type T
    template <typename T>
    bool CanUnbox(BoxedValue* val)
    {
        return dynamic_cast<BoxImpl<T>*>(val) != nullptr;
    }

    // Unbox function to extract the value from BoxedValue
    template <typename T>
    const T& Unbox(BoxedValue* boxedValue)
    {
        // Attempt to cast the BoxedValue to a BoxImpl<T>
        BoxImpl<T>* box = dynamic_cast<BoxImpl<T>*>(boxedValue);
        if (box)
        {
            return box->GetValue();
        }
        else
        {
            throw std::bad_cast();
        }
    }
}