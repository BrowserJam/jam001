#include "gpu/Renderer.hpp"
#include "log/log.h"
#include "std/Check.h"
#include "std/Hash.h"
#include "std/Utils.hpp"

#include <d3d11.h>
#include <d3d11_1.h>
#include <d3dcompiler.h>
#include <winuser.h>

#include "embed/embed.h"

#define GPU_DEBUG (0)

EMBED_DECL(shaders);

struct DepthBuffer {
  ID3D11Texture2D *texture;
  ID3D11DepthStencilView *view;
};

struct GPU_NativeWindowSurface {
  HWND handle;
  IDXGISwapChain *pSwapChain = nullptr;
  ID3D11Texture2D *tex = nullptr;
  ID3D11RenderTargetView *rtv = nullptr;
  ID3D11RenderTargetView *rtvSrgb = nullptr;

  b32 wasClosed = false;

  DepthBuffer depthBuffer;
};

struct GPU_Surface_t {
  GPU_SurfaceKind kind;

  b32 isSizeMoving = false;
  b32 isOccluded = false;
  b32 isCapturing = false;
  UINT resizeWidth = 0;
  UINT resizeHeight = 0;

  u32 width, height;

  union {
    GPU_NativeWindowSurface nativeWindow;
  };
};

struct VertexShader {
  ID3DBlob *blob;
  ID3D11VertexShader *shader;

  ID3D11InputLayout *inputLayout;
};

struct SurfaceShader {
  ID3D11PixelShader *pixelShader;

  ID3D11RasterizerState *rasterizerState;
  ID3D11DepthStencilState *depthStencilState;
  ID3D11SamplerState *samplerState;
};

struct GPU_Device_t {
  ID3D11Device1 *pDevice = nullptr;
  ID3D11DeviceContext1 *pCtx = nullptr;
  IDXGIFactory2 *pDxgiFactory = nullptr;

  VertexShader vertexShader;

  SurfaceShader surfaceShader;
  ID3D11SamplerState *samplerBilinear;
  ID3D11BlendState *blendState;

  LARGE_INTEGER timePrev;
};

struct GPU_Mesh_t {
  ID3D11Buffer *vertexBuffer;
  u32 stride;
  u32 offset;
  ID3D11Buffer *indexBuffer;
  DXGI_FORMAT indexFormat;
  D3D11_PRIMITIVE_TOPOLOGY topology;
  u32 numIndices;
};

struct GPU_Image_t {
  ID3D11Texture2D *texture;
  ID3D11ShaderResourceView *view;
  ID3D11ShaderResourceView *viewSrgb;
};

struct ViewConstants {
  mat4x4 projection;
};

struct ModelConstants {};

struct BatchConstants {};

#define FMT_BLOB(blob) \
  (u32)(blob)->GetBufferSize(), (const char *)(blob)->GetBufferPointer()

static b32 VertexShader_init(VertexShader *self,
                             GPU_Device_t *renderer,
                             const char *vsEntry) {
  ID3D11Device1 *device = renderer->pDevice;
  ID3DBlob *vsBlob, *err;
  HRESULT hr;

  UINT flags1 = 0;
#if GPU_DEBUG
  flags1 |= D3DCOMPILE_DEBUG;
#endif

  hr = D3DCompile(shaders, shaders_len, "shaders.hlsl", nullptr, nullptr,
                  vsEntry, "vs_5_0", flags1, 0, &vsBlob, &err);
  if (!SUCCEEDED(hr)) {
    log_error("Failed to compile vertex shader:\n%.*s", FMT_BLOB(err));
    return false;
  }
  if (err) {
    err->Release();
    err = nullptr;
  }

  device->CreateVertexShader(vsBlob->GetBufferPointer(),
                             vsBlob->GetBufferSize(), nullptr, &self->shader);

  D3D11_INPUT_ELEMENT_DESC elems[4];
  elems[0] = {"POSITION",
              0,
              DXGI_FORMAT_R32G32B32_FLOAT,
              0,
              0 * sizeof(f32),
              D3D11_INPUT_PER_VERTEX_DATA,
              0};
  elems[1] = {"TEXCOORD",
              0,
              DXGI_FORMAT_R32G32_FLOAT,
              0,
              3 * sizeof(f32),
              D3D11_INPUT_PER_VERTEX_DATA,
              0};
  elems[2] = {"COLOR",
              0,
              DXGI_FORMAT_R32G32B32A32_FLOAT,
              0,
              5 * sizeof(f32),
              D3D11_INPUT_PER_VERTEX_DATA,
              0};
  elems[3] = {"COLOR",
              1,
              DXGI_FORMAT_R32G32B32A32_FLOAT,
              0,
              9 * sizeof(f32),
              D3D11_INPUT_PER_VERTEX_DATA,
              0};

  device->CreateInputLayout(elems, 4, vsBlob->GetBufferPointer(),
                            vsBlob->GetBufferSize(), &self->inputLayout);

  self->blob = vsBlob;
  return true;
}

static void VertexShader_bind(const VertexShader *self,
                              ID3D11DeviceContext1 *ctx) {
  ctx->VSSetShader(self->shader, nullptr, 0);
}

