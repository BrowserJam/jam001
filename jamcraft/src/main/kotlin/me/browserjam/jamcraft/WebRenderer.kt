package me.browserjam.jamcraft

import net.minecraft.world.World
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import java.awt.*
import java.awt.image.BufferedImage
import java.awt.image.DataBufferInt
import java.io.File
import javax.imageio.ImageIO

object WebRendererFlags {
    var displayTextBounds = false

    fun loadFromWorld(world: World) {
        displayTextBounds = world.gameRules.getBoolean(DISPLAY_TEXT_BOUNDS)
    }
}

class WebRenderer(width: Int, height: Int) {
    val buffer = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
    val graphics: Graphics2D = buffer.createGraphics()

    init {
        graphics.color = Color.WHITE
        graphics.fillRect(0, 0, width, height)
    }

    fun render(doc: Document): IntArray {
        val b = doc.body()

        val rootNode = elementToView(buffer, b)

        try {
            rootNode.render()
        } catch (e: Throwable) {
            println("Err: ${e.stackTraceToString()}")
        }

        val buf2 = BufferedImage(buffer.width, buffer.height, BufferedImage.TYPE_INT_RGB)
        buffer.copyData(buf2.raster)
        val fl = File("./render.png")
        ImageIO.write(buf2, "png", fl)

        return (buffer.data.dataBuffer as DataBufferInt).data
    }
}
