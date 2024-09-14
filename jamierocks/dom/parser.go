/*
 * Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

package dom

import (
	"fmt"
	"log/slog"
	"strings"
)

type Parser struct {
	Source string

	Current int
}

func NewParser(source string) *Parser {
	return &Parser{
		Source:  source,
		Current: -1,
	}
}

func (p *Parser) peek(n int) uint8 {
	return p.Source[p.Current+n]
}

func (p *Parser) consume(n int) uint8 {
	p.Current += n
	return p.Source[p.Current]
}

func (p *Parser) Parse() *Document {
	doc := &Document{
		Head: &Element{
			Name:       "head",
			Attributes: make(map[string]string),
			Children:   []any{},
		},
		Body: &Element{
			Name:       "body",
			Attributes: make(map[string]string),
			Children:   []any{},
		},
	}

	for p.Current+1 < len(p.Source) {
		if isWhitespace(p.peek(1)) {
			p.consume(1)
			continue
		}

		switch p.peek(1) {
		case '<':
			if p.peek(2) == '!' {
				p.consume(2)
				for p.peek(1) != '>' {
					p.consume(1)
				}
				p.consume(1)
				continue
			}

			parsedElement := p.parseElement()
			if parsedElement == nil {
				continue
			}

			var mergeElementIntoDocument func(element *Element)
			mergeElementIntoDocument = func(element *Element) {
				if element.Name == "html" {
					for _, child := range element.Children {
						// Elements
						if e, ok := child.(*Element); ok {
							mergeElementIntoDocument(e)
						}

						// Text
						if t, ok := child.(*Text); ok {
							doc.Body.Children = append(doc.Body.Children, t)
						}
					}
				} else if element.Name == "head" {
					// Merge the element into doc.Head
					doc.Head.Children = append(doc.Head.Children, element.Children...)
					for key, value := range element.Attributes {
						doc.Head.Attributes[key] = value
					}
				} else if element.Name == "body" {
					// Merge the element into doc.Body
					doc.Body.Children = append(doc.Body.Children, element.Children...)
					for key, value := range element.Attributes {
						doc.Body.Attributes[key] = value
					}
				} else {
					doc.Body.Children = append(doc.Body.Children, element)
				}
			}
			mergeElementIntoDocument(parsedElement)
		default:
			slog.Warn("Unable to handle next character", "c", string(p.peek(1)))
			p.consume(1)
		}
	}

	return doc
}

func (p *Parser) parseElement() *Element {
	if p.consume(1) != '<' {
		panic(fmt.Errorf("element doesn't start with <"))
	}
	if p.peek(1) == '/' {
		p.consume(1)

		start := p.Current
		for p.peek(1) != '>' {
			p.consume(1)
		}
		name := strings.ToLower(p.Source[start+1 : p.Current+1])
		p.consume(1)

		slog.Info("Ignoring errant end tag", "name", name)
		return nil
	}

	element := &Element{
		Attributes: make(map[string]string),
		Children:   []any{},
	}

	start := p.Current
	for !isWhitespace(p.peek(1)) && p.peek(1) != '>' {
		p.consume(1)
	}
	element.Name = strings.ToLower(p.Source[start+1 : p.Current+1])

	for p.peek(1) != '>' {
		if isWhitespace(p.peek(1)) {
			p.consume(1)
			continue
		}

		// Attributes
		start = p.Current
		for !isWhitespace(p.peek(1)) && p.peek(1) != '=' && p.peek(1) != '>' {
			p.consume(1)
		}
		key := p.Source[start+1 : p.Current+1]

		if p.peek(1) == '=' {
			p.consume(1)

			var value string
			if p.peek(1) == '"' {
				p.consume(1)
				start = p.Current
				for p.peek(1) != '"' {
					p.consume(1)
				}
				value = p.Source[start+1 : p.Current+1]
				p.consume(1)
			} else {
				start = p.Current
				for !isWhitespace(p.peek(1)) && p.peek(1) != '>' {
					p.consume(1)
				}
				value = p.Source[start+1 : p.Current+1]
			}

			element.Attributes[key] = value
		} else {
			element.Attributes[key] = ""
		}
	}
	p.consume(1)

	// Void elements
	// https://html.spec.whatwg.org/#void-elements
	if element.Name == "area" || element.Name == "base" || element.Name == "br" ||
		element.Name == "col" || element.Name == "embed" || element.Name == "hr" ||
		element.Name == "img" || element.Name == "input" || element.Name == "link" ||
		element.Name == "meta" || element.Name == "source" || element.Name == "track" ||
		element.Name == "wbr" ||
		// Legacy elements
		element.Name == "nextid" {
		return element
	}

	for p.Current+1 < len(p.Source) {
		switch p.peek(1) {
		case '<':
			if p.peek(2) == '/' {
				p.consume(2)

				start := p.Current
				for p.peek(1) != '>' {
					p.consume(1)
				}
				name := strings.ToLower(p.Source[start+1 : p.Current+1])
				p.consume(1)

				if name == element.Name {
					return element
				}

				slog.Info("Ignoring errant end tag", "name", name)
				continue
			}

			// Tag omission for dt and dd
			if element.Name == "dt" || element.Name == "dd" {
				next := strings.ToLower(p.Source[p.Current+2 : p.Current+4])
				if next == "dd" || next == "dt" {
					return element
				}
			}

			element.Children = append(element.Children, p.parseElement())
		default:
			start = p.Current
			for p.Current+1 < len(p.Source) && p.peek(1) != '<' {
				p.consume(1)
			}

			element.Children = append(element.Children, &Text{
				Text: replaceCharacterReferences(p.Source[start+1 : p.Current+1]),
			})
		}
	}

	return element
}

func isWhitespace(c uint8) bool {
	return c == ' ' || c == '\n'
}

func replaceCharacterReferences(in string) string {
	var out = in
	out = strings.ReplaceAll(out, "&amp;", "&")
	out = strings.ReplaceAll(out, "&lt;", "<")
	out = strings.ReplaceAll(out, "&gt;", ">")
	out = strings.ReplaceAll(out, "&copy;", "©")
	return out
}