static b32 SurfaceShader_init(SurfaceShader *self,
                              GPU_Device_t *renderer,
                              const char *psEntry) {
  ID3D11Device1 *device = renderer->pDevice;
  ID3DBlob *psBlob, *err;
  HRESULT hr;

  UINT flags1 = 0;
#if GPU_DEBUG
  flags1 |= D3DCOMPILE_DEBUG;
#endif

  hr = D3DCompile(shaders, shaders_len, "shaders.hlsl", nullptr, nullptr,
                  psEntry, "ps_5_0", flags1, 0, &psBlob, &err);
  if (!SUCCEEDED(hr)) {
    log_error("Failed to compile fragment shader:\n%.*s", FMT_BLOB(err));
    return false;
  }
  if (err) {
    err->Release();
    err = nullptr;
  }

  device->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(),
                            nullptr, &self->pixelShader);

  D3D11_RASTERIZER_DESC rasterizerdesc = {};
  rasterizerdesc.FillMode = D3D11_FILL_SOLID;
  rasterizerdesc.CullMode = D3D11_CULL_BACK;
  device->CreateRasterizerState(&rasterizerdesc, &self->rasterizerState);

  D3D11_DEPTH_STENCIL_DESC depthstencildesc = {};
  depthstencildesc.DepthEnable = TRUE;
  depthstencildesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
  depthstencildesc.DepthFunc = D3D11_COMPARISON_LESS;
  device->CreateDepthStencilState(&depthstencildesc, &self->depthStencilState);

  psBlob->Release();

  return true;
}

static void SurfaceShader_destroy(SurfaceShader *self) {
  self->depthStencilState->Release();
  self->rasterizerState->Release();
  self->pixelShader->Release();
}

static void SurfaceShader_bind(SurfaceShader *self, ID3D11DeviceContext1 *ctx) {
  ctx->OMSetDepthStencilState(self->depthStencilState, 0);
  ctx->RSSetState(self->rasterizerState);
  ctx->PSSetShader(self->pixelShader, nullptr, 0);
}

enum class TexcoordSet {
  Primary,
  Secondary,
};

static void DepthBuffer_destroy(DepthBuffer *self) {
  self->view->Release();
  self->texture->Release();
  self->view = nullptr;
  self->texture = nullptr;
}

static b32 DepthBuffer_init(DepthBuffer *self,
                            ID3D11Device1 *device,
                            GPU_NativeWindowSurface *window) {
  D3D11_TEXTURE2D_DESC desc;

  ID3D11Texture2D *frameBuffer;
  window->pSwapChain->GetBuffer(0, __uuidof(ID3D11Texture2D),
                                reinterpret_cast<void **>(&frameBuffer));
  frameBuffer->GetDesc(&desc);
  frameBuffer->Release();

  desc.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
  desc.BindFlags = D3D11_BIND_DEPTH_STENCIL;

  ID3D11Texture2D *depthBuffer;
  device->CreateTexture2D(&desc, nullptr, &depthBuffer);

  ID3D11DepthStencilView *depthBufferView;
  device->CreateDepthStencilView(depthBuffer, nullptr, &depthBufferView);

  self->texture = depthBuffer;
  self->view = depthBufferView;
  return true;
}

static LRESULT wndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  GPU_Surface pWnd = (GPU_Surface)GetWindowLongPtr(hWnd, GWLP_USERDATA);
  switch (msg) {
    case WM_CREATE: {
      if (!pWnd) {
        pWnd = (GPU_Surface)((CREATESTRUCT *)lParam)->lpCreateParams;
      }
      CHECK(pWnd->kind == GSK_NativeWindow);
      SetWindowLongPtrW(hWnd, GWLP_USERDATA, (LONG_PTR)pWnd);

      RECT rc = {0};
      GetWindowRect(hWnd, &rc);
      int win_w = rc.right - rc.left;
      int win_h = rc.bottom - rc.top;

      int screen_w = GetSystemMetrics(SM_CXSCREEN);
      int screen_h = GetSystemMetrics(SM_CYSCREEN);

      SetWindowPos(hWnd, HWND_TOP, (screen_w - win_w) / 2,
                   (screen_h - win_h) / 2, 0, 0, SWP_NOSIZE);

      return 0;
    }
    case WM_PAINT: {
      if (pWnd->isSizeMoving) {
      } else {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hWnd, &ps);
        EndPaint(hWnd, &ps);
      }
      break;
    }
    case WM_ENTERSIZEMOVE: {
      pWnd->isSizeMoving = true;
      break;
    }
    case WM_EXITSIZEMOVE: {
      pWnd->isSizeMoving = false;
      break;
    }
    case WM_CLOSE: {
      pWnd->nativeWindow.wasClosed = true;
      break;
    }
    case WM_SIZE: {
      if (wParam == SIZE_MINIMIZED) {
        return 0;
      }
      pWnd->resizeWidth = (UINT)LOWORD(lParam);
      pWnd->resizeHeight = (UINT)HIWORD(lParam);
      return 0;
    }
  }

  return DefWindowProc(hWnd, msg, wParam, lParam);
}

