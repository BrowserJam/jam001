package me.browserjam.jamcraft

import net.fabricmc.loader.impl.util.log.Log
import net.fabricmc.loader.impl.util.log.LogCategory
import org.jsoup.nodes.Element
import org.jsoup.nodes.Node
import org.jsoup.nodes.TextNode
import java.awt.Color
import java.awt.Font
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import kotlin.math.max


data class DOMRect(
    var x: Int, var y: Int,
    var width: Int,
    var height: Int
) {
    override fun toString(): String {
        return "{x=$x; y=$y; width=$width; height=$height}"
    }
}

/** TODO: DO NOT RELY ON ANYTHING BESIDES `rects`. Have to re-do the whole "making the biggest rectangle" */
interface Layout {
    var blockX: Int
    var blockY: Int
    var blockWidth: Int
    var blockHeight: Int
    val rects: List<DOMRect>

    companion object {
        fun fromRect(rect: DOMRect): Layout {
            return object : Layout {
                override var blockX = rect.x
                override var blockY = rect.y
                override var blockWidth = rect.width
                override var blockHeight = rect.height
                override val rects = mutableListOf(rect)
            }
        }

        fun fromRects(rects: List<DOMRect>): Layout {
            var minX = Int.MAX_VALUE
            var minY = Int.MAX_VALUE
            var maxWidth = 0
            var maxHeight = 0

            // Some rects don't overlap, and this would misrepresent the height.
            // TODO: rework
            for (r in rects) {
                if (r.x < minX) minX = r.x
                if (r.y < minY) minY = r.y

                if (r.width > maxWidth) maxWidth = r.width
                if (r.height > maxHeight) maxHeight = r.height
            }

            return object : Layout {
                override var blockX = minX
                override var blockY = minY
                override var blockWidth = maxWidth
                override var blockHeight = maxHeight
                override val rects = rects
            }
        }
    }
}

enum class Trim {
    None,
    Beginning,
    End,
}
data class StyleCascade(
    val color: Color,
    val font: Font,
    val textUnderline: Boolean,
    val trim: Trim
) {
    fun clone(newColor: Color? = null, newFont: Font? = null, underline: Boolean? = null, newTrim: Trim? = null): StyleCascade {
        return StyleCascade(newColor ?: color, newFont ?: font, underline ?: textUnderline, newTrim ?: trim)
    }

    companion object {
        val default = StyleCascade(
            Color.BLACK,
            Font(Font.SERIF, Font.PLAIN, 16),
            false,
            Trim.None
        )
    }

}

interface View {
    var buffer: BufferedImage
    var style: StyleCascade?
    fun render(
        x: Int = 0,
        y: Int = 0,
        maxWidth: Int = buffer.width,
        maxHeight: Int = buffer.height,
        initialX: Int = x
    ): Layout
}

class EmptyView(override var buffer: BufferedImage): View {
    override var style: StyleCascade? = null
    override fun render(x: Int, y: Int, maxWidth: Int, maxHeight: Int, initialX: Int): Layout {
        return object : Layout {
            override var blockX = x
            override var blockY = y
            override var blockWidth = 0
            override var blockHeight = 0
            override val rects = listOf(
                DOMRect(
                    x, y, 0, 0
                )
            )
        }
    }
}

class BlockView(override var buffer: BufferedImage, var tagName: String = "?") : View {
    val children = mutableListOf<View>()
    override var style: StyleCascade? = null

    override fun toString(): String {
        return "{ ${children.joinToString("; ")} }"
    }

