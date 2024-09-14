#pragma once

//#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>

// Note we want this dash literally so it must be first. Implementation defined.
//              v
#define Name "%[-:_.A-Za-z0-9]"
#define STag "<" Name " >%n" // Needs to have list of Attributes somehow
#define ETag "</" Name " >%n"
#define EmptyElemTag "<" Name " />%n" // Needs to have list of Attributes somehow

#define Content "%[-:_.A-Za-z0-9 \n\t\r]%n"

// Not allowing dashes in comments, which is technically not compliant but whatever
#define Comment "<!-- %*[:_A-Za-z0-9] -->%n"

// TODO
#define Attribute " " Name " = "

// 16 indent levels max for now
const char* tabs = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

#define PAGE_SIZE 4096

typedef struct tag tag;

typedef struct attribute
{
	const char* key;
	//uint8_t key_length; // We are using null terminated strings in the arena instead
	const char* value;
	//uint8_t value_length;
} attribute;

typedef struct tag
{
	const char* name;
	const char* content;
	attribute* first_attribute;
	tag* first_child;
	tag* next_sibling;
	tag* parent;
} tag;

tag root_tag = { .name = "root", .first_child = NULL, .first_attribute = NULL, .next_sibling = NULL, .parent = NULL };

char* arena_start = NULL;
char* arena_head = NULL;

// Returns a pointer to the last sibling of a tag, or NULL if it has no siblings
tag* get_last_sibling(tag* t)
{
	while (t && t->next_sibling)
		t = t->next_sibling;
	return t;
}

// Returns any sibling in 't's list of siblings (or 't' itself) whose name matches 'name'. Otherwise NULL.
tag* get_sibling_by_name(tag* t, const char* name)
{
	while (t)
		if (strcmp(t->name, name))
			t = t->next_sibling;
		else return t;
	return NULL;
}

tag* get_child_by_name(tag* t, const char* name, ...)
{
	va_list args;
	va_start(args, name);
	const char* next_name = name;
	while (t && t->first_child && next_name)
	{
		t = get_sibling_by_name(t->first_child, next_name);
		if (!t) return NULL;
		next_name = va_arg(args, const char*);
	}
	va_end(args);
	return t;
}

void parseHTML(const char* input)
{
	if (!arena_start) {
		arena_start = malloc(PAGE_SIZE);
		arena_head = arena_start;
	}

	char buf[256];

	int parsed = 0;
	int indent_level = 0;
	tag* active_tag = &root_tag;

	while (input && *input) {
		parsed = 0;
		if (sscanf(input, STag, arena_head, &parsed) && parsed > 0) {
			// Opening tags - <tag>

			// Move the arena_head to represent the string we just copied in. Then, make space for a new tag.
			const char* name = arena_head;
			arena_head += (strlen(arena_head) + 1); // Account for \0
			tag* current_tag = (tag*)arena_head;
			memset(current_tag, 0, sizeof(tag));
			current_tag->name = name;
			current_tag->parent = active_tag;
			arena_head += sizeof(tag);

			if (active_tag->first_child) get_last_sibling(active_tag->first_child)->next_sibling = current_tag;
			else active_tag->first_child = current_tag;
			active_tag = current_tag;

			printf("%.*s<%s>\n", (indent_level > 16)? 16 : indent_level, tabs, name);

			indent_level++;
		}
		else if (sscanf(input, ETag, buf, &parsed) && parsed > 0) {
			// Closing tags - </tag>
			indent_level--;

			if (strcmp(active_tag->name, buf)) {
				printf("Expected closing tag </%s> but found </%s>", active_tag->name, buf);
				return;
			}
			active_tag = active_tag->parent;

			printf("%.*s</%s>\n", (indent_level > 16) ? 16 : indent_level, tabs, buf);
		}
		else if (sscanf(input, EmptyElemTag, buf, &parsed) && parsed > 0) {
			// Empty Elem Tags - <tag/>
			printf("%.*s<%s/>\n", (indent_level > 16) ? 16 : indent_level, tabs, buf);
		}
		else if (sscanf(input, Content, arena_head, &parsed) && parsed > 0) {
			// Content?
			const char* content = arena_head;
			arena_head += (strlen(arena_head) + 1); // Account for \0
			active_tag->content = content;
			printf("%.*s%s\n", (indent_level > 16) ? 16 : indent_level, tabs, content);
		}
		else if (sscanf(input, Comment, &parsed) && parsed > 0) {
			// Comments - <!-- abcd -->
			printf("%.*sFound comment, skipping...\n", (indent_level > 16) ? 16 : indent_level, tabs);
		}
		else {
			input++;
		}

		input += parsed;
	}

	printf("Done with parsing. Yay!");
}