b32 GPU_create(Arena *arena, GPU_Device *out) {
  CHECK(arena);
  CHECK(out);

  D3D_FEATURE_LEVEL bufFeatureLevels[2] = {D3D_FEATURE_LEVEL_11_1,
                                           D3D_FEATURE_LEVEL_11_0};
  Slice<D3D_FEATURE_LEVEL> featureLevels = {bufFeatureLevels, 2};
  IDXGIFactory2 *dxgiFactory = nullptr;
  IDXGIAdapter *dxgiAdapter = nullptr;
  D3D_DRIVER_TYPE driverType = D3D_DRIVER_TYPE_HARDWARE;

  ID3D11Device *baseDevice = nullptr;
  ID3D11DeviceContext *baseDeviceContext = nullptr;

  UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
#if GPU_DEBUG
  flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

  D3D_FEATURE_LEVEL chosenFeatureLevel;
  D3D11CreateDevice(dxgiAdapter, driverType, nullptr, flags, featureLevels.data,
                    featureLevels.length, D3D11_SDK_VERSION, &baseDevice,
                    &chosenFeatureLevel, &baseDeviceContext);

  log_info("Chosen D3D feature level: %d.%d", chosenFeatureLevel >> 12,
           (chosenFeatureLevel >> 8) & 0xF);

  ID3D11Device1 *device;
  baseDevice->QueryInterface(__uuidof(ID3D11Device1),
                             reinterpret_cast<void **>(&device));
  CHECK(device);
  baseDevice->Release();

  D3D11_FEATURE_DATA_D3D11_OPTIONS3 opts3;
  HRESULT res = device->CheckFeatureSupport(D3D11_FEATURE_D3D11_OPTIONS3,
                                            &opts3, sizeof(opts3));
  if (SUCCEEDED(res)) {
    if (!opts3.VPAndRTArrayIndexFromAnyShaderFeedingRasterizer) {
      log_error(
          "D3D 11.3 feature VPAndRTArrayIndexFromAnyShaderFeedingRasterizer is "
          "not supported");
      return false;
    }
  }

  ID3D11DeviceContext1 *deviceContext;
  baseDeviceContext->QueryInterface(__uuidof(ID3D11DeviceContext1),
                                    reinterpret_cast<void **>(&deviceContext));
  CHECK(deviceContext);
  baseDeviceContext->Release();

  if (!dxgiFactory) {
    CHECK(dxgiAdapter == nullptr);
    IDXGIDevice1 *dxgiDevice;
    device->QueryInterface(__uuidof(IDXGIDevice1),
                           reinterpret_cast<void **>(&dxgiDevice));
    dxgiDevice->GetAdapter(&dxgiAdapter);
    dxgiDevice->Release();
    dxgiAdapter->GetParent(__uuidof(IDXGIFactory2),
                           reinterpret_cast<void **>(&dxgiFactory));
  }

  DXGI_ADAPTER_DESC adapterDesc;
  dxgiAdapter->GetDesc(&adapterDesc);
  log_info("Graphics adapter: %S", adapterDesc.Description);

  dxgiAdapter->Release();
  dxgiAdapter = nullptr;

  // Window
  WNDCLASSA wndClass = {0, wndProc, 0, 0, 0, 0, 0, 0, 0, "htmlview"};
  RegisterClassA(&wndClass);

  GPU_Device renderer = alloc<GPU_Device_t>(arena);
  renderer->pCtx = deviceContext;
  renderer->pDevice = device;
  renderer->pDxgiFactory = dxgiFactory;

  VertexShader_init(&renderer->vertexShader, renderer, "vs_main");

  if (!SurfaceShader_init(&renderer->surfaceShader, renderer, "ps_main")) {
    log_error("Failed to create surface shader");
    return false;
  }

  D3D11_SAMPLER_DESC samplerdesc = {};
  samplerdesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
  samplerdesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
  samplerdesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
  samplerdesc.ComparisonFunc = D3D11_COMPARISON_NEVER;
  samplerdesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;

  device->CreateSamplerState(&samplerdesc, &renderer->samplerBilinear);

  D3D11_BLEND_DESC blendDesc = {};
  blendDesc.RenderTarget[0].BlendEnable = TRUE;
  blendDesc.RenderTarget[0].SrcBlend = D3D11_BLEND_SRC_ALPHA;
  blendDesc.RenderTarget[0].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
  blendDesc.RenderTarget[0].BlendOp = D3D11_BLEND_OP_ADD;
  blendDesc.RenderTarget[0].SrcBlendAlpha = D3D11_BLEND_ONE;
  blendDesc.RenderTarget[0].DestBlendAlpha = D3D11_BLEND_ZERO;
  blendDesc.RenderTarget[0].BlendOpAlpha = D3D11_BLEND_OP_ADD;
  blendDesc.RenderTarget[0].RenderTargetWriteMask =
      D3D11_COLOR_WRITE_ENABLE_ALL;
  device->CreateBlendState(&blendDesc, &renderer->blendState);

  QueryPerformanceCounter(&renderer->timePrev);

  *out = renderer;
  return true;
}

void Surface_destroy(GPU_Surface self) {
  switch (self->kind) {
    case GSK_NativeWindow: {
      DepthBuffer_destroy(&self->nativeWindow.depthBuffer);
      self->nativeWindow.rtv->Release();
      self->nativeWindow.rtvSrgb->Release();
      self->nativeWindow.pSwapChain->Release();
      self->nativeWindow.tex->Release();
      DestroyWindow(self->nativeWindow.handle);
      break;
    }
  }
}

