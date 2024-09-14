/*
 * Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

package css

import (
	"errors"
	"image/color"
	"log/slog"
)

// ParseNamedColour parses CSS colours into their RGB equivalent.
func ParseNamedColour(in string) string {
	// https://drafts.csswg.org/css-color/#named-colors

	if in[0] == '#' {
		return in
	}

	switch in {
	case "black":
		return "#000000"
	case "silver":
		return "#c0c0c0"
	case "gray":
		return "#808080"
	case "white":
		return "#ffffff"
	case "maroon":
		return "#800000"
	case "red":
		return "#ff0000"
	case "purple":
		return "#800080"
	case "fuchsia":
		return "#ff00ff"
	case "green":
		return "#008000"
	case "lime":
		return "#00ff00"
	case "olive":
		return "#808000"
	case "yellow":
		return "#ffff00"
	case "navy":
		return "#000080"
	case "blue":
		return "#0000ff"
	case "teal":
		return "#008080"
	case "aqua":
		return "#00ffff"
	}

	slog.Warn("Unknown named colour, defaulting to #000", "colour", in)
	return "#000"
}

// ParseHexColour parses hexadecimal colour codes into color.Color.
func ParseHexColour(s string) (c color.RGBA, err error) {
	// https://stackoverflow.com/a/54200713
	c.A = 0xff

	if s[0] != '#' {
		return c, errors.New("invalid hex colour")
	}

	hexToByte := func(b byte) byte {
		switch {
		case b >= '0' && b <= '9':
			return b - '0'
		case b >= 'a' && b <= 'f':
			return b - 'a' + 10
		case b >= 'A' && b <= 'F':
			return b - 'A' + 10
		}
		err = errors.New("invalid hex colour")
		return 0
	}

	switch len(s) {
	case 7:
		c.R = hexToByte(s[1])<<4 + hexToByte(s[2])
		c.G = hexToByte(s[3])<<4 + hexToByte(s[4])
		c.B = hexToByte(s[5])<<4 + hexToByte(s[6])
	case 4:
		c.R = hexToByte(s[1]) * 17
		c.G = hexToByte(s[2]) * 17
		c.B = hexToByte(s[3]) * 17
	default:
		err = errors.New("invalid hex colour")
	}
	return
}
