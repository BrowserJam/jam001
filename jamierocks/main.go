/*
 * Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

package main

import (
	"encoding/json"
	"io"
	"log/slog"
	"os"

	"github.com/tdewolff/canvas"
	"github.com/tdewolff/canvas/renderers"

	"github.com/jamiemansfield/toybrowser/dom"
)

func main() {
	if len(os.Args) <= 1 {
		slog.Warn("Usage: toy-browser <url>")
		os.Exit(1)
	}
	slog.Info("Starting Toy Browser", "url", os.Args[1])

	resp, err := Get(os.Args[1])
	if err != nil {
		slog.Warn("Failed to get webpage", "err", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	text, err := io.ReadAll(resp.Body)
	if err != nil {
		slog.Warn("Failed to read response", "err", err)
		os.Exit(1)
	}

	parser := dom.NewParser(string(text))
	doc := parser.Parse()

	// Ensure output directory exists
	err = os.MkdirAll("output", os.ModePerm)
	if err != nil {
		slog.Warn("Failed to create output directory", "err", err)
		os.Exit(1)
	}

	// Dump DOM as JSON file
	out, err := json.MarshalIndent(doc, "", "\t")
	if err != nil {
		slog.Warn("Failed to write DOM as JSON", "err", err)
		os.Exit(1)
	}
	err = os.WriteFile("output/dom.json", out, os.ModePerm)
	if err != nil {
		slog.Warn("Failed to write DOM to file", "err", err)
		os.Exit(1)
	}

	// Render document as PNG file
	notoSerifFont := canvas.NewFontFamily("notoserif")
	if err := notoSerifFont.LoadFontFile("NotoSerif.ttf", canvas.FontRegular); err != nil {
		panic(err)
	}

	c := canvas.New(300, 200)

	renderer := NewRenderer(notoSerifFont)
	renderer.Render(c, doc)

	// Rasterize the canvas and write to a PNG file
	if err := renderers.Write("output/document.png", c, canvas.DPMM(4)); err != nil {
		slog.Warn("Failed to create output image", "err", err)
		os.Exit(1)
	}
}
