#include <BrowserJam/Style.h>
#include <BrowserJam/StyleFactory.h>
#include <BrowserJam/BoxedValue.h>


using namespace sb;


std::unique_ptr<BoxedValue> Style::GetOrDefaultValue(StylePropertyId id) const
{
    auto it = mProperties.find(id);
    if (it == mProperties.end()) return mFactory->GetDefaultValue(id);
    return it->second->Clone();
}

std::shared_ptr<Style> Style::Clone() const
{
    std::shared_ptr<Style> style = std::make_shared<Style>(mFactory);
    for (auto& prop : mProperties)
    {
        style->mProperties[prop.first] = prop.second->Clone();
    }
    return style;
}