    var marginLeft = 0
    var marginTop = 0
    var marginRight = 0
    var marginBottom = 0
    override fun render(x: Int, y: Int, maxWidth: Int, maxHeight: Int, initialX: Int): Layout {
        var realX = x + marginLeft
        var realY = y + marginTop
        var realMaxWidth = maxWidth - marginRight
        var realMaxHeight = maxHeight - marginBottom

        var currentX = realX
        var currentY = realY
        var currentMaxHeight = realMaxHeight

        var actualHeight = marginTop + marginBottom

        var contentHeight = 0

        // MARGIN COLLAPSE 😭
        if (children.isEmpty()) actualHeight = max(marginTop, marginBottom)

        println("<$tagName> bounds: ($realX, $realY) : {$realMaxWidth, $realMaxHeight} $this")
        println("buf: ${buffer.width}, ${buffer.height}")

        /** Represents all the "bottoms" (x + height)s of the children, to select the highest one */
        val bottoms = mutableListOf<Int>()

        /** margin collapse */
        var previousMarginBottom = 0

        for ((i, view) in children.withIndex()) {
            if (view.style == null) {
                view.style = this.style

                if (i == 0) {
                    view.style = view.style?.clone(newTrim = Trim.Beginning)
                }
                if (i == children.size - 1) {
                    view.style = view.style?.clone(newTrim = Trim.End)
                }
            }

            if (view is BlockView) {
                currentY = realY + contentHeight
                currentX = realX

                println("<$tagName> / <${view.tagName}>: margin collapse: ${view.marginTop - previousMarginBottom} = ${view.marginTop} - $previousMarginBottom")
                view.marginTop = max(view.marginTop - previousMarginBottom, 0)
                previousMarginBottom = view.marginBottom
            } else {
                previousMarginBottom = 0
            }
            Log.info(LogCategory.LOG, "doing child $i of $tagName")
            val layout = view.render(realX, currentY, realMaxWidth, currentMaxHeight, currentX)
            val lastRect = layout.rects.last()
            bottoms.add((lastRect.y + lastRect.height) - realY)
            contentHeight = bottoms.maxOrNull() ?: 0
            println("<$tagName>: contentHeight=$contentHeight, (${lastRect.y} + ${lastRect.height}) - $realY, $bottoms")
            if (view is BlockView) {
                currentY = realY + contentHeight
                currentX = realX
            } else {
                currentX = lastRect.x + lastRect.width
                currentY = lastRect.y
            }
            currentMaxHeight = realMaxHeight - contentHeight
            actualHeight = marginTop + contentHeight + marginBottom
        }

        return Layout.fromRect(
            DOMRect(
                x, y, maxWidth, actualHeight
            )
        )
    }
}

class TextNodeView(override var buffer: BufferedImage, var content: String) : View {
    override fun toString(): String {
        return "($content)"
    }

    override var style: StyleCascade? = null
    override fun render(x: Int, y: Int, maxWidth: Int, maxHeight: Int, initialX: Int): Layout {
        println("textNode ($content) bounds: ($x, $y), initialX: $initialX : {$maxWidth, $maxHeight} $this")
        val graphics = buffer.createGraphics()

        val style = this.style ?: StyleCascade.default
        graphics.color = style.color
        graphics.font = style.font
        val fm = graphics.fontMetrics

        if (style.trim == Trim.Beginning) {
            content = content.trimStart()
        }
        if (style.trim == Trim.End) {
            content = content.trimEnd()
        }

        val actualLines = wrap(content, fm, maxWidth, initalMaxWidth = max(maxWidth - initialX, 0))

        println("($content) Wrapped: $actualLines")

        graphics.setRenderingHint(
            RenderingHints.KEY_TEXT_ANTIALIASING,
            RenderingHints.VALUE_TEXT_ANTIALIAS_ON
        );

        val height = fm.maxAscent
        var rects: List<DOMRect> = actualLines.mapIndexed { index, oldStr ->
            val str = oldStr.replace("\t", "    ")
            // Uhhhhhh that's a huge ass hack that is super weird

            val width = fm.stringWidth(str)
            if (WebRendererFlags.displayTextBounds) {
                graphics.color = Color.ORANGE
                graphics.drawRect(if (index == 0) initialX else x, y, width, height)
            }
            graphics.color = style.color
            graphics.drawString(str, if (index == 0) initialX else x, (y + height * index) + fm.maxAscent)
            println("Draw string at ${if (index == 0) initialX else x}, ${(y + height * index)}")
            if (style.textUnderline) {
                graphics.fillRect(if (index == 0) initialX else x, (y + height * index) + fm.maxAscent, width, 1)
            }

            DOMRect(if (index == 0) initialX else x, y + height * index, width, height)
        }

        if (rects.isEmpty()) {
            rects = listOf(DOMRect(x, y, 0, 0))
        }
        println("($content) $rects")
        return Layout.fromRects(rects)
    }
}