#if GPU_DEBUG && !__MINGW32__
#include "dxgidebug.h"
using PFN_DXGIGetDebugInterface = HRESULT (*WINAPI)(REFIID riid,
                                                    void **ppDebug);

static void reportLeaks() {
  HMODULE mod = LoadLibraryA("Dxgidebug.dll");
  if (!mod) {
    return;
  }

  PFN_DXGIGetDebugInterface getDebug =
      (PFN_DXGIGetDebugInterface)GetProcAddress(mod, "DXGIGetDebugInterface");
  IDXGIDebug *pDxgiDebug = nullptr;
  HRESULT hr = getDebug(IID_PPV_ARGS(&pDxgiDebug));
  if (hr == E_NOINTERFACE) {
    FreeLibrary(mod);
    return;
  }

  pDxgiDebug->ReportLiveObjects(DXGI_DEBUG_D3D11, DXGI_DEBUG_RLO_ALL);
  pDxgiDebug->Release();
  FreeLibrary(mod);
}
#else
static void reportLeaks() {}
#endif

b32 GPU_destroy(GPU_Device renderer) {
  CHECK(renderer->pDevice != nullptr);

  renderer->pCtx->Flush();

  VertexShader *vs = &renderer->vertexShader;
  if (vs->shader) {
    if (vs->inputLayout) {
      vs->inputLayout->Release();
    }

    vs->shader->Release();
    vs->blob->Release();
    vs->shader = nullptr;
    vs->blob = nullptr;
  } else {
    CHECK(vs->blob == nullptr);
  }

  SurfaceShader_destroy(&renderer->surfaceShader);

  renderer->pCtx->Release();
  renderer->pDxgiFactory->Release();
  renderer->pDevice->Release();

  renderer->pDevice = nullptr;

  reportLeaks();

  return true;
}

b32 GPU_createNativeWindowSurface(GPU_Device device,
                                  Arena *arena,
                                  const GPU_NativeWindowSurfaceDesc *desc,
                                  GPU_Surface *out) {
  GPU_Surface self = alloc<GPU_Surface_t>(arena);
  self->kind = GSK_NativeWindow;
  HWND window = CreateWindowExA(0, "htmlview", "htmlview",
                                WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0, 1280,
                                720, nullptr, nullptr, nullptr, self);

  DXGI_SWAP_CHAIN_DESC1 swapChainDesc;
  swapChainDesc.Width = 0;
  swapChainDesc.Height = 0;
  swapChainDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  swapChainDesc.Stereo = FALSE;
  swapChainDesc.SampleDesc.Count = 1;
  swapChainDesc.SampleDesc.Quality = 0;
  swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
  swapChainDesc.BufferCount = 3;
  swapChainDesc.Scaling = DXGI_SCALING_STRETCH;
  swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
  swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED;
  swapChainDesc.Flags = 0;

  IDXGISwapChain1 *swapChain;

  HRESULT res;
  res = device->pDxgiFactory->CreateSwapChainForHwnd(
      device->pDevice, window, &swapChainDesc, nullptr, nullptr, &swapChain);
  if (!SUCCEEDED(res)) {
    log_error("CreateSwapChainForHwnd failed [%d]", res);
    DestroyWindow(window);
    return false;
  }

  ID3D11Texture2D *frameBuffer;

  swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D),
                       reinterpret_cast<void **>(&frameBuffer));

  ID3D11RenderTargetView *rtv, *rtvSrgb;
  D3D11_RENDER_TARGET_VIEW_DESC framebufferDesc = {};
  framebufferDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;

  framebufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  device->pDevice->CreateRenderTargetView(frameBuffer, &framebufferDesc, &rtv);
  framebufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
  device->pDevice->CreateRenderTargetView(frameBuffer, &framebufferDesc,
                                          &rtvSrgb);

  self->nativeWindow.handle = window;
  self->nativeWindow.pSwapChain = swapChain;
  self->nativeWindow.tex = frameBuffer;
  self->nativeWindow.rtv = rtv;
  self->nativeWindow.rtvSrgb = rtvSrgb;

  if (!DepthBuffer_init(&self->nativeWindow.depthBuffer, device->pDevice,
                        &self->nativeWindow)) {
    return false;
  }

  *out = self;

  return true;
}

b32 GPU_createSurface(GPU_Device device,
                      Arena *arena,
                      const GPU_SurfaceDesc *desc,
                      GPU_Surface *out) {
  switch (desc->kind) {
    case GSK_NativeWindow:
      return GPU_createNativeWindowSurface(
          device, arena, (const GPU_NativeWindowSurfaceDesc *)desc, out);
  }

  return false;
}

b32 GPU_createMesh(GPU_Device renderer,
                   Arena *arena,
                   const GPU_MeshDesc *desc,
                   GPU_Mesh *out) {
  ID3D11Buffer *vertexBuffer, *indexBuffer;

  // Upload the vertex buffers
  D3D11_BUFFER_DESC bufferDesc = {};
  bufferDesc.ByteWidth = 0;
  bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
  bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;

  D3D11_SUBRESOURCE_DATA vertexData = {desc->vertexData.data};
  bufferDesc.ByteWidth = desc->vertexData.length * sizeof(GPU_Vertex);
  renderer->pDevice->CreateBuffer(&bufferDesc, &vertexData, &vertexBuffer);

  // Upload the index buffer
  bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
  bufferDesc.ByteWidth = desc->indices.length * 4;
  D3D11_SUBRESOURCE_DATA data = {desc->indices.data};
  renderer->pDevice->CreateBuffer(&bufferDesc, &data, &indexBuffer);

  GPU_Mesh mesh = alloc<GPU_Mesh_t>(arena);
  mesh->vertexBuffer = vertexBuffer;
  mesh->indexBuffer = indexBuffer;
  mesh->indexFormat = DXGI_FORMAT_R32_UINT;
  mesh->topology = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
  mesh->stride = sizeof(GPU_Vertex);
  mesh->offset = 0;
  mesh->numIndices = desc->indices.length;

  *out = mesh;
  return true;
}

