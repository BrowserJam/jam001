﻿#define _CRT_SECURE_NO_WARNINGS

// For now we're just going to keep everything in a single TU
#include "cssparser.h"
#include "gluthelpers.h"
#include "htmlparser.h"
#include "jsparser.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <GL/freeglut.h>

// TODO 1-char tag names are broken
// TODO spaces in "Content" are broken
const char* test_html = "<html><head></head><body>"
	"<h1>This is a heading h1!</h1>"
	"<h2>This is a heading h2!</h2>"
	"<h3>This is a heading h3!</h3>"
	"<p>This is a paragraph!</p>"
	"<a href='http://example.com'>This is a link!</a>"
"</body></html>";

unsigned int modstate;
int cur_key = -1;
int cur_skey = -1;
int win_width, win_height;

void draw_line(float width, float x0, float y0, float x1, float y1, rgb* color)
{
	glLineWidth(width);
	//glEnable(GL_LINE_SMOOTH);
	glBegin(GL_LINES);
	glVertex2f(x0, y0);
	glVertex2f(x1, y1);
	glEnd();
}

// Render text with the specified style. Returns the number of lines rendered.
int draw_text(int x, int y, const style* s, const char* str)
{
	int lines = 1;
	int width = 0;
	glColor3f(((float)s->color->r) / 255.f, ((float)s->color->g) / 255.f, ((float)s->color->b) / 255.f);
	glRasterPos2i(x, y);
	y -= s->margin->top;
	if (s->border->top > 0) draw_line(s->border->top, x, y, x + 100, y, s->color);
	y -= s->padding->top;
	while (*str) {
		if (*str == '\n') {
			y -= glutBitmapHeight(s->font);
			glRasterPos2i(x, y);
			str++; lines++;
			continue;
		}
		width += glutBitmapWidth(s->font, *str); // TODO this is broken for multilines.
		glutBitmapCharacter(s->font, *str++);
	}
	y -= s->padding->bottom;
	if (s->border->bottom > 0) draw_line(s->border->bottom, x, y, x + width, y, s->color);
	y -= s->margin->bottom;
	return lines;
}

void reshape(int x, int y)
{
	win_width = x;
	win_height = y;
	glViewport(0, 0, x, y);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, x, 0, y, -1, 1);
}

void keypress(unsigned char key, int x, int y)
{
	if (key == 27) exit(0);

	modstate = glutGetModifiers();
	cur_key = key;
	glutPostRedisplay();
}

void keyrelease(unsigned char key, int x, int y)
{
	cur_key = -1;
	glutPostRedisplay();
}

void skeypress(int key, int x, int y)
{
	cur_skey = key;
	glutPostRedisplay();
}

void skeyrelease(int key, int x, int y)
{
	cur_skey = -1;
	glutPostRedisplay();
}

void display(void)
{
	char str[256];

	glClearColor(((float)bg_color->r) / 255.f, ((float)bg_color->g) / 255.f, ((float)bg_color->b) / 255.f, 0.f);
	glClear(GL_COLOR_BUFFER_BIT);

	strcpy(str, "Key:");
	if (cur_key > 0) {
		if (isprint(cur_key)) {
			sprintf(str + 4, " '%c'", cur_key);
		} else {
			sprintf(str + 4, " 0x%02x", cur_key);
		}

		if (modstate & GLUT_ACTIVE_SHIFT) {
			strcat(str, "  shift");
		} if (modstate & GLUT_ACTIVE_CTRL) {
			strcat(str, "  ctrl");
		} if (modstate & GLUT_ACTIVE_ALT) {
			strcat(str, "  alt");
		} if (modstate & GLUT_ACTIVE_SUPER) {
			strcat(str, "  super");
		}
	}
	draw_text(win_width * (3.f/4.f), 10, &fallback_style, str);

	strcpy(str, "Special key: ");
	if (cur_skey > 0) {
		strcat(str, skeyname(cur_skey));
	}
	draw_text(win_width * (1.f/2.f), 10, &fallback_style, str);
	
	tag* body = get_child_by_name(&root_tag, 2, "html", "body");
	tag* iter = body;

	int caret_x = 0;
	int caret_y = win_height - 24;

	assert(prev_tag(next_tag(iter)) == iter && "Bad tree traversal");

	while (iter)
	{
		if (iter->content) {
			const style* sty = get_default_style_by_name(iter->type);
			int lines = draw_text(caret_x, caret_y, sty, iter->content);
			int top_buffer = sty->padding->top + sty->border->top + sty->padding->top;
			int bottom_buffer = sty->padding->bottom + sty->border->bottom + sty->padding->bottom;
			caret_y -= (top_buffer + lines*glutBitmapHeight(sty->font) + bottom_buffer);
		}
		iter = next_tag(iter);
	}

	glutSwapBuffers();
}

int main(int argc, char** argv)
{
	glutInit(&argc, argv);
	glutInitWindowSize(1600, 900);
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE);
	glutCreateWindow("glutbrowser");

	glutDisplayFunc(display);
	glutReshapeFunc(reshape);
	glutKeyboardFunc(keypress);
	glutKeyboardUpFunc(keyrelease);
	glutSpecialFunc(skeypress);
	glutSpecialUpFunc(skeyrelease);

	parse_html(test_html);
	glutMainLoop();
	return 0;
}
