
PAGES = index architecture concepts jack dsp

HTML = $(addsuffix .html, $(PAGES))

all: $(HTML)

%.html: %.txt
	./txt2html $(PAGES) < $? > $@

clean:
	rm *.html

