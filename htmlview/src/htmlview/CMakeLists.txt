add_executable(htmlview)
target_sources(htmlview
  PRIVATE
    entry.cpp
    HTTP.cpp HTTP.hpp
    HTML.cpp HTML.hpp
    DOM.cpp DOM.hpp
)

if(WIN32)
target_sources(htmlview
  PRIVATE
    OS_Win32.cpp
)
endif()

target_link_libraries(htmlview
  PRIVATE
    std
    log
    stb
    gpu

    ws2_32
)

# Embed fonts
add_custom_command(
  OUTPUT font_regular.c
  COMMAND embed font_regular ${CMAKE_CURRENT_SOURCE_DIR}/fonts/LiberationSerif-Regular.ttf
  DEPENDS fonts/LiberationSerif-Regular.ttf
)
add_custom_command(
  OUTPUT font_bold.c
  COMMAND embed font_bold ${CMAKE_CURRENT_SOURCE_DIR}/fonts/LiberationSerif-Bold.ttf
  DEPENDS fonts/LiberationSerif-Bold.ttf
)
target_sources(htmlview
  PRIVATE
    font_regular.c
    font_bold.c
)

if(MSVC)
  target_compile_options(htmlview PRIVATE /permissive- /Zc:preprocessor /Zc:inline)
  target_compile_options(htmlview PRIVATE /w15219)
  target_compile_options(htmlview PRIVATE /w14242)
  target_compile_options(htmlview PRIVATE /w14254)
  target_compile_options(htmlview PRIVATE /w14061)
  target_compile_options(htmlview PRIVATE /w14165)
  target_compile_options(htmlview PRIVATE /w14296)
  target_compile_options(htmlview PRIVATE /w14388)
  target_compile_options(htmlview PRIVATE /w14514)
  target_compile_options(htmlview PRIVATE /w14738)
  target_compile_options(htmlview PRIVATE /w15245)
  target_compile_options(htmlview PRIVATE /w15264)
endif()
