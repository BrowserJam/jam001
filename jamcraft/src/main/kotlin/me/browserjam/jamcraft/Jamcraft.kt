package me.browserjam.jamcraft

import com.google.common.collect.ImmutableMap
import com.mojang.brigadier.arguments.IntegerArgumentType
import com.mojang.brigadier.arguments.StringArgumentType
import it.unimi.dsi.fastutil.objects.Reference2ObjectArrayMap
import net.fabricmc.api.ModInitializer
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback
import net.fabricmc.fabric.api.gamerule.v1.GameRuleFactory
import net.fabricmc.fabric.api.gamerule.v1.GameRuleRegistry
import net.minecraft.block.*
import net.minecraft.command.argument.BlockPosArgumentType
import net.minecraft.command.argument.PosArgument
import net.minecraft.server.command.CommandManager
import net.minecraft.text.Text
import net.minecraft.util.math.BlockPos
import net.minecraft.world.GameRules
import net.minecraft.world.GameRules.BooleanRule
import org.jsoup.Jsoup


//val NOT_ENOUGH_ARGS = SimpleCommandExceptionType(Text.literal("Not enough arguments to /render"))

var DISPLAY_TEXT_BOUNDS: GameRules.Key<BooleanRule>? = null

class Jamcraft : ModInitializer {

    override fun onInitialize() {
        DISPLAY_TEXT_BOUNDS = GameRuleRegistry.register("jcDisplayTextBounds", GameRules.Category.MISC, GameRuleFactory.createBooleanRule(false))

        CommandRegistrationCallback.EVENT.register { dispatcher, _, _ ->
            dispatcher.register(
                CommandManager.literal("render")
                    .requires { source -> source.hasPermissionLevel(2) }
                    .then(
                        CommandManager.argument("position", BlockPosArgumentType.blockPos())
                            .then(
                                CommandManager.argument("url", StringArgumentType.string())
                                    .then(
                                        CommandManager.argument("width", IntegerArgumentType.integer())
                                            .executes { context ->
                                                try {

                                                val url = context.getArgument("url", String::class.java)
                                                val width = context.getArgument("width", Int::class.java)
                                                val position = context.getArgument("position", PosArgument::class.java)

                                                val blkpos = position.toAbsoluteBlockPos(context.source)

                                                val height = (width.toDouble() * (9.0/16.0)).toInt()

                                                val leftmost = blkpos.x
                                                val topmost = blkpos.z
                                                val rightmost = leftmost + width
                                                val bottommost = topmost + height

                                                val elevation = blkpos.y


                                                /*for (i in 0..height) {
                                                    context.source.server.commandManager.executeWithPrefix(
                                                        context.source,
                                                        "/fill ${blkpos.x} ${blkpos.y} ${blkpos.z + i} $rightmost ${blkpos.y + 1} ${blkpos.z + i} minecraft:white_concrete"
                                                    )
                                                }*/
                                                val world = context.source.world

                                                WebRendererFlags.loadFromWorld(world)

                                                val renderer = WebRenderer(width, height)
                                                // TODO: move out of main thread
                                                val doc = Jsoup.connect(url).get()
                                                val pixels = renderer.render(doc)

                                                buildPixels(pixels, width, world, leftmost, elevation, topmost)

                                                context.source.sendFeedback(
                                                    { Text.literal("Hello! $url, $width, $position") },
                                                    true
                                                )
                                                0
                                                } catch (e: Throwable) {
                                                    println("ERROR! $e")
                                                    0
                                                }
                                            }
                                    )
                            )
                    )
            )
        }
    }
}