b32 GPU_destroyMesh(GPU_Device device, GPU_Mesh mesh) {
  mesh->indexBuffer->Release();
  mesh->vertexBuffer->Release();

  return true;
}

static b32 mapVK(WPARAM vk, GPU_KeyCode &out) {
  switch (vk) {
    case 'W':
      out = K_W;
      break;
    case 'A':
      out = K_A;
      break;
    case 'S':
      out = K_S;
      break;
    case 'D':
      out = K_D;
      break;
    case 'Z':
      out = K_Z;
      break;
    case 'R':
      out = K_R;
      break;
    case 'Q':
      out = K_Q;
      break;
    case 'E':
      out = K_E;
      break;
    case VK_SHIFT:
      out = K_Shift;
      break;
    case VK_LEFT:
      out = K_Left;
      break;
    case VK_RIGHT:
      out = K_Right;
      break;
    case VK_LMENU:
      out = K_Alt;
      break;
    default:
      return false;
  }
  return true;
}

Slice<GPU_Event> Surface_getEvents(GPU_Device device,
                                   Arena *arena,
                                   GPU_Surface surface) {
  if (surface->kind != GSK_NativeWindow) {
    return {nullptr, 0};
  }

  GPU_NativeWindowSurface *pWnd = &surface->nativeWindow;
  ArenaTemp temp = getScratch(&arena, 1);
  Vector<GPU_Event> events;

  MSG msg;
  while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.hwnd != pWnd->handle) {
      TranslateMessage(&msg);
      DispatchMessage(&msg);
      continue;
    }

    switch (msg.message) {
      case WM_SYSKEYDOWN:
      case WM_KEYDOWN: {
        GPU_KeyCode vk;
        if (mapVK(msg.wParam, vk)) {
          GPU_Event *dst = append(temp.arena, &events);
          dst->kind = GET_KeyDown;
          dst->key.vk = vk;
          dst->key.altIsHeld = msg.lParam & (1 << 29);
        }
        break;
      }
      case WM_SYSKEYUP:
      case WM_KEYUP: {
        GPU_KeyCode vk;
        if (mapVK(msg.wParam, vk)) {
          GPU_Event *dst = append(temp.arena, &events);
          dst->kind = GET_KeyUp;
          dst->key.vk = vk;
          dst->key.altIsHeld = msg.lParam & (1 << 29);
        }
        break;
      }
      case WM_INPUT: {
        if (Surface_isCapturingMouse(surface)) {
          UINT dwSize = sizeof(RAWINPUT);
          static BYTE lpb[sizeof(RAWINPUT)];

          GetRawInputData((HRAWINPUT)msg.lParam, RID_INPUT, lpb, &dwSize,
                          sizeof(RAWINPUTHEADER));
          RAWINPUT *raw = (RAWINPUT *)lpb;
          if (raw->header.dwType != RIM_TYPEMOUSE) {
            continue;
          }

          GPU_Event *dst = append(temp.arena, &events);
          dst->kind = GET_MouseMove;
          float dx, dy;
          dst->mouseMove.dx = raw->data.mouse.lLastX;
          dst->mouseMove.dy = raw->data.mouse.lLastY;
        }
        break;
      }
      case WM_MOUSEMOVE: {
        GPU_Event *dst = append(temp.arena, &events);
        dst->kind = GET_MouseMoveAbs;
        dst->mouseMoveAbs.x = LOWORD(msg.lParam);
        dst->mouseMoveAbs.y = HIWORD(msg.lParam);
        break;
      }
      case WM_LBUTTONUP: {
        GPU_Event *dst = append(temp.arena, &events);
        dst->kind = GET_MouseUp;
        dst->mouseUp.button = 0;
        dst->mouseUp.x = LOWORD(msg.lParam);
        dst->mouseUp.y = HIWORD(msg.lParam);
        break;
      }
      case WM_MOUSEWHEEL: {
        // NOTE(danielm): scroll amount is a signed number in the high word of
        // wparam; extract the word then sign-extend
        i32 scrollSigned = (i32)(i16)(msg.wParam >> 16);
        GPU_Event *dst = append(temp.arena, &events);
        dst->kind = GET_MouseWheel;
        dst->mouseWheel.y = (f32)scrollSigned / (f32)WHEEL_DELTA;
        break;
      }
      case WM_KILLFOCUS:
        Surface_releaseMouse(surface);
        break;
      case WM_ACTIVATE:
        if (msg.wParam == WA_INACTIVE) {
          Surface_releaseMouse(surface);
        }
        break;
    }

    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  Slice<GPU_Event> ret = copyToSlice(arena, events);
  releaseScratch(temp);
  return ret;
}

