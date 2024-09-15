add_library(gpu STATIC
  Renderer.cpp Renderer.hpp
)

target_link_libraries(gpu
  PRIVATE
    std
    log
    d3d11
    d3dcompiler
    dxgi
)


add_custom_command(
  OUTPUT shaders.c
  COMMAND embed shaders ${CMAKE_CURRENT_SOURCE_DIR}/shaders.hlsl
  DEPENDS shaders.hlsl
)
target_sources(gpu
  PRIVATE
    shaders.c
)
