//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_COLOR_H__
#define __BROWSERJAM_COLOR_H__


namespace sb
{
    struct Color
    {
        Color(): r(0), g(0), b(0), a(0) {}
        Color(float r, float g, float b, float a = 1.0f): r(r), g(g), b(b), a(a) {}
        Color(unsigned char r, unsigned char g, unsigned char b, unsigned char a = 255)
            : r(r / 255.0f), g(g / 255.0f), b(b / 255.0f), a(a / 255.0f) {}
        Color(unsigned int rgba)
        {
            r = ((rgba >> 24) & 0xFF) / 255.0f;
            g = ((rgba >> 16) & 0xFF) / 255.0f;
            b = ((rgba >> 8) & 0xFF) / 255.0f;
            a = (rgba & 0xFF) / 255.0f;
        }

        inline unsigned int AsUInt32() const
        {
            const unsigned int Ri = static_cast<unsigned int>(r * 255.0f);
            const unsigned int Gi = static_cast<unsigned int>(g * 255.0f);
            const unsigned int Bi = static_cast<unsigned int>(b * 255.0f);
            const unsigned int Ai = static_cast<unsigned int>(a * 255.0f);

            return (Ri << 24) | (Gi << 16) | (Bi << 8) | Ai;
        }

        float r;
        float g;
        float b;
        float a;

        inline static Color Transparent() { return Color(1.0f, 1.0f, 1.0f, 0.0f); }
        inline static Color White() { return Color(1.0f, 1.0f, 1.0f); }
        inline static Color Black() { return Color(0.0f, 0.0f, 0.0f); }
        inline static Color Red() { return Color(1.0f, 0.0f, 0.0f); }
        inline static Color Green() { return Color(0.0f, 1.0f, 0.0f); }
        inline static Color Blue() { return Color(0.0f, 0.0f, 1.0f); }
        inline static Color Yellow() { return Color(1.0f, 1.0f, 0.0f); }
        inline static Color Cyan() { return Color(0.0f, 1.0f, 1.0f); }
        inline static Color Magenta() { return Color(1.0f, 0.0f, 1.0f); }
    };
}

#endif //__BROWSERJAM_COLOR_H__
