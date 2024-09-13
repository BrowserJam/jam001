#define W 640
#define H 480
#define MARGIN 5
#define REM 2

#define COMP2(s, p) ((s)[0] == (p)[0] && (s)[1] == (p)[1])

char *html;
int depth;
int tx, ty;
int scale;
int blockdepth;
unsigned color;
unsigned frame[W*H];

void ReturnLine(int n) {
  tx = MARGIN;
  ty += n;
}

void StartBlockElement(int n) {
  ReturnLine(n*scale*7);
  blockdepth = depth;
}

void Reset() {
  if (depth == blockdepth) {
    StartBlockElement(2);
    blockdepth = 0;
  }
  color = 0;
  scale = REM;
}

/* Taken from github.com/zserge/fenster */
int font5x3[] = {0x0000,0x2092,0x002d,0x5f7d,0x279e,0x52a5,0x7ad6,0x0012,0x4494,0x1491,0x017a,0x05d0,0x1400,0x01c0,0x0400,0x12a4,0x2b6a,0x749a,0x752a,0x38a3,0x4f4a,0x38cf,0x3bce,0x12a7,0x3aae,0x49ae,0x0410,0x1410,0x4454,0x0e38,0x1511,0x10e3,0x73ee,0x5f7a,0x3beb,0x624e,0x3b6b,0x73cf,0x13cf,0x6b4e,0x5bed,0x7497,0x2b27,0x5add,0x7249,0x5b7d,0x5b6b,0x3b6e,0x12eb,0x4f6b,0x5aeb,0x388e,0x2497,0x6b6d,0x256d,0x5f6d,0x5aad,0x24ad,0x72a7,0x6496,0x4889,0x3493,0x002a,0xf000,0x0011,0x6b98,0x3b79,0x7270,0x7b74,0x6750,0x95d6,0xb9ee,0x5b59,0x6410,0xb482,0x56e8,0x6492,0x5be8,0x5b58,0x3b70,0x976a,0xcd6a,0x1370,0x38f0,0x64ba,0x3b68,0x2568,0x5f68,0x54a8,0xb9ad,0x73b8,0x64d6,0x2492,0x3593,0x03e0};

void Rect(int x, int y, int w, int h) {
  int xx, yy;
  for (xx = x; xx < x+w; xx++) {
    for (yy = y; yy < y+h; yy++) {
      if (yy*W+xx < sizeof(frame)/sizeof(unsigned))
        frame[yy*W+xx] = color;
    }
  }
}

void DrawText(char *s, int n) {
  int i, chr, bmp, dx, dy;
  for (i = 0; i < n; i++) {
    chr = s[i];
    if (chr > 32) {
      if (tx + 4 * scale >= W)
        ReturnLine(scale*7);
      bmp = font5x3[chr - 32];
      for (dy = 0; dy < 5; dy++) {
        for (dx = 0; dx < 3; dx++) {
          if (bmp >> (dy * 3 + dx) & 1) {
            Rect(tx+dx*scale, ty+dy*scale, scale, scale);
          }
        }
      }
    }
    if (color == 0xff)
      Rect(tx, ty+4*scale+1, 4*scale,scale);
    if (tx > MARGIN || chr > 32)
      tx += 4 * scale;
  }
}

void SkipToEnd() {
  while (*html && *html++ != '>') {}
}

void ParseContent() {
  char *b = html;
  while (*html && *html != '<')
    html++;
  DrawText(b, html-b);
}

void Parse() {
  while (*html) {
    if (*html++ == '<') {
      if (*html == '/') {
        depth--;
        Reset();
      } else {
        if (*html == 'A') {
          color = 0xff;
        } else if (*html == 'P' || COMP2(html, "DL")) {
          StartBlockElement(2);
        } else if (COMP2(html, "DT")) {
          StartBlockElement(1);
        } else if (COMP2(html, "DD")) {
          StartBlockElement(1);
          tx += 4*4*scale;
        } else if (COMP2(html, "TI")) {
          scale = 0;
        } else if (COMP2(html, "H1")) {
          StartBlockElement(1);
          scale = REM * 2;
        }
      }
      SkipToEnd();
      ParseContent();
      depth++;
    }
  }
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void WritePbm() {
  int i;
  FILE *f = fopen("render.pbm", "w");
  fprintf(f, "P3\n%d %d\n255\n", W, H);
  for (i = 0; i < W*H; i++)
    fprintf(f, "%d %d %d\n", (frame[i] >> 16) & 0xff, (frame[i] >> 8) & 0xff, frame[i] & 0xff);
  fclose(f);
}

int main() {
  memset(frame, 0xff, sizeof(frame));
  html = malloc(10000);
  read(0, html, 10000);
  Reset();
  Parse();
  WritePbm();
  return 0;
}
