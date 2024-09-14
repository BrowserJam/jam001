#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <GL/freeglut.h>


// TODO 1-char tag names are broken
// TODO spaces in "Content" are broken
const char* input = "<head></head><body><h1>This is a heading\n</h1></body>";

// Note we want this dash literally so it must be first. Implementation defined.
//                          v
#define Name "%1[:_A-Za-z]%[-:_.A-Za-z0-9]"
#define STag "<" Name " >%n" // Needs to have list of Attributes somehow
#define ETag "</" Name " >%n"
#define EmptyElemTag "<" Name " />%n" // Needs to have list of Attributes somehow

#define Content "%[-:_.A-Za-z0-9 \n\t\r]%n"

// Not allowing dashes in comments, which is technically not compliant but whatever
#define Comment "<!-- %*[:_A-Za-z0-9] -->%n"

// TODO
#define Attribute " " Name " = "

unsigned int modstate;
int cur_key = -1;
int cur_skey = -1;
int win_width, win_height;

void draw_text(int x, int y, const char* str)
{
	glRasterPos2i(x, y);
	while (*str) {
		glutBitmapCharacter(GLUT_BITMAP_HELVETICA_18, *str++);
	}
}

const char* skeyname(int skey)
{
	static const char* fkeys[] = { "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" };

	switch (skey) {
	case GLUT_KEY_LEFT: return "left";
	case GLUT_KEY_UP: return "up";
	case GLUT_KEY_RIGHT: return "right";
	case GLUT_KEY_DOWN: return "down";
	case GLUT_KEY_PAGE_UP: return "page up";
	case GLUT_KEY_PAGE_DOWN: return "page down";
	case GLUT_KEY_HOME: return "home";
	case GLUT_KEY_END: return "end";
	case GLUT_KEY_INSERT: return "insert";
	case GLUT_KEY_NUM_LOCK: return "num lock";
	case GLUT_KEY_BEGIN: return "begin";
	case GLUT_KEY_DELETE: return "delete";
	case GLUT_KEY_SHIFT_L: return "L Shift";
	case GLUT_KEY_SHIFT_R: return "R Shift";
	case GLUT_KEY_CTRL_L: return "L Ctrl";
	case GLUT_KEY_CTRL_R: return "R Ctrl";
	case GLUT_KEY_ALT_L: return "L Alt";
	case GLUT_KEY_ALT_R: return "R Alt";
	case GLUT_KEY_SUPER_L: return "L Super";
	case GLUT_KEY_SUPER_R: return "R Super";
	default:
		if (skey >= GLUT_KEY_F1 && skey <= GLUT_KEY_F12) {
			return fkeys[skey - GLUT_KEY_F1];
		}

		break;
	}
	return "<unknown>";
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

// here temporarily
char buf_content[128] = "";

void parseHTML()
{
	int parsed = 0;
	int indent_level = 0;
	char buf[128];
	char namestack[128] = "\0"; // Guarantee two null characters at the start of the stack
	char* namestack_top = namestack + 2;

	while (input && *input) {
		parsed = 0;
		if (sscanf(input, STag, namestack_top, namestack_top + 1, &parsed) && parsed > 0) {
			// Opening tags - <tag>
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("<%s>\n", namestack_top);
			indent_level++;
			namestack_top += strlen(namestack_top) + 1; // Account for \0
			input += parsed;
		}
		else if (sscanf(input, ETag, buf, buf + 1, &parsed) && parsed > 0) {
			// Closing tags - </tag>
			indent_level--;
			while (*((--namestack_top) - 1)); // Walk back the stack pointer until it points to the first character of the previous tag name
			if (strcmp(namestack_top, buf)) {
				printf("Expected closing tag </%s> but found </%s>", namestack_top, buf);
				return 1;
			}
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("</%s>\n", buf);
		}
		else if (sscanf(input, EmptyElemTag, buf, buf + 1, &parsed) && parsed > 0) {
			// Empty Elem Tags - <tag/>
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("<%s/>\n", buf);
		}
		else if (sscanf(input, Content, buf_content, &parsed) && parsed > 0) {
			// Content?
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("%s\n", buf_content);
		}
		else if (sscanf(input, Comment, &parsed) && parsed > 0) {
			// Comments - <!-- abcd -->
			input += parsed;
		}
		else {
			input++;
		}
	}
}

void display(void)
{
	char str[256];

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
	draw_text(win_width / 3, 2 * win_height / 3, str);

	strcpy(str, "Special key: ");
	if (cur_skey > 0) {
		strcat(str, skeyname(cur_skey));
	}
	draw_text(win_width / 3, win_height / 3, str);

	draw_text(0, win_height - 64, buf_content);

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

	parseHTML();
	glutMainLoop();
	return 0;
}
