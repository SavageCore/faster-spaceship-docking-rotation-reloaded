# Faster Spaceship Docking Rotation Reloaded
# Builds the FOMOD installer (Instant + 10x + 5x + 2x) with the AMUMSS Linux port.
#
# Usage:
#   make release      clean rebuild + verify + pack dist/ zip (default)
#   make verify       sanity-check the built outputs
#   make clean        remove build/ and dist/
#
# Override the AMUMSS install location if needed:
#   make AMUMSS_HOME=/path/to/AMUMSS release
#
# Game-update playbook (see README.md):
#   1. fetch latest MBINCompiler into AMUMSS_HOME
#   2. bump NMS_VERSION in src/*.lua to the new game version
#   3. make release VERSION=x.y.z   (bump the mod version too)
#   4. import + deploy + test in game

AMUMSS_HOME ?= $(HOME)/AMUMSS
AMUMSS_LINUX ?= $(HOME)/Git/AMUMSS/linux

VERSION      := 0.1.0

MOD_SET      := Faster Spaceship Docking Rotation Reloaded

SRC_TEMPLATE := src/docking.lua.in

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

# Installer variants, fastest first. Each variant label names the rendered
# script, the CreatedMODS folder, the fomod source folder and the in-game
# MOD_FILENAME suffix, so it must match ModuleConfig.xml exactly.
VARIANT   := Instant 10x 5x 2x
RENDERED  := $(addprefix $(BUILD)/,$(addsuffix .lua,$(VARIANT)))

# DockingRotateSpeed to write (game default is 1) and the description shown
# in the mod list. Both are keyed by variant label.
SPEED_Instant := 100
SPEED_10x     := 10
SPEED_5x      := 5
SPEED_2x      := 2

DESC_Instant  := instant docking rotation
DESC_10x      := 10x faster docking rotation
DESC_5x       := 5x faster docking rotation
DESC_2x       := 2x faster docking rotation

SPEEDS := $(foreach v,$(VARIANT),$(v)=$(SPEED_$(v)))

.PHONY: all release fomod build verify assets clean

all: release

release: clean build
	@rm -rf "$(BUILD)/fomodz" && mkdir -p "$(BUILD)/fomodz/fomod" $(addprefix "$(BUILD)/fomodz/",$(VARIANT))
	@set -e; for v in $(VARIANT); do cp -a "$(BUILD)/$(MOD_SET) - $$v/GLOBALS" "$(BUILD)/fomodz/$$v/"; done
	@cp ModuleConfig.xml "$(BUILD)/fomodz/fomod/"
	@mkdir -p "$(DIST)" && rm -f "$(FOMOD_ZIP)" && cd "$(BUILD)/fomodz" && zip -qr "$(shell pwd)/$(FOMOD_ZIP)" fomod $(VARIANT)
	@echo "packed: $(FOMOD_ZIP)"
	@python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$(BUILD)/fomodz/fomod/ModuleConfig.xml'); print('ModuleConfig.xml: well-formed XML')"

# Render the variant scripts from the single template. One pattern rule for
# every variant: the file stem is the variant label, so $* drives the
# substitutions. The guard turns a typo in VARIANT into a loud failure rather
# than a script with a blank speed.
$(BUILD)/%.lua: $(SRC_TEMPLATE)
	@mkdir -p "$(BUILD)"
	@test -n "$(SPEED_$*)" || { echo "ERROR: unknown variant '$*' - add SPEED_$* and DESC_$* to the Makefile" >&2; exit 1; }
	@sed -e "s/@VARIANT_LABEL@/$*/" -e "s/@SPEED@/$(SPEED_$*)/" -e "s/@DESC@/$(DESC_$*)/" "$(SRC_TEMPLATE)" > "$@"

# One pipeline run builds every variant as an individual mod.
build: $(RENDERED)
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME) (set AMUMSS_HOME=...)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: run $(AMUMSS_LINUX)/scripts/fetch_mbincompiler.sh with AMUMSS_HOME=$(AMUMSS_HOME) first" >&2; exit 1)
	@mkdir -p "$(BUILD)"
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp $(RENDERED) "$(AMUMSS_HOME)/ModScript/"; \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@set -e; for v in $(VARIANT); do \
		rm -rf "$(BUILD)/$(MOD_SET) - $$v"; \
		mkdir -p "$(BUILD)/$(MOD_SET) - $$v"; \
		cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET) - $$v/GLOBALS" "$(BUILD)/$(MOD_SET) - $$v/"; \
	done
	@touch "$(STAMP)"
	@echo "built: $(foreach v,$(VARIANT),$(BUILD)/$(MOD_SET) - $(v) )"

# Single zip with a FOMOD installer menu (choose a speed).
# fomod/ lives at the zip root (that is how managers detect installers).
# Version travels in the zip filename (Nexus convention).
FOMOD_ZIP := $(DIST)/$(MOD_SET) $(VERSION).zip

# Path to a variant's generated EXML.
exml = $(BUILD)/$(MOD_SET) - $(1)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML

# One check chain per variant, expanded at make time so each speed is baked in.
define VERIFY_VARIANT
test -f "$(call exml,$(1))" || { echo "MISSING $(1) EXML" >&2; exit 1; }; \
grep -qE 'DockingRotateSpeed" value="$(SPEED_$(1))(\.[0-9]+)?"' "$(call exml,$(1))" || { echo "BAD $(1) value (want $(SPEED_$(1)))" >&2; exit 1; }; \
if grep -q '!#' "$(call exml,$(1))"; then echo "marker tags present in $(1)" >&2; exit 1; fi
endef

verify: build
	@set -e; $(foreach v,$(VARIANT),$(call VERIFY_VARIANT,$(v));)
	@echo "verify: OK ($(SPEEDS), no marker tags)"

# Nexus page images from assets/src (Pillow required). Outputs are
# generated artifacts (gitignored) - reproducible via this target.
assets: assets/src/docking-procedure.jpg assets/generate.py
	python3 assets/generate.py

clean:
	rm -rf "$(BUILD)" "$(DIST)"