b32 Surface_isCapturingMouse(GPU_Surface surface) {
  return surface->isCapturing;
}

b32 NativeWindowSurface_captureMouse(GPU_Surface surf) {
  GPU_NativeWindowSurface *pWnd = &surf->nativeWindow;
  RECT rcClip;
  GetWindowRect(pWnd->handle, &rcClip);
  SetCapture(pWnd->handle);
  ClipCursor(&rcClip);

  int c = ShowCursor(FALSE);
  while (c >= 0) {
    c = ShowCursor(FALSE);
  }

  RAWINPUTDEVICE Rid[1];
  Rid[0].usUsagePage = 0x01;  // HID_USAGE_PAGE_GENERIC
  Rid[0].usUsage = 0x02;      // HID_USAGE_GENERIC_MOUSE
  // Rid[0].dwFlags = RIDEV_NOLEGACY;
  Rid[0].dwFlags = 0;
  Rid[0].hwndTarget = pWnd->handle;
  RegisterRawInputDevices(Rid, 1, sizeof(Rid[0]));
  surf->isCapturing = true;
  return true;
}

b32 NativeWindowSurface_releaseMouse(GPU_Surface surf) {
  GPU_NativeWindowSurface *pWnd = &surf->nativeWindow;

  RAWINPUTDEVICE Rid[1];
  Rid[0].usUsagePage = 0x01;  // HID_USAGE_PAGE_GENERIC
  Rid[0].usUsage = 0x02;      // HID_USAGE_GENERIC_MOUSE
  Rid[0].dwFlags = RIDEV_REMOVE;
  Rid[0].hwndTarget = pWnd->handle;
  RegisterRawInputDevices(Rid, 1, sizeof(Rid[0]));

  ClipCursor(NULL);
  int c = ShowCursor(TRUE);
  while (c < 0) {
    c = ShowCursor(TRUE);
  }
  ReleaseCapture();
  surf->isCapturing = false;
  return true;
}

b32 Surface_captureMouse(GPU_Surface surf) {
  switch (surf->kind) {
    case GSK_NativeWindow:
      return NativeWindowSurface_captureMouse(surf);
  }

  return false;
}

b32 Surface_releaseMouse(GPU_Surface surf) {
  switch (surf->kind) {
    case GSK_NativeWindow:
      return NativeWindowSurface_releaseMouse(surf);
  }

  return false;
}

b32 GPU_beginFrame(GPU_Device renderer,
                   GPU_Surface surf,
                   GPU_NativeWindowSurface *pWnd,
                   f32 *deltaTime) {
  if (surf->isOccluded &&
      pWnd->pSwapChain->Present(0, DXGI_PRESENT_TEST) == DXGI_STATUS_OCCLUDED) {
    return false;
  }

  surf->isOccluded = false;

  if (surf->resizeWidth != 0 && surf->resizeHeight != 0) {
    if (pWnd->rtv) {
      pWnd->rtv->Release();
      pWnd->rtvSrgb->Release();
      pWnd->tex->Release();
      pWnd->rtv = nullptr;
      pWnd->rtvSrgb = nullptr;
      pWnd->tex = nullptr;
    }

    DepthBuffer_destroy(&pWnd->depthBuffer);

    pWnd->pSwapChain->ResizeBuffers(0, surf->resizeWidth, surf->resizeHeight,
                                    DXGI_FORMAT_UNKNOWN, 0);
    surf->width = surf->resizeWidth;
    surf->height = surf->resizeHeight;
    surf->resizeWidth = surf->resizeHeight = 0;

    DepthBuffer_init(&pWnd->depthBuffer, renderer->pDevice, pWnd);
  }

  if (pWnd->rtv == nullptr) {
    ID3D11Texture2D *pBackBuffer;
    pWnd->pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
    D3D11_RENDER_TARGET_VIEW_DESC rtvDesc = {};
    rtvDesc.Texture2D.MipSlice = 0;
    rtvDesc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;

    rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    renderer->pDevice->CreateRenderTargetView(pBackBuffer, &rtvDesc,
                                              &pWnd->rtv);
    rtvDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
    renderer->pDevice->CreateRenderTargetView(pBackBuffer, &rtvDesc,
                                              &pWnd->rtvSrgb);
    pWnd->tex = pBackBuffer;
  }

  LARGE_INTEGER timeNow, freq;
  QueryPerformanceCounter(&timeNow);
  u64 delta = timeNow.QuadPart - renderer->timePrev.QuadPart;
  renderer->timePrev = timeNow;

  QueryPerformanceFrequency(&freq);
  *deltaTime = (f64)delta / (f64)freq.QuadPart;

  return true;
}

b32 GPU_beginFrame(GPU_Device renderer, GPU_Surface surf, f32 *deltaTime) {
  switch (surf->kind) {
    case GSK_NativeWindow:
      return GPU_beginFrame(renderer, surf, &surf->nativeWindow, deltaTime);
  }

  return false;
}

b32 GPU_present(GPU_Device renderer,
                GPU_Surface surface,
                GPU_NativeWindowSurface *pWnd,
                u32 interval) {
  renderer->pCtx->DiscardView(pWnd->depthBuffer.view);

  HRESULT hr = pWnd->pSwapChain->Present(interval, 0);
  surface->isOccluded = (hr == DXGI_STATUS_OCCLUDED);
  return true;
}

