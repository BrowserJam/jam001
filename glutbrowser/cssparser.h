#pragma once

#include <stdint.h>

// All styling is assumed in px for now
typedef struct box {
	int top, right, bottom, left;
} box;

typedef struct rgb {
	uint8_t r;
	uint8_t g;
	uint8_t b;
} rgb;

typedef struct style {
	const char* name;
	void* font;
	rgb* color;
	box* margin;
	box* border;
	box* padding;
	int skip_lines;
} style;

void parseCSS(const char* input, const char* output)
{

}
