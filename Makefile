# Targets
TARGETS:=

# Subdirectories
SUBDIRS = build
SUBDIRS_CLEAN = $(patsubst %,%.clean,$(SUBDIRS))

# Rules
.PHONY: all
all: $(SUBDIRS) $(TARGETS)

test_%:
	cd build && $(MAKE) $@

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	cd $@ && $(MAKE) 

.PHONY: $(SUBDIRS_CLEAN)
$(SUBDIRS_CLEAN):
	cd $(@:.clean=) && $(MAKE) clean

.PHONY: clean
clean: $(SUBDIRS_CLEAN)
	-rm -rf $(TARGETS)

