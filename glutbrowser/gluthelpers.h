#pragma once

#include <GL/freeglut.h>

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
