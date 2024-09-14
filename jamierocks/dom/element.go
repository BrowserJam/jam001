/*
 * Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

package dom

type Element struct {
	Name       string
	Attributes map[string]string
	Children   []any
}
