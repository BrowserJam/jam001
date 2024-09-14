/*
 * Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

package main

import (
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"log/slog"
	"strconv"
	"strings"

	"github.com/tdewolff/canvas"

	"github.com/jamiemansfield/toybrowser/css"
	"github.com/jamiemansfield/toybrowser/dom"
)

type ListType uint8

const (
	ListTypeNone ListType = iota
	ListTypeOrdered
	ListTypeUnordered
)

type List struct {
	Ordinal int
}

type RendererContext struct {
	Ctx *canvas.Context

	ForegroundColour color.Color

	FontSize       float64
	FontStyle      canvas.FontStyle
	FontVariant    canvas.FontVariant
	FontDecorators []canvas.FontDecorator

	ListType ListType
	List     *List
}

type Renderer struct {
	FontFamily *canvas.FontFamily
	RichText   *canvas.RichText
}

func NewRenderer(fontFamily *canvas.FontFamily) *Renderer {
	face := fontFamily.Face(12.0, canvas.Black, canvas.FontNormal, canvas.FontRegular)

	return &Renderer{
		FontFamily: fontFamily,
		RichText:   canvas.NewRichText(face),
	}
}

func (r *Renderer) Render(c *canvas.Canvas, doc *dom.Document) {
	ctx := canvas.NewContext(c)

	// White background
	ctx.SetFillColor(canvas.White)
	ctx.DrawPath(0, 0, canvas.Rectangle(c.W, c.H))

	// Render body
	r.renderElement(RendererContext{
		Ctx: ctx,

		ForegroundColour: canvas.Black,

		FontSize:    12.0,
		FontStyle:   canvas.FontRegular,
		FontVariant: canvas.FontNormal,

		ListType: ListTypeNone,
	}, doc.Body)

	// Render rich text
	text := r.RichText.ToText(c.W, c.H, canvas.Left, canvas.Top, 0, 0)
	ctx.DrawText(0, c.H, text)
}

func (r *Renderer) renderElement(ctx RendererContext, element *dom.Element) {
	switch element.Name {
	case "body":
		r.renderInline(ctx, element)
	case "p":
		r.renderParagraph(ctx, element)
	case "h1":
		r.renderHeading(ctx, element, 24.0)
	case "a":
		r.renderHyperlink(ctx, element)
	case "dl":
		r.renderDescriptionList(ctx, element)
	case "dt":
		r.renderDescriptionTerm(ctx, element)
	case "dd":
		r.renderDescriptionDetails(ctx, element)
	case "br":
		r.newline()
	case "strong":
		r.renderStrong(ctx, element)
	case "b":
		r.renderStrong(ctx, element)
	case "ul":
		r.renderList(ctx, element, ListTypeUnordered)
	case "ol":
		r.renderList(ctx, element, ListTypeUnordered)
	case "li":
		r.renderListItem(ctx, element)
	case "font":
		r.renderFont(ctx, element)
	case "title":
		// NOTE: ignored
	case "nextid":
		// NOTE: ignored
	default:
		slog.Warn("Unknown element, treating as inline", "name", element.Name)
		r.renderInline(ctx, element)
	}
}

func (r *Renderer) renderInline(ctx RendererContext, element *dom.Element) {
	// Render children
	for _, child := range element.Children {
		// Elements
		if e, ok := child.(*dom.Element); ok {
			r.renderElement(ctx, e)
		}

		// Text
		if t, ok := child.(*dom.Text); ok {
			text := strings.ReplaceAll(t.Text, "\n", " ")
			r.renderText(ctx, text)
		}
	}
}

func (r *Renderer) renderHyperlink(ctx RendererContext, element *dom.Element) {
	ctx.ForegroundColour = canvas.Blue
	ctx.FontDecorators = append(ctx.FontDecorators, canvas.FontUnderline)
	r.renderInline(ctx, element)
}

func (r *Renderer) renderParagraph(ctx RendererContext, element *dom.Element) {
	r.newline()
	r.newline()
	r.renderInline(ctx, element)
	r.newline()
}

func (r *Renderer) renderHeading(ctx RendererContext, element *dom.Element, fontSize float64) {
	ctx.FontSize = fontSize
	ctx.FontStyle = canvas.FontBold

	r.newline()
	r.renderInline(ctx, element)
	r.newline()
	r.newline()
}

func (r *Renderer) renderDescriptionList(ctx RendererContext, element *dom.Element) {
	r.newline()
	r.newline()
	r.renderInline(ctx, element)
}

func (r *Renderer) renderDescriptionTerm(ctx RendererContext, element *dom.Element) {
	r.renderInline(ctx, element)
	r.newline()
}

func (r *Renderer) renderDescriptionDetails(ctx RendererContext, element *dom.Element) {
	r.indent(ctx)
	r.indent(ctx)
	r.renderInline(ctx, element)
	r.newline()
}

func (r *Renderer) renderList(ctx RendererContext, element *dom.Element, listType ListType) {
	ctx.ListType = listType
	ctx.List = &List{
		Ordinal: 1,
	}
	r.renderInline(ctx, element)
}

func (r *Renderer) renderListItem(ctx RendererContext, element *dom.Element) {
	r.newline()
	r.indent(ctx)

	if ctx.ListType == ListTypeOrdered {
		var ordinal int
		if ctx.List != nil {
			ordinal = ctx.List.Ordinal
			ctx.List.Ordinal++
		}
		r.renderText(ctx, strconv.Itoa(ordinal)+". ")
	} else if ctx.ListType == ListTypeUnordered {
		r.renderText(ctx, "• ")
	}

	r.renderInline(ctx, element)
}

func (r *Renderer) renderFont(ctx RendererContext, element *dom.Element) {
	for key, value := range element.Attributes {
		if key == "color" {
			hex := css.ParseNamedColour(value)
			colour, err := css.ParseHexColour(hex)
			if err != nil {
				slog.Warn("Failed to parse <font> colour, ignoring", "err", err)
			} else {
				ctx.ForegroundColour = colour
			}
		} else {
			slog.Warn("Unknown <font> attribute", "key", key, "value", value)
		}
	}
	r.renderInline(ctx, element)
}

func (r *Renderer) renderStrong(ctx RendererContext, element *dom.Element) {
	ctx.FontStyle = canvas.FontBold
	r.renderInline(ctx, element)
}

func (r *Renderer) indent(ctx RendererContext) {
	// FIXME: This is very much a bodge, improve this.
	ctx.ForegroundColour = canvas.Transparent
	r.renderText(ctx, "XX")
}

func (r *Renderer) newline() {
	r.RichText.WriteString("\n")
}

func (r *Renderer) renderText(ctx RendererContext, text string) {
	args := []any{ctx.ForegroundColour, ctx.FontStyle, ctx.FontVariant}
	for _, decorator := range ctx.FontDecorators {
		args = append(args, decorator)
	}
	face := r.FontFamily.Face(ctx.FontSize, args...)

	r.RichText.WriteFace(face, text)
}
