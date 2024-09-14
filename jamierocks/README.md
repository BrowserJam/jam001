Toy Browser
===

Toy Browser is a 'web browser' developed for the inaugural [Browser Jam], built using Go utilising [canvas]' rich text functionality.

## Building

Toy Browser requires the following software to be installed: Go. A copy of [Noto Serif] is also required at `NotoSerif.ttf`.

```shell
curl -o NotoSerif.ttf https://raw.githubusercontent.com/google/fonts/main/ofl/notoserif/NotoSerif%5Bwdth%2Cwght%5D.ttf
go build .
```

## Running

Toy Browser requires a single argument - the URL to render. The rendered page is available from `output/document.png`.

```shell
./toybrowser http://info.cern.ch/hypertext/WWW/TheProject.html
```

## Licence

Toy Browser is licenced with the [BSD 2-Clause Licence](LICENCE).

[Browser Jam]: https://github.com/BrowserJam/browserjam
[canvas]: https://github.com/tdewolff/canvas
[Noto Serif]: https://fonts.google.com/noto/specimen/Noto+Serif
