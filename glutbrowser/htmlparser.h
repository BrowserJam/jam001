#pragma once

#include <stdarg.h>
#include <stdio.h>

// Note we want this dash literally (not as a range) so it must be first. Implementation defined.
//              v
#define Name "%[-:_.A-Za-z0-9]"
#define AttrValue "%[-:_.;=#A-Za-z0-9/ ]"
#define NameStartChar "%[-._A-Za-z]"
#define TagContents "%[-:_.;=#A-Za-z0-9\'\"/ ]"

#define Attr Name "=\"" AttrValue "\"%n"	// Attrs can use single or double quotes
#define AttrAlt Name "='" AttrValue "'%n"	// We could use a set here instead of two separate production rules, but
												// that would add complexity as we'd have to make sure they match.

#define STag "<" TagContents " >%n"				// Can have attributes
#define ETag "</" Name " >%n"					// Cannot have attributes
#define EmptyElemTag "<" TagContents " />%n"	// Can have attributes

#define Content "%[^<]%n" // For now, match on anything but '<'

// Not allowing dashes in comments, which is technically not compliant but whatever
#define Comment "<!-- %*[:_A-Za-z0-9] -->%n"

// TODO
#define Attribute " " Name " = "

// 16 indent levels max for now
const char* tabs = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

#define PAGE_SIZE 4096

typedef struct tag tag;
typedef struct attribute attribute;

typedef struct attribute
{
	const char* key;
	const char* value;
	attribute* next;
} attribute;

typedef struct tag
{
	const char* type;
	const char* content;
	const char* post_content; // content belonging to the parent after the closing tag
	attribute* first_attribute;
	tag* first_child;
	tag* next_sibling;
	tag* parent;
	int x0;
	int y0;
	int x1;
	int y1;
} tag;

tag root_tag = { .type = "root", .first_child = NULL, .first_attribute = NULL, .next_sibling = NULL, .parent = NULL };

char* arena_start = NULL;
char* arena_head = NULL;

// Append attribute to tag. Return the new number of attributes.
int append_attribute(tag* t, attribute* attr)
{
	int attrs = 1;
	attribute* it = t->first_attribute;
	if (!it) {
		t->first_attribute = attr;
		it = attr;
	}
	while (it->next) it = it->next, attrs++;
	if (t->first_attribute != attr) it->next = attr;
	return attrs;
}

const char* get_attribute_by_name(const tag* t, const char* name)
{
	const attribute* it = t->first_attribute;
	while (it) {
		if (strcmp(it->key, name))
			it = it->next;
		else return it->value;
	} return NULL;
}

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
	while (t) {
		if (strcmp(t->type, name))
			t = t->next_sibling;
		else return t;
	} return NULL;
}

// Get a child of 't' by name, if extant. Optionally, supply a VA_LIST of names as the nested children to traverse.
tag* get_child_by_name(tag* t, int depth, const char* name, ...)
{
	if (depth < 1) return NULL;
	va_list args;
	va_start(args, name);
	const char* next_name = name;
	while (t && t->first_child && depth-- > 1)
	{
		t = get_sibling_by_name(t->first_child, next_name);
		if (!t) return NULL;
		next_name = va_arg(args, const char*);
	}
	va_end(args);
	return t;
}

// Get the next tag by order of iteration:
// 1. If 't' has a child, return a pointer to it
// 2. If 't' has a next sibling, return a pointer to it
// 3. Refer to the parent of 't' and return a pointer to its next sibling. Do this step recursively.
// 4. If we run out of parents to search for siblings of, return NULL
tag* next_tag(tag* t)
{
	if (!t) return NULL;
	if (t->first_child) return t->first_child;
	while (t) {
		if (t->next_sibling) return t->next_sibling;
		t = t->parent;
	}
	return NULL;
}

// Return the previous tag by order of iteration:
// 1. If 't' has a parent and 't' is the first child, return the parent of 't'
// 2. Iterate through the children of 't' parent until the tag whose next sibling is 't'
// 3. Otherwise, return NULL
tag* prev_tag(tag* t)
{
	if (!t) return NULL;
	tag* prev_tag = t->parent;
	while (prev_tag) {
		tag* next = next_tag(prev_tag);
		if (next == t) return prev_tag;
		prev_tag = next;
	}
	return NULL;
}

// Push an return a new attribute onto the arena, along with its key and val strings
attribute* create_attr(const char* k, const char* v)
{
	const char* ak = arena_head;
	strcpy(ak, k);
	arena_head += strlen(ak) + 1; // Account for \0

	const char* av = arena_head;
	strcpy(av, v);
	arena_head += strlen(av) + 1; // Account for \0

	// Make space for a new attr in the mem arena
	attribute* attr = (attribute*)arena_head;
	memset(attr, 0, sizeof(attribute));
	attr->key = ak;
	attr->value = av;
	arena_head += sizeof(attribute);
	return attr;
}

