
PAGES = index architecture concepts jack dsp examples live_coding about

HTML = $(addsuffix .html, $(PAGES))

all: $(HTML)

%.html: %.txt
	./txt2html $(PAGES) < $? > $@

clean:
	rm *.html

