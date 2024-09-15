package me.browserjam.jamcraft

import net.minecraft.block.Blocks
import net.minecraft.util.math.BlockPos
import net.minecraft.world.World
import java.awt.Color
import kotlin.math.round

// TODO: properly represent colors
// now it misrepresents their saturation
// and only accounts for luminosity;
// the terracotta blocks are also often
// desaturated rather than dark

val monochrome = arrayOf(
    Blocks.BLACK_CONCRETE,
    Blocks.BLACK_WOOL,
    Blocks.GRAY_CONCRETE,
    Blocks.GRAY_WOOL,
    Blocks.LIGHT_GRAY_CONCRETE,
    Blocks.LIGHT_GRAY_WOOL,
    Blocks.WHITE_CONCRETE,
    Blocks.WHITE_CONCRETE,
    Blocks.WHITE_WOOL,
)

val redHue = arrayOf(
    Blocks.NETHER_BRICKS,
    Blocks.RED_NETHER_BRICKS,
    Blocks.NETHER_WART_BLOCK,
    Blocks.RED_CONCRETE,
    Blocks.RED_CONCRETE,
    Blocks.RED_CONCRETE,
    Blocks.RED_WOOL,
)

val orangeHue = arrayOf(
    Blocks.BROWN_TERRACOTTA,
    Blocks.BROWN_CONCRETE,
    Blocks.ORANGE_TERRACOTTA,
    Blocks.SMOOTH_RED_SANDSTONE,
    Blocks.ORANGE_CONCRETE,
    Blocks.ORANGE_CONCRETE,
    Blocks.ORANGE_WOOL,
)

val yellowHue = arrayOf(
    Blocks.YELLOW_TERRACOTTA,
    Blocks.YELLOW_TERRACOTTA,
    Blocks.YELLOW_CONCRETE,
    Blocks.YELLOW_CONCRETE,
    Blocks.YELLOW_WOOL,
    Blocks.YELLOW_WOOL,
    Blocks.GOLD_BLOCK,
)

val limeHue = arrayOf(
    Blocks.GREEN_CONCRETE,
    Blocks.LIME_TERRACOTTA,
    Blocks.LIME_TERRACOTTA,
    Blocks.LIME_CONCRETE,
    Blocks.LIME_CONCRETE,
    Blocks.LIME_WOOL,
)

val greenHue = arrayOf(
    Blocks.GREEN_TERRACOTTA,
    Blocks.GREEN_CONCRETE,
    Blocks.GREEN_CONCRETE,
    Blocks.GREEN_CONCRETE,
    Blocks.LIME_TERRACOTTA,
    Blocks.LIME_CONCRETE,
    Blocks.LIME_WOOL,
)

val cyanHue = arrayOf(
    Blocks.DARK_PRISMARINE,
    Blocks.WARPED_PLANKS,
    Blocks.CYAN_CONCRETE,
    Blocks.CYAN_WOOL,
    Blocks.STRIPPED_WARPED_HYPHAE,
    Blocks.OXIDIZED_COPPER,
    Blocks.PRISMARINE_BRICKS,
    Blocks.DIAMOND_BLOCK
)

val lightblueHue = arrayOf(
    Blocks.BLUE_CONCRETE,
    Blocks.BLUE_WOOL,
    Blocks.LAPIS_BLOCK,
    Blocks.LIGHT_BLUE_CONCRETE,
    Blocks.LIGHT_BLUE_CONCRETE,
    Blocks.LIGHT_BLUE_WOOL,
)

/*val blueHue = arrayOf(
    Blocks.BLUE_CONCRETE,
    Blocks.BLUE_CONCRETE,
    Blocks.BLUE_WOOL,
    Blocks.BLUE_WOOL,
    Blocks.BLUE_WOOL,
    Blocks.LAPIS_BLOCK,
    Blocks.LIGHT_BLUE_TERRACOTTA,
)*/

val purpleHue = arrayOf(
    Blocks.OBSIDIAN,
    Blocks.PURPLE_CONCRETE,
    Blocks.PURPLE_CONCRETE,
    Blocks.PURPLE_CONCRETE,
    Blocks.PURPLE_WOOL,
    Blocks.PURPLE_WOOL,
    Blocks.PURPLE_WOOL,
    Blocks.PURPLE_WOOL,
    Blocks.PURPLE_WOOL,
    Blocks.AMETHYST_BLOCK,
    Blocks.AMETHYST_BLOCK,
    Blocks.AMETHYST_BLOCK,
    Blocks.PURPUR_BLOCK,
    Blocks.PURPUR_BLOCK,
    Blocks.PURPUR_BLOCK,
)

val magentaHue = arrayOf(
    Blocks.CRIMSON_PLANKS,
    Blocks.STRIPPED_CRIMSON_HYPHAE,
    Blocks.MAGENTA_CONCRETE,
    Blocks.MAGENTA_CONCRETE,
    Blocks.MAGENTA_WOOL,
)

val hues = arrayOf(
    redHue, orangeHue, yellowHue, limeHue, cyanHue,
    lightblueHue, lightblueHue, /*blueHue,*/ purpleHue, magentaHue
)
const val BRIGHTNESS_THRESHOLD = 0.12f
const val SATURATION_THRESHOLD = 0.25f

fun buildPixels(pixels: IntArray, width: Int, world: World, leftmost: Int, elevation: Int, topmost: Int) {
    for ((i, pxSigned) in pixels.withIndex()) {
        val x = i % width
        val y = i.floorDiv(width)

        val px = pxSigned + 16777216 // idk whatever
        val color = Color(px)

        val hsb = Color.RGBtoHSB(color.red, color.green, color.blue, null)

        var colors = monochrome

        if (hsb[1] > SATURATION_THRESHOLD && hsb[2] > BRIGHTNESS_THRESHOLD) {
            val colorIndex = round(hsb[0] * hues.size.toFloat() - 1f).toInt()
            colors = hues[colorIndex]
        }

        val luminance = (0.299*color.red + 0.587*color.green + 0.114*color.blue)

        val step = (255).floorDiv(colors.size - 1)
        val index = (luminance / step).toInt()

        world.setBlockState(
            BlockPos(leftmost + x, elevation, topmost + y),
            colors[index].defaultState
        )
    }
}