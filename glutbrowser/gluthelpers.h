#pragma once

#include "cssparser.h"

#include <GL/freeglut.h>

const box box_zero = { .top = 0, .right = 0, .bottom = 0, .left = 0 };
const rgb white =	{ .r = 255,	.g = 255,	.b = 255 };
const rgb black =	{ .r = 0,	.g = 0,		.b = 0 };
const rgb red =		{ .r = 255, .g = 0,		.b = 0 };
const rgb green =	{ .r = 0,	.g = 255,	.b = 0 };
const rgb blue =	{ .r = 0,	.g = 0,		.b = 255 };

const rgb* bg_color = &white;

const style fallback_style = { .name = "fallback", GLUT_BITMAP_8_BY_13, .color = &black, .margin = &box_zero, .border = &box_zero, .padding = &box_zero };

const style default_styles[] = {
	{.name = "h1", GLUT_BITMAP_TIMES_ROMAN_24, .color = &black, .margin = &box_zero, .border = &box_zero, .padding = &box_zero},
	{.name = "h2", GLUT_BITMAP_HELVETICA_18, .color = &black, .margin = &box_zero, .border = &box_zero, .padding = &box_zero},
	{.name = "h3", GLUT_BITMAP_9_BY_15, .color = &black, .margin = &box_zero, .border = &box_zero, .padding = &box_zero},
	{.name = "a", GLUT_BITMAP_8_BY_13, .color = &black, .margin = &box_zero, .border = &box_zero, .padding = &box_zero}
};

const style* get_default_style_by_name(const char* name) {
	for (int i = 0; i < sizeof(default_styles) / sizeof(style); i++)
		if (0 == strcmpi(name, default_styles[i].name))
			return &(default_styles[i]);
	return &fallback_style;
}

const char* skeyname(int skey)
{
	static const char* fkeys[] = { "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" };

	switch (skey) {
	case GLUT_KEY_LEFT:			return "left";
	case GLUT_KEY_UP:			return "up";
	case GLUT_KEY_RIGHT:		return "right";
	case GLUT_KEY_DOWN:			return "down";
	case GLUT_KEY_PAGE_UP:		return "page up";
	case GLUT_KEY_PAGE_DOWN:	return "page down";
	case GLUT_KEY_HOME:			return "home";
	case GLUT_KEY_END:			return "end";
	case GLUT_KEY_INSERT:		return "insert";
	case GLUT_KEY_NUM_LOCK:		return "num lock";
	case GLUT_KEY_BEGIN:		return "begin";
	case GLUT_KEY_DELETE:		return "delete";
	case GLUT_KEY_SHIFT_L:		return "L Shift";
	case GLUT_KEY_SHIFT_R:		return "R Shift";
	case GLUT_KEY_CTRL_L:		return "L Ctrl";
	case GLUT_KEY_CTRL_R:		return "R Ctrl";
	case GLUT_KEY_ALT_L:		return "L Alt";
	case GLUT_KEY_ALT_R:		return "R Alt";
	case GLUT_KEY_SUPER_L:		return "L Super";
	case GLUT_KEY_SUPER_R:		return "R Super";
	default:
		if (skey >= GLUT_KEY_F1 && skey <= GLUT_KEY_F12) {
			return fkeys[skey - GLUT_KEY_F1];
		}

		break;
	}
	return "<unknown>";
}
