//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_TEXTSIZE_H__
#define __BROWSERJAM_TEXTSIZE_H__


namespace sb
{
    enum TextSizeUnit
    {
        TextSizeUnit_Pixel,
        TextSizeUnit_Em
    };

    struct TextSize
    {
        TextSize() : unit(TextSizeUnit_Pixel), value(0.0f) {}
        TextSize(float v) : unit(TextSizeUnit_Pixel), value(v) {}
        TextSize(float v, TextSizeUnit u) : unit(u), value(v) {}

        float ToPixels() const
        {
            if (unit == TextSizeUnit_Em) return value * 16.0f;
            return value; // TextSizeUnit_Pixel
        }

        float value;
        TextSizeUnit unit;
    };
}

#endif //__BROWSERJAM_TEXTSIZE_H__
