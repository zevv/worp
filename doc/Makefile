
PAGES 	:= index architecture concepts jack dsp examples live_coding gui libs about

LIBS	:= $(wildcard ../lib/*.lua ../lib/Dsp/*.lua)

HTML 	+= $(addsuffix .html, $(PAGES))
HTML	+= libs.html

all: $(HTML)

%.html: %.txt txt2html
	./txt2html $(PAGES) < $< > $@

libs.txt: ./libdocs $(LIBS)
	./libdocs $(LIBS) > $@

clean:
	rm -f *.html

