//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_FONTDESCRIPTION_H__
#define __BROWSERJAM_FONTDESCRIPTION_H__


namespace sb
{
    enum FontWeight: int
    {
        FontWeight_Thin = 100,
        FontWeight_ExtraLight = 200,
        FontWeight_UltraLight = 200,
        FontWeight_Light = 300,
        FontWeight_SemiLight = 350,
        FontWeight_Normal = 400,
        FontWeight_Regular = 400,
        FontWeight_Medium = 500,
        FontWeight_DemiBold = 600,
        FontWeight_SemiBold = 600,
        FontWeight_Bold = 700,
        FontWeight_ExtraBold = 800,
        FontWeight_UltraBold = 800,
        FontWeight_Black = 900,
        FontWeight_Heavy = 900,
        FontWeight_ExtraBlack = 950,
        FontWeight_UltraBlack = 950
    };

    enum FontStyle: int
    {
        FontStyle_Normal = 0,
        FontStyle_Oblique = 1,
        FontStyle_Italic = 2
    };

    enum FontStretch: int
    {
        FontStretch_Undefined = 0,
        FontStretch_UltraCondensed = 1,
        FontStretch_ExtraCondensed = 2,
        FontStretch_Condensed = 3,
        FontStretch_SemiCondensed = 4,
        FontStretch_Normal = 5,
        FontStretch_Medium = 5,
        FontStretch_SemiExpanded = 6,
        FontStretch_Expanded = 7,
        FontStretch_ExtraExpanded = 8,
        FontStretch_UltraExpanded = 9
    };

    enum TextDecoration: int
    {
        TextDecoration_None,
        TextDecoration_Underline,
        TextDecoration_LineThrough
    };
}

#endif //__BROWSERJAM_FONTDESCRIPTION_H__