b32 GPU_present(GPU_Device renderer, GPU_Surface surface, u32 interval) {
  switch (surface->kind) {
    case GSK_NativeWindow:
      return GPU_present(renderer, surface, &surface->nativeWindow, interval);
      break;
  }

  return false;
}

b32 GPU_present(GPU_Device renderer, GPU_Surface surface) {
  return GPU_present(renderer, surface, 1);
}

b32 Surface_wasClosed(GPU_Surface surface) {
  if (surface->kind != GSK_NativeWindow) {
    return false;
  }

  return surface->nativeWindow.wasClosed;
}

static v3 v3_from(v4 v) {
  return {v.x, v.y, v.z};
}

b32 GPU_submit(GPU_Device renderer,
               GPU_Surface surface,
               Slice<GPU_RenderCmd> commands) {
  ArenaTemp temp = getScratch(nullptr, 0);

  D3D11_VIEWPORT viewports[2];
  ID3D11RenderTargetView *renderTarget = nullptr;
  ID3D11DepthStencilView *depthBuffer = nullptr;
  u32 numViews = 0;

  const f32 clearcolor[4] = {1, 1, 1, 1};

  viewports[0] = {0.0f, 0.0f, (float)surface->width, (float)surface->height,
                  0.0f, 1.0f};

  switch (surface->kind) {
    case GSK_NativeWindow: {
      renderTarget = surface->nativeWindow.rtvSrgb;
      depthBuffer = surface->nativeWindow.depthBuffer.view;
      numViews = 1;
      break;
    }
  }

  ID3D11DeviceContext1 *ctx = renderer->pCtx;
  ID3D11Device1 *device = renderer->pDevice;

  ctx->ClearRenderTargetView(renderTarget, clearcolor);
  ctx->ClearDepthStencilView(depthBuffer, D3D11_CLEAR_DEPTH, 1.0f, 0);

  ctx->OMSetRenderTargets(1, &renderTarget, depthBuffer);
  ctx->OMSetBlendState(renderer->blendState, nullptr, 0xffffffff);
  ctx->RSSetViewports(numViews, viewports);

  GPU_Mesh mesh = nullptr;
  ID3D11ShaderResourceView *shaderResources[8];
  b32 shaderResourcesDirty = false;
  memset(shaderResources, 0, sizeof(shaderResources));

  VertexShader_bind(&renderer->vertexShader, ctx);
  SurfaceShader_bind(&renderer->surfaceShader, ctx);
  ctx->PSSetSamplers(0, 1, &renderer->samplerBilinear);

  for (u32 idxCmd = 0; idxCmd < commands.length; idxCmd++) {
    auto &cmd = commands[idxCmd];

    switch (cmd.kind) {
      case GPU_CmdKind::BindImage: {
        u32 idxRes = 0;
        if (shaderResources[idxRes] != cmd.bindImage.image->view) {
          if (cmd.bindImage.colorSpace == GCS_Srgb) {
            shaderResources[idxRes] = cmd.bindImage.image->viewSrgb;
          } else {
            shaderResources[idxRes] = cmd.bindImage.image->view;
          }
          shaderResourcesDirty = true;
        }
        break;
      }
      case GPU_CmdKind::BindMesh: {
        if (mesh != cmd.bindMesh.mesh) {
          mesh = cmd.bindMesh.mesh;
          ID3D11InputLayout *inputLayout = renderer->vertexShader.inputLayout;

          ctx->IASetPrimitiveTopology(mesh->topology);
          ctx->IASetInputLayout(inputLayout);
          ctx->IASetVertexBuffers(0, 1, &mesh->vertexBuffer, &mesh->stride,
                                  &mesh->offset);
          ctx->IASetIndexBuffer(mesh->indexBuffer, mesh->indexFormat, 0);
        }
        break;
      }
      case GPU_CmdKind::SetView: {
        ViewConstants viewConstantsData;
        viewConstantsData.projection = cmd.setView.projection;

        D3D11_BUFFER_DESC constantbufferdesc = {};
        constantbufferdesc.ByteWidth =
            (sizeof(ViewConstants) + 0xf) & 0xfffffff0;
        constantbufferdesc.Usage = D3D11_USAGE_IMMUTABLE;
        constantbufferdesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;

        D3D11_SUBRESOURCE_DATA sub = {&viewConstantsData};
        ID3D11Buffer *viewConstants;
        device->CreateBuffer(&constantbufferdesc, &sub, &viewConstants);

        ctx->VSSetConstantBuffers(0, 1, &viewConstants);
        viewConstants->Release();
        break;
      }
      case GPU_CmdKind::SetSurfaceConstants: {
        D3D11_BUFFER_DESC desc = {};
        desc.ByteWidth =
            (cmd.setSurfaceConstants.buffer.length + 0xf) & 0xfffffff0;
        desc.Usage = D3D11_USAGE_IMMUTABLE;
        desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;

        D3D11_SUBRESOURCE_DATA sub = {cmd.setSurfaceConstants.buffer.data};
        ID3D11Buffer *buf;
        device->CreateBuffer(&desc, &sub, &buf);

        ctx->PSSetConstantBuffers(1, 1, &buf);
        buf->Release();
        break;
      }
      case GPU_CmdKind::RenderInstance: {
        if (mesh) {
          if (shaderResourcesDirty) {
            shaderResourcesDirty = false;
            ctx->PSSetShaderResources(0, 8, shaderResources);
          }

          ctx->DrawIndexedInstanced(mesh->numIndices, 1, 0, 0, 0);
        }
        break;
      }
    }
  }

  releaseScratch(temp);
  return true;
}

