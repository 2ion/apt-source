PANDOC = /usr/bin/pandoc
TEMPLATEDIR=/usr/share/pandoc/data/templates/default
TEMPLATE_MAN=$(TEMPLATEDIR).man
TEMPLATE_HTML=$(TEMPLATEDIR).html
PANDOC_FLAGS_HTML = -t html --template $(TEMPLATE_HTML)
PANDOC_FLAGS_MAN  = -t man  --template $(TEMPLATE_MAN)

SOURCE_MKD = $(wildcard *.mkd)
TARGET_MAN = $(patsubst %.mkd,%.3,$(SOURCE_MKD))
TARGET_HTML= $(patsubst %.mkd,%.html,$(SOURCE_MKD))

.PHONY: all

all: $(TARGET_MAN)

$(TARGET_MAN): $(SOURCE_MKD)
	@echo PANDOC $< -o $@
	@$(PANDOC) $(PANDOC_FLAGS_MAN) -o $@ $<

$(TARGET_HTML): $(SOURCE_MKD)
	@echo PANDOC $< -o $@
	@$(PANDOC) $(PANDOC_FLAGS_HTML) -o $@ $<