class InlineView(override var buffer: BufferedImage, var tagName: String = "?") : View {
    override var style: StyleCascade? = null

    val children = mutableListOf<View>()

    override fun toString(): String {
        return "( ${children.joinToString("; ")} )"
    }

    override fun render(x: Int, y: Int, maxWidth: Int, maxHeight: Int, initialX: Int): Layout {
        var currentX = initialX
        var currentY = y
        var currentMaxHeight = maxHeight

        var contentHeight = 0
        var contentWidth = 0

        println("inline <$tagName> bounds: ($x, $y) : {$maxWidth, $maxHeight} $this")
        println("buf: ${buffer.width}, ${buffer.height}")

        /** Represents all the "bottoms" (x + height)s of the children, to select the highest one */
        val bottoms = mutableListOf<Int>()

        /** margin collapse */
        var previousMarginBottom = 0

        val domRects = mutableListOf<DOMRect>()
        for ((i, view) in children.withIndex()) {
            if (view.style == null) {
                view.style = this.style
            }

            if (view is BlockView) {
                currentY = y + contentHeight
                currentX = x

                println("inline <$tagName> / <${view.tagName}>: margin collapse: ${view.marginTop - previousMarginBottom} = ${view.marginTop} - $previousMarginBottom")
                view.marginTop = max(view.marginTop - previousMarginBottom, 0)
                previousMarginBottom = view.marginBottom
            } else {
                previousMarginBottom = 0
            }
            Log.info(LogCategory.LOG, "doing child $i of inline $tagName")
            val layout = view.render(x, currentY, maxWidth, currentMaxHeight, currentX)
            val spaceWidth = buffer.graphics.fontMetrics.stringWidth(" ")
            val lastRect = layout.rects.last()
            bottoms.add((lastRect.y + lastRect.height) - y)
            contentHeight = bottoms.maxOrNull() ?: 0
            if (view is BlockView) {
                currentY = y + contentHeight
                currentX = x + spaceWidth
            } else {
                currentX = lastRect.x + lastRect.width + spaceWidth
                currentY = lastRect.y
            }
            currentMaxHeight = maxHeight - contentHeight
            domRects.addAll(layout.rects)
            println("Adding rectangles to $tagName: ${layout.rects}")
        }

        if (domRects.isEmpty()) {
            domRects.add(DOMRect(x, y, 0, 0))
        }

        println("Final layout of $tagName: ${Layout.fromRects(domRects).blockHeight}")
        return Layout.fromRects(domRects)
    }
}

fun em2px(emUnits: Double, font: Font): Int {
    return (font.size.toDouble() * emUnits).toInt()
}

fun body(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "body")
    view.marginLeft = 8
    view.marginBottom = 8
    view.marginRight = 8
    view.marginTop = 8
    view.children.addAll(children)
    view.style = style

    return view
}

val hMargins = arrayOf(.67, .75, .83, 1.0, 1.5, 1.67)
val hFontSizeMultipliers = arrayOf(2.0, 1.5, 1.17, 1.0, .83, .75)
fun h(
    number: Int,
    buffer: BufferedImage,
    children: MutableList<View>,
    style: StyleCascade = StyleCascade.default
): BlockView {
    val view = BlockView(buffer, "h$number")
    val realFont = Font(
        style.font.fontName,
        style.font.style or Font.BOLD,
        em2px(hFontSizeMultipliers[number], style.font)
    )
    val margin = em2px(hMargins[number], realFont)

    view.marginBottom = margin
    view.marginTop = margin
    view.children.addAll(children)
    view.style = style.clone(newFont = realFont)

    return view
}