b32 Surface_getSize(GPU_Surface surface, i32 *w, i32 *h) {
  *w = surface->width;
  *h = surface->height;
  return true;
}

#pragma comment(lib, "dxguid.lib")

b32 GPU_destroyImage(GPU_Device renderer, GPU_Image image) {
  CHECK(image->texture && image->view);
  if (image->texture == nullptr || image->view == nullptr) {
    return false;
  }

  image->view->Release();
  image->view = nullptr;
  image->viewSrgb->Release();
  image->viewSrgb = nullptr;
  image->texture->Release();
  image->texture = nullptr;
  return true;
}

b32 GPU_createImage(GPU_Device renderer,
                    Arena *arena,
                    const GPU_ImageDesc *image,
                    GPU_Image *out) {
  HRESULT res;
  DXGI_FORMAT imageFormat, linearFormat, srgbFormat;
  u32 pitch;

  switch (image->format) {
    case GPU_PixelFormat::R8G8B8A8:
      imageFormat = DXGI_FORMAT_R8G8B8A8_TYPELESS;
      linearFormat = DXGI_FORMAT_R8G8B8A8_UNORM;
      srgbFormat = DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
      pitch = 4 * image->width;
      break;
    case GPU_PixelFormat::R8:
      imageFormat = DXGI_FORMAT_R8_TYPELESS;
      linearFormat = DXGI_FORMAT_R8_UNORM;
      srgbFormat = DXGI_FORMAT_R8_UNORM;
      pitch = 1 * image->width;
      break;
    default:
      TODO();
      return false;
  }

  ArenaTemp temp = getScratch(&arena, 1);

  ID3D11Texture2D *texture = nullptr;
  D3D11_TEXTURE2D_DESC textureDesc = {};
  textureDesc.Width = image->width;
  textureDesc.Height = image->height;
  textureDesc.MipLevels = 1;
  textureDesc.ArraySize = 1;
  textureDesc.Format = imageFormat;
  textureDesc.SampleDesc.Count = 1;
  textureDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  textureDesc.Usage = D3D11_USAGE_IMMUTABLE;

  D3D11_SUBRESOURCE_DATA subresource = {};
  subresource.pSysMem = image->pixels.data;
  subresource.SysMemPitch = pitch;
  subresource.SysMemSlicePitch = 0;

  res =
      renderer->pDevice->CreateTexture2D(&textureDesc, &subresource, &texture);
  if (!SUCCEEDED(res)) {
    return false;
  }

  ID3D11ShaderResourceView *view, *viewSrgb;

  D3D11_SHADER_RESOURCE_VIEW_DESC viewDesc = {};
  viewDesc.Format = linearFormat;
  viewDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  viewDesc.Texture2D.MipLevels = -1;
  viewDesc.Texture2D.MostDetailedMip = 0;
  res = renderer->pDevice->CreateShaderResourceView(texture, &viewDesc, &view);
  if (!SUCCEEDED(res)) {
    return false;
  }

  D3D11_SHADER_RESOURCE_VIEW_DESC descSrgb = {};
  descSrgb.Format = srgbFormat;
  descSrgb.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  descSrgb.Texture2D.MipLevels = -1;
  descSrgb.Texture2D.MostDetailedMip = 0;
  res = renderer->pDevice->CreateShaderResourceView(texture, &descSrgb,
                                                    &viewSrgb);
  if (!SUCCEEDED(res)) {
    return false;
  }

  GPU_Image i = alloc<GPU_Image_t>(arena);
  i->texture = texture;
  i->view = view;
  i->viewSrgb = viewSrgb;
  *out = i;

  releaseScratch(temp);
  return true;
}

b32 GPU_discardUpdateImage(GPU_Device device,
                           GPU_Image image,
                           u32 idxSubresource,
                           Slice<u8> newContents,
                           u32 numRows,
                           u32 rowPitch) {
  D3D11_MAPPED_SUBRESOURCE mappedSubres;
  HRESULT hr;
  hr = device->pCtx->Map(image->texture, idxSubresource,
                         D3D11_MAP_WRITE_DISCARD, 0, &mappedSubres);
  if (!SUCCEEDED(hr)) {
    return false;
  }

  if (rowPitch == mappedSubres.RowPitch) {
    memcpy(mappedSubres.pData, newContents.data, newContents.length);
  } else {
    u8 *dst = (u8 *)mappedSubres.pData;
    for (u32 row = 0; row < numRows; row++) {
      memcpy(dst, &newContents[row * rowPitch], rowPitch);
      dst += mappedSubres.RowPitch;
    }
  }

  device->pCtx->Unmap(image->texture, idxSubresource);
  return true;
}

void *GPU_getRawHandle(GPU_Image image) {
  return image->viewSrgb;
}

b32 GPU_getRawHandle(GPU_Device device, void **out) {
  if (!device || !out) {
    return false;
  }

  *out = device->pDevice;
  return true;
}
