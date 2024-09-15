//
// Created by dario on 14.9.2024..
//

#ifndef __BROWSERJAM_TOOLS_H__
#define __BROWSERJAM_TOOLS_H__

#include <string>
#include <algorithm>
#include <cctype>


namespace
{
    void Trim(std::string &str)
    {
        auto start = std::find_if_not(str.begin(), str.end(), ::isspace);
        auto end = std::find_if_not(str.rbegin(), str.rend(), ::isspace).base();
        if (start < end)
        {
            str = std::string(start, end);
        }
        else
        {
            str = "";
        }
    }

    template <class T>
    void SafeRelease(T** ppT)
    {
        if (*ppT)
        {
            (*ppT)->Release();
            *ppT = nullptr;
        }
    }
}

#endif //__BROWSERJAM_TOOLS_H__
