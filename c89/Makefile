all: render.png

browser: browser.c
	$(CC) -o $@ browser.c -std=c89

index.html:
	curl -o $@ https://info.cern.ch/hypertext/WWW/TheProject.html

render.pbm: browser | index.html
	./browser < index.html

render.png: render.pbm
	convert $< $@

clean:
	rm -f browser render.pbm render.png
