#pragma once

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

void parseHTML(const char* input, const char* output)
{
	int parsed = 0;
	int indent_level = 0;
	char buf[128];
	char namestack[128] = "\0"; // Guarantee two null characters at the start of the stack
	char* namestack_top = namestack + 2;

	while (input && *input) {
		parsed = 0;
		if (sscanf(input, STag, namestack_top, &parsed) && parsed > 0) {
			// Opening tags - <tag>
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("<%s>\n", namestack_top);
			indent_level++;
			namestack_top += strlen(namestack_top) + 1; // Account for \0
			input += parsed;
		}
		else if (sscanf(input, ETag, buf, &parsed) && parsed > 0) {
			// Closing tags - </tag>
			indent_level--;
			while (*((--namestack_top) - 1)); // Walk back the stack pointer until it points to the first character of the previous tag name
			if (strcmp(namestack_top, buf)) {
				printf("Expected closing tag </%s> but found </%s>", namestack_top, buf);
				return;
			}
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("</%s>\n", buf);
		}
		else if (sscanf(input, EmptyElemTag, buf, &parsed) && parsed > 0) {
			// Empty Elem Tags - <tag/>
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("<%s/>\n", buf);
		}
		else if (sscanf(input, Content, output, &parsed) && parsed > 0) {
			// Content?
			input += parsed;
			for (int i = 0; i < indent_level; i++) printf("\t");
			printf("%s\n", output);
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