// Returns the number of attributes parsed. -1 if invalid.
// TODO: We may need to support other whitespace here.
int parse_tag_attrs(tag* t, const char* tagContents)
{
	char buf[256]; // We are arbitrarily limiting tag content length to 256 chars
	char keyBuf[128];
	char valBuf[128];
	strcpy(buf, tagContents);

	char* it = buf;
	while (*it && *it != ' ' && *it != '\t') it++;

	// Copy the non-null terminated string in
	size_t chars = it - buf;
	memcpy(arena_head, buf, chars);
	t->type = arena_head;
	arena_head[chars] = '\0';
	arena_head += strlen(arena_head) + 1;

	while (*it++) {
		while (*it == ' ' || *it == '\t') it++;
		int parsed = 0;
		if (sscanf(it, Attr, keyBuf, valBuf, &parsed) && parsed > 0) {
			attribute* a = create_attr(keyBuf, valBuf);
			append_attribute(t, a);
			it += parsed;
		} else if (sscanf(it, AttrAlt, keyBuf, valBuf, &parsed) && parsed > 0) {
			attribute* a = create_attr(keyBuf, valBuf);
			append_attribute(t, a);
			it += parsed;
		}
	}
}

void parse_html(const char* input)
{
	if (!arena_start) {
		arena_start = malloc(PAGE_SIZE * 16); // For now, allocate enough that we just don't run out
		arena_head = arena_start;
	}

	char buf[256];

	int parsed = 0;
	int indent_level = 0;
	tag* active_tag = &root_tag;

	while (input && *input) {
		parsed = 0;
		// Precedence matters a lot here. Because opening tags can contain slashes inside attribute values,
		// we need to check against the closing tag rules first.
		if (sscanf(input, ETag, buf, &parsed) && parsed > 0) {
			// Closing tags - </tag>
			indent_level--;

			if (strcmp(active_tag->type, buf)) {
				indent_level--;
				active_tag = active_tag->parent;
				// We are being generous about closing tag matching here
				//printf("Expected closing tag </%s> but found </%s>", active_tag->type, buf);
				//return;
			}
			active_tag = active_tag->parent;

			printf("%.*s</%s>\n", (indent_level > 16) ? 16 : indent_level, tabs, buf);
		}
		else if (sscanf(input, STag, buf, &parsed) && parsed > 0) {
			// Opening tags - <tag>

			// Make space for a new tag in the mem arena
			tag* current_tag = (tag*)arena_head;
			memset(current_tag, 0, sizeof(tag));
			current_tag->parent = active_tag;
			arena_head += sizeof(tag);

			parse_tag_attrs(current_tag, buf);

			if (active_tag->first_child) get_last_sibling(active_tag->first_child)->next_sibling = current_tag;
			else active_tag->first_child = current_tag;
			active_tag = current_tag;

			// Note that we've already stripped the tags at this point
			printf("%.*s<%s>", (indent_level > 16) ? 16 : indent_level, tabs, current_tag->type);
			attribute* attr = current_tag->first_attribute;
			while (attr) {
				printf(" %s='%s'", attr->key, attr->value);
				attr = attr->next;
			} printf("\n");

			indent_level++;
		}
		else if (sscanf(input, EmptyElemTag, buf, &parsed) && parsed > 0) {
			// Empty Elem Tags - <tag/>
			
			// Make space for a new tag in the mem arena
			tag* current_tag = (tag*)arena_head;
			memset(current_tag, 0, sizeof(tag));
			current_tag->parent = active_tag;
			arena_head += sizeof(tag);

			parse_tag_attrs(current_tag, buf);

			if (active_tag->first_child) get_last_sibling(active_tag->first_child)->next_sibling = current_tag;
			else active_tag->first_child = current_tag;

			// Note that we've already stripped the tags at this point
			printf("%.*s<%s/>", (indent_level > 16) ? 16 : indent_level, tabs, current_tag->type);
			attribute* attr = current_tag->first_attribute;
			while (attr) {
				printf(" %s='%s'", attr->key, attr->value);
				attr = attr->next;
			} printf("\n");
		}
		else if (sscanf(input, Content, arena_head, &parsed) && parsed > 0) {
			// Content?
			const char* content = arena_head;
			arena_head += (strlen(arena_head) + 1); // Account for \0
			if (active_tag->first_child) get_last_sibling(active_tag->first_child)->post_content = content;
			else active_tag->content = content;
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
