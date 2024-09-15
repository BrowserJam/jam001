package me.browserjam.jamcraft

import net.minecraft.predicate.entity.DistancePredicate.y
import java.awt.FontMetrics


/**
 * Globally available utility classes, mostly for string manipulation.
 *
 * @author Jim Menard, <a href="mailto:jimm@io.com">jimm@io.com</a>
 * copied from https://stackoverflow.com/questions/12129633/how-do-i-render-wrapped-text-on-an-image-in-java
 *
 * TODO: use the Unicode UAX 14 algo (no time lol)
 */


fun wrap(str: String, fm: FontMetrics, maxWidth: Int, initalMaxWidth: Int = maxWidth): List<String> {
    if (str.trim() == "") return listOf()

    val lines = splitIntoLines(str)
    if (lines.isEmpty()) return lines

    val strings = ArrayList<String>()
    val iter = lines.iterator()
    while (iter.hasNext()) {
        wrapLineInto(iter.next(), strings, fm, maxWidth, initalMaxWidth)
    }
    return strings
}

/**
 * Given a line of text and font metrics information, wrap the line and add
 * the new line(s) to <var>list</var>.
 *
 * @param tempLine
 * a line of text
 * @param list
 * an output list of strings
 * @param fm
 * font metrics
 * @param maxWidth
 * maximum width of the line(s)
 */
fun wrapLineInto(tempLine: String, list: MutableList<String>, fm: FontMetrics, maxWidth: Int, initalMaxWidth: Int = maxWidth) {
    if (maxWidth == 0) return

    var line = tempLine
    var len = line.length
    var width: Int = 0
    var currentMaxWidth = initalMaxWidth

    while (len > 0 && (fm.stringWidth(line).also { width = it }) > currentMaxWidth) {
        // Guess where to split the line. Look for the next space before
        // or after the guess.
        val guess = len * currentMaxWidth / width
        var before = line.substring(0, guess)/*.trim { it.isWhitespace() || it < ' ' }*/

        width = fm.stringWidth(before)
        var pos = findBreakBefore(line, guess)
        if (pos == -1) { // Too short or possibly just right
            pos = findBreakAfter(line, guess)
            println("found bre after $pos, $guess")
            if (pos != -1) { // Make sure this doesn't make us too long
                before = line.substring(0, pos)/*.trim { it.isWhitespace() || it < ' ' }*/
                if (fm.stringWidth(before) > currentMaxWidth) pos = findBreakBefore(line, guess)
            }
        }
        if (pos == -1) {
            pos = if (width > currentMaxWidth)
                guess // Split in the middle of the word
            else
                guess
        }
        println("Spliutting word ($line) in position $pos, w=$width, max=$currentMaxWidth,")


        list.add(line.substring(0, pos)/*.trim { it.isWhitespace() || it < ' ' }*/)
        line = line.substring(pos)/*.trim { it.isWhitespace() || it < ' ' }*/
        len = line.length
        currentMaxWidth = maxWidth // Once we added a line, it has now reset our "carriage"
    }
    if (len > 0) list.add(line)
    return
}

/**
 * Returns the index of the first whitespace character or '-' in <var>line</var>
 * that is at or before <var>start</var>. Returns -1 if no such character is
 * found.
 *
 * @param line
 * a string
 * @param start
 * where to star looking
 */
fun findBreakBefore(line: String, start: Int): Int {
    for (i in start downTo 0) {
        val c = line[i]
        if (Character.isWhitespace(c) || c == '-') return i
    }
    return -1
}

/**
 * Returns the index of the first whitespace character or '-' in <var>line</var>
 * that is at or after <var>start</var>. Returns -1 if no such character is
 * found.
 *
 * @param line
 * a string
 * @param start
 * where to star looking
 */
fun findBreakAfter(line: String, start: Int): Int {
    val len = line.length
    for (i in start until len) {
        val c = line[i]
        if (Character.isWhitespace(c) || c == '-') return i
    }
    return -1
}

/**
 * Returns an array of strings, one for each line in the string. Lines end
 * with any of cr, lf, or cr lf. A line ending at the end of the string will
 * not output a further, empty string.
 *
 *
 * This code assumes <var>str</var> is not `null`.
 *
 * @param str
 * the string to split
 * @return a non-empty list of strings
 */
fun splitIntoLines(str: String): List<String> {
    val strings = ArrayList<String>()

    val len = str.length
    if (len == 0) {
        strings.add("")
        return strings
    }

    var lineStart = 0

    var i = 0
    while (i < len) {
        val c = str[i]
        if (c == '\r') {
            var newlineLength = 1
            if ((i + 1) < len && str[i + 1] == '\n') newlineLength = 2
            strings.add(str.substring(lineStart, i))
            lineStart = i + newlineLength
            if (newlineLength == 2)  // skip \n next time through loop
                ++i
        } else if (c == '\n') {
            strings.add(str.substring(lineStart, i))
            lineStart = i + 1
        }
        ++i
    }
    if (lineStart < len) strings.add(str.substring(lineStart))

    return strings
}