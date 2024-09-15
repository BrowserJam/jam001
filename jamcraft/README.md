# JamCraft

«categorically insane»  
— lino-levan

---
To quote one of the creators of the jam:
![pic](https://github.com/user-attachments/assets/ddf35b74-7f45-4082-80bd-2d5e9340f884)
> some such graphical context

And a graphical context i found.
Who needs any "windows", "images", or "canvases", we have **_Minecraft_**.

This is a fabric mod that allows you to enter a command `/render <position> <url> <width>`, that will fetch the url (from the main thread btw, sorry), and fill the space (top-left corner being `<position>`) with the blocks corresponding to the rendered HTML. The aspect ratio is hardcoded to be 16/9.

This is my first time creating a minecraft mod and a second time working with Kotlin, so the code might be stupid. (It most definitely is) Also it uses a library for parsing HTML (ik lame) because otherwise I would not have finished this at all.

It is semi-compliant with some web standards, that is to say it doesn't even have list support 😭
But it's able to support like all colors with different blocks, even though that's not used anywhere, and also the text is anti-aliased - with minecraft blocks...

Anyway, here's my abomination, and unfortunately I didn't have time for any interactivity, so it's just static for now.


P.S. Also this thing will create a mess of your logs and will also create a png in the `run/` folder, to which it also renders the HTML, I didn't have time to clean that up, sorry lol

Demo:
![sorry sir, you've got some villages on your website](https://github.com/user-attachments/assets/7234d585-4da1-402b-9bcd-2c1357b8f65b)

## How to run
Good question. I didn't make a .jar file, but you can use **IntelliJ IDEA** with its Minecraft modding extension (will compile the whole Minecraft source, no way around this) to run the debug version (top right button that should say "Minecraft Client")

It is my first time working both with Fabric and IntelliJ, so if you have any questions or there are any problems, you can message me - kaizjen - on discord.