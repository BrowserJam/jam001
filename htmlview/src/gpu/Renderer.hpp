#pragma once

#include "std/Arena.h"
#include "std/Slice.hpp"
#include "std/vec.h"

typedef struct GPU_Device_t *GPU_Device;
typedef struct GPU_Surface_t *GPU_Surface;
typedef struct GPU_Mesh_t *GPU_Mesh;
typedef struct GPU_Image_t *GPU_Image;

enum class GPU_CmdKind {
  SetView,
  BindMesh,
  BindImage,
  SetSurfaceConstants,
  RenderInstance,
};

struct GPU_SetView {
  mat4x4 projection;
};

struct GPU_BindMesh {
  GPU_Mesh mesh;
};

enum GPU_ColorSpace {
  GCS_Linear,
  GCS_Srgb,
};

struct GPU_BindImage {
  GPU_Image image;
  GPU_ColorSpace colorSpace;
};

struct GPU_SetSurfaceConstants {
  Slice<u8> buffer;
};

struct GPU_RenderInstance {};

struct GPU_RenderCmd {
  GPU_CmdKind kind;

  union {
    GPU_SetView setView;
    GPU_BindImage bindImage;
    GPU_BindMesh bindMesh;
    GPU_SetSurfaceConstants setSurfaceConstants;
    GPU_RenderInstance renderInstance;
  };
};

enum GPU_EventType {
  GET_KeyDown,
  GET_KeyUp,
  GET_MouseMove,
  GET_MouseMoveAbs,
  GET_MouseUp,
  GET_MouseWheel,
};

enum GPU_KeyCode {
  K_A,
  K_D,
  K_E,
  K_Q,
  K_R,
  K_S,
  K_W,
  K_Z,
  K_Shift,
  K_Alt,
  K_Left,
  K_Right,
};

struct GPU_Event {
  GPU_EventType kind;

  union {
    struct {
      GPU_KeyCode vk;
      b32 altIsHeld;
    } key;
    struct {
      f32 dx, dy;
    } mouseMove;
    struct {
      i32 x, y;
    } mouseMoveAbs;
    struct {
      u32 button;
      i32 x, y;
    } mouseUp;
    struct {
      // Away from the user; i.e. a negative value means scrolling down
      f32 y;
    } mouseWheel;
  };
};

enum GPU_SurfaceKind {
  GSK_NativeWindow,
};

struct GPU_SurfaceDesc {
  GPU_SurfaceKind kind;
};

struct GPU_NativeWindowSurfaceDesc {
  GPU_SurfaceDesc header;
};

enum class GPU_PixelFormat {
  R8G8B8A8,
  R8,
};

struct GPU_ImageDesc {
  GPU_PixelFormat format;
  u32 width, height;
  Slice<u8> pixels;
};

struct GPU_Vertex {
  v3 position;
  v2 texcoord0;
  v4 color0;
  v4 color1;
};

struct GPU_MeshDesc {
  Slice<GPU_Vertex> vertexData;
  Slice<u32> indices;
};

b32 GPU_create(Arena *arena, GPU_Device *out);
b32 GPU_createMesh(GPU_Device device,
                   Arena *arena,
                   const GPU_MeshDesc *desc,
                   GPU_Mesh *out);
b32 GPU_destroyMesh(GPU_Device device, GPU_Mesh mesh);
b32 GPU_createImage(GPU_Device device,
                    Arena *arena,
                    const GPU_ImageDesc *image,
                    GPU_Image *out);
b32 GPU_discardUpdateImage(GPU_Device device,
                           GPU_Image image,
                           u32 idxSubresource,
                           Slice<u8> newContents,
                           u32 numRows,
                           u32 rowPitch);
b32 GPU_destroyImage(GPU_Device device, GPU_Image image);
b32 GPU_destroy(GPU_Device device);

b32 GPU_createSurface(GPU_Device device,
                      Arena *arena,
                      const GPU_SurfaceDesc *desc,
                      GPU_Surface *out);
void Surface_destroy(GPU_Surface self);
b32 Surface_isCapturingMouse(GPU_Surface surface);
b32 Surface_captureMouse(GPU_Surface pWnd);
b32 Surface_releaseMouse(GPU_Surface pWnd);
b32 Surface_wasClosed(GPU_Surface surface);
b32 Surface_getSize(GPU_Surface surface, i32 *w, i32 *h);

Slice<GPU_Event> Surface_getEvents(GPU_Device device,
                                   Arena *arena,
                                   GPU_Surface surface);

b32 Surface_setCurrentImage(GPU_Surface surface, u32 idxColor, u32 idxDepth);

b32 GPU_beginFrame(GPU_Device renderer, GPU_Surface pWnd, f32 *deltaTime);
b32 GPU_submit(GPU_Device renderer,
               GPU_Surface surface,
               Slice<GPU_RenderCmd> commands);
b32 GPU_present(GPU_Device renderer, GPU_Surface surface);
b32 GPU_present(GPU_Device renderer, GPU_Surface surface, u32 interval);

void *GPU_getRawHandle(GPU_Image image);

b32 GPU_getRawHandle(GPU_Device device, void **out);
