cmake_minimum_required(VERSION 3.9)

project(BrowserJam)
set(CMAKE_CXX_STANDARD 17)

find_package(SDL2 REQUIRED)


option(MyHTML_BUILD_WITHOUT_THREADS "Build without POSIX Threads" ON)
option(MyCORE_BUILD_WITHOUT_THREADS "Build MyCORE without POSIX Threads" ON)
option(MyHTML_BUILD_SHARED "Build shared library" OFF)
option(MyHTML_BUILD_STATIC "Build static library" ON)
option(MyHTML_INSTALL_HEADER "Install header files" OFF)
add_subdirectory(libs/myhtml)

add_executable(BrowserJam main.cpp
               inc/BrowserJam/Thickness.h
               inc/BrowserJam/Color.h
               inc/BrowserJam/TextSize.h
               inc/BrowserJam/StyleProperty.h
               inc/BrowserJam/Style.h
               inc/BrowserJam/Elements/PageElement.h
               src/PageElement.cpp
               inc/BrowserJam/Renderer.h
               src/Renderer.cpp
               inc/BrowserJam/Tools.h
               inc/BrowserJam/Document.h
               src/Document.cpp
               inc/BrowserJam/FontDescription.h
               inc/BrowserJam/Elements/TextElement.h
               inc/BrowserJam/DisplayType.h
               inc/BrowserJam/Rect.h
               src/TextElement.cpp
               inc/BrowserJam/StyleFactory.h
               src/StyleFactory.cpp
               inc/BrowserJam/Cursor.h
               inc/BrowserJam/BoxedValue.h
               inc/BrowserJam/BoxedValue.inl
               src/Style.cpp
               inc/BrowserJam/Point.h)

target_include_directories(BrowserJam PRIVATE inc/ libs/ libs/myhtml/include/)
target_link_libraries(BrowserJam PRIVATE SDL2::SDL2 d2d1 dwrite myhtml_static wininet)