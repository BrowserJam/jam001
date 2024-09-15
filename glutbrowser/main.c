#define _CRT_SECURE_NO_WARNINGS

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
int draw_text(int x, int y, int* dxout, int* dyout, const style* s, const char* str)
{
	int lines = 0;
	glColor3f(((float)s->color->r) / 255.f, ((float)s->color->g) / 255.f, ((float)s->color->b) / 255.f);
	glRasterPos2i(x, y);
	if (s->border->top > 0) draw_line(s->border->top, x, y, x + 100, y, s->color);
	while (*str) {
		/*if (*str == '\n') {
			*dyout += glutBitmapHeight(s->font);
			y -= glutBitmapHeight(s->font);
			glRasterPos2i(x, y);
			str++; lines++;
			continue;
		}*/
		*dxout += glutBitmapWidth(s->font, *str); // TODO this is broken for multilines.
		glutBitmapCharacter(s->font, *str++);
	}
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

void mouseinput(int button, int state, int x, int y)
{
	if (button != GLUT_LEFT_BUTTON && state != GLUT_DOWN) return;
	y = win_height - y;
	printf("LMB click at (%i, %i)\n", x, y);

	tag* body = get_child_by_name(&root_tag, 2, "html", "body");
	tag* iter = body;

	while (iter)
	{
		if (x > iter->x0 && y > iter->y0 && iter->x1 > x && iter->y1 > y) {
			printf("Clicked in the BB (%i, %i, %i, %i)\n", iter->x0, iter->y0, iter->x1, iter->y1);
			if (0 == strcmpi(iter->type, "a") && get_attribute_by_name(iter, "href")) {
				printf("Navigating to %s\n", get_attribute_by_name(iter, "href"));
			}
		}
		iter = next_tag(iter);
	}
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
	/*draw_text(win_width * (3.f / 4.f), 10, &fallback_style, str);

	strcpy(str, "Special key: ");
	if (cur_skey > 0) {
		strcat(str, skeyname(cur_skey));
	}
	draw_text(win_width * (1.f/2.f), 10, &fallback_style, str);*/
	
	tag* body = get_child_by_name(&root_tag, 2, "html", "body");
	tag* iter = body;

	int caret_x = 0;
	int caret_y = win_height - 24;

	if (prev_tag(next_tag(iter)) != iter)
		printf("Warning: Drawing an empty/bad tree!");

	while (iter)
	{
		if (0 == strcmpi(iter->type, "title")) {
			glutSetWindowTitle(iter->content);
			iter = next_tag(iter);
			continue;
		}
		
		if (iter->content) {
			const style* sty = get_default_style_by_name(iter->type);
			caret_x += sty->padding->left;
			caret_y -= sty->padding->top;

			int dx = 0, dy = 0;
			int lines = draw_text(caret_x, caret_y, &dx, &dy, sty, iter->content);
			if (sty->skip_lines > 0) {
				lines += 1;
				dy += glutBitmapHeight(sty->font);
			}

			iter->x0 = caret_x; iter->y0 = caret_y; iter->x1 = caret_x + dx; iter->y1 = caret_y + dy + glutBitmapHeight(sty->font);;
			if (sty->border->bottom > 0)	draw_line(sty->border->bottom, iter->x0, iter->y0, iter->x1, iter->y0, sty->color);
			if (sty->border->top > 0)		draw_line(sty->border->top,	   iter->x0, iter->y1, iter->x1, iter->y1, sty->color);
			if (sty->border->left > 0)		draw_line(sty->border->left,   iter->x0, iter->y0, iter->x0, iter->y1, sty->color);
			if (sty->border->right > 0)		draw_line(sty->border->right,  iter->x1, iter->y0, iter->x1, iter->y1, sty->color);

			caret_x += dx + sty->padding->right;
			caret_y -= dy + sty->padding->bottom;
			if (lines != 0) caret_x = 0;
		}

		if (iter->post_content) {
			const style* sty = get_default_style_by_name(iter->parent->type);
			int dx = 0, dy = 0;
			int lines = draw_text(caret_x, caret_y, &dx, &dy, sty, iter->post_content);
			if (sty->border->bottom > 0)
				draw_line(sty->border->bottom, caret_x, caret_y, caret_x + dx, caret_y, sty->color);
			caret_x += dx;
			caret_y -= dy;
			if (lines != 0) caret_x = 0;
		}

		iter = next_tag(iter);
	}

	glutSwapBuffers();
}

char filebuffer[PAGE_SIZE * 16];

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
	glutMouseFunc(mouseinput);

	FILE* fin;
	if (argv[1]) {
		fin = fopen(argv[1], "r");
		size_t charsread = fread(filebuffer, 1, PAGE_SIZE * 16, fin);
		filebuffer[charsread] = '\0';
		parse_html(filebuffer);
		fclose(fin);
	}

	glutMainLoop();
	return 0;
}