fun p(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "p")
    val margin = em2px(1.0, style.font)

    view.marginBottom = margin
    view.marginTop = margin
    view.children.addAll(children)
    view.style = style

    return view
}

fun dl(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "dl")
    val margin = em2px(1.0, style.font)

    view.marginBottom = margin
    view.marginTop = margin
    view.children.addAll(children)
    view.style = style

    return view
}

fun dt(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "dt")

    view.children.addAll(children)
    view.style = style

    return view
}

fun dd(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "dd")
    val margin = em2px(1.0, style.font)

    view.marginLeft = margin
    view.children.addAll(children)
    view.style = style

    return view
}

fun simpleBlock(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "?block?")

    view.children.addAll(children)
    view.style = style

    return view
}

fun blockquote(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "blockquote")

    view.marginTop = em2px(1.0, style.font)
    view.marginBottom = em2px(1.0, style.font)
    view.marginLeft = 40
    view.marginRight = 40
    view.children.addAll(children)
    view.style = style

    return view
}

fun pre(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "pre/xmp")

    view.marginTop = em2px(1.0, style.font)
    view.marginBottom = em2px(1.0, style.font)
    view.children.addAll(children)
    view.style = style.clone(newFont = Font(Font.MONOSPACED, style.font.style, style.font.size))

    return view
}

fun ulOl(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): BlockView {
    val view = BlockView(buffer, "ul/ol")

    view.marginTop = em2px(1.0, style.font)
    view.marginBottom = em2px(1.0, style.font)
    view.marginLeft = 40
    view.children.addAll(children)
    view.style = style

    return view
}

fun empty(buffer: BufferedImage): View {
    return EmptyView(buffer)
}

fun unknownElement(
    buffer: BufferedImage,
    children: MutableList<View>,
    tg: String = "?",
    style: StyleCascade = StyleCascade.default
): InlineView {
    val view = InlineView(buffer, tg)

    view.children.addAll(children)
    view.style = style

    return view
}

fun a(buffer: BufferedImage, children: MutableList<View>, style: StyleCascade = StyleCascade.default): InlineView {
    val view = InlineView(buffer, "a")

    view.children.addAll(children)
    view.style = style.clone(underline = true, newColor = Color.BLUE)

    return view
}

fun nodeToView(buffer: BufferedImage, node: Node, pre: Boolean = false): View {
    if (node is Element) {
        return elementToView(buffer, node)
    }
    if (node is TextNode) {
        println("Creating view from text node ${if (node.text().contains('\n')) "[has \\n] " else ""}(${node.text()})")
        return TextNodeView(buffer, if (pre) node.wholeText else node.text())
    }
    return TextNodeView(buffer, "")
}

fun elementToView(buffer: BufferedImage, node: Element): View {
    // TODO: move this out of here and into the TextNodeView renderer
    val pre = node.tag().name == "pre" || node.tag().name == "xmp"

    println("Creating view for <${node.tag().name}>")
    val children = node.childNodes().map { nodeToView(buffer, it, pre) }.toMutableList()

    if (node.tag().name.startsWith("h") && node.tag().name.length == 2) {
        try {
            val hn = node.tag().name.substring(1, 2).toInt()
            println("Sliced hn to $hn")
            if (hn < 7) {
                return h(hn, buffer, children)
            }
        } catch (_: Throwable) {
        }
    }

    when (node.tag().name) {
        "title" -> return empty(buffer)
        "body" -> return body(buffer, children)
        "p" -> return p(buffer, children)
        "dl" -> return dl(buffer, children)
        "dt" -> return dt(buffer, children)
        "dd" -> return dd(buffer, children)
        "a" -> return a(buffer, children)
        "blockquote" -> return blockquote(buffer, children)
        "article", "aside", "footer", "header", "hgroup", "main", "li",
        "nav", "section", "address", "figcaption", "div", "legend", "fieldset" ->
            return simpleBlock(buffer, children)
        "ul", "ol" -> return ulOl(buffer, children)
        "pre", "xmp", "plaintext", "listing" -> return pre(buffer, children)
    }

    return unknownElement(buffer, children, node.tag().name)
}