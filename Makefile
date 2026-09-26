# Faster Spaceship Docking Rotation Reloaded
# Builds the FOMOD installer (Instant + 10x) with the AMUMSS Linux port.
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

MOD_INSTANT  := Faster Spaceship Docking Rotation Reloaded - Instant
MOD_10X      := Faster Spaceship Docking Rotation Reloaded - 10x
MOD_SET      := Faster Spaceship Docking Rotation Reloaded

SRC_TEMPLATE := src/docking.lua.in

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

RENDERED_INSTANT := $(BUILD)/instant.lua
RENDERED_10X    := $(BUILD)/10x.lua
DESC_INSTANT := instant docking rotation (rebuilt for current NMS)
DESC_10X     := 10x faster docking rotation (rebuilt for current NMS)

.PHONY: all release fomod build verify clean

all: release

release: clean build
	@rm -rf "$(BUILD)/fomodz" && mkdir -p "$(BUILD)/fomodz/fomod" "$(BUILD)/fomodz/Instant" "$(BUILD)/fomodz/10x"
	@cp -a "$(BUILD)/$(MOD_INSTANT)/GLOBALS" "$(BUILD)/fomodz/Instant/"
	@cp -a "$(BUILD)/$(MOD_10X)/GLOBALS" "$(BUILD)/fomodz/10x/"
	@cp ModuleConfig.xml "$(BUILD)/fomodz/fomod/"
	@mkdir -p "$(DIST)" && rm -f "$(DIST)/$(MOD_SET) $(VERSION).zip" && cd "$(BUILD)/fomodz" && zip -qr "$(shell pwd)/$(DIST)/$(MOD_SET) $(VERSION).zip" fomod Instant 10x
	@echo "packed: $(FOMOD_ZIP)"
	@python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$(BUILD)/fomodz/fomod/ModuleConfig.xml'); print('ModuleConfig.xml: well-formed XML')"

# Render the variant scripts from the single template.
$(RENDERED_INSTANT): $(SRC_TEMPLATE)
	@mkdir -p "$(BUILD)"
	@sed -e "s/@VARIANT_LABEL@/Instant/" -e "s/@SPEED@/100/" -e "s/@DESC@/instant docking rotation/" "$(SRC_TEMPLATE)" > "$@"

$(RENDERED_10X): $(SRC_TEMPLATE)
	@mkdir -p "$(BUILD)"
	@sed -e "s/@VARIANT_LABEL@/10x/" -e "s/@SPEED@/10/" -e "s/@DESC@/10x faster docking rotation/" "$(SRC_TEMPLATE)" > "$@"

# One pipeline run builds both variants as individual mods.
build: $(RENDERED_INSTANT) $(RENDERED_10X)
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME) (set AMUMSS_HOME=...)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: run $(AMUMSS_LINUX)/scripts/fetch_mbincompiler.sh with AMUMSS_HOME=$(AMUMSS_HOME) first" >&2; exit 1)
	@mkdir -p "$(BUILD)"
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp "$(RENDERED_INSTANT)" "$(RENDERED_10X)" "$(AMUMSS_HOME)/ModScript/"; \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@rm -rf "$(BUILD)/$(MOD_INSTANT)" "$(BUILD)/$(MOD_10X)"
	@mkdir -p "$(BUILD)/$(MOD_INSTANT)" "$(BUILD)/$(MOD_10X)"
	@cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_INSTANT)/GLOBALS" "$(BUILD)/$(MOD_INSTANT)/"
	@cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_10X)/GLOBALS" "$(BUILD)/$(MOD_10X)/"
	@touch "$(STAMP)"
	@echo "built: $(BUILD)/$(MOD_INSTANT) $(BUILD)/$(MOD_10X)"

# Single zip with a FOMOD installer menu (choose Instant or 10x).
# fomod/ lives at the zip root (that is how managers detect installers).
# Version travels in the zip filename (Nexus convention).
FOMOD_ZIP := $(DIST)/$(MOD_SET) $(VERSION).zip

verify: build
	@test -f "$(BUILD)/$(MOD_INSTANT)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML" || (echo "MISSING instant EXML" >&2; exit 1)
	@test -f "$(BUILD)/$(MOD_10X)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML" || (echo "MISSING 10x EXML" >&2; exit 1)
	@grep -q 'DockingRotateSpeed" value="100' "$(BUILD)/$(MOD_INSTANT)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML" || (echo "BAD instant value" >&2; exit 1)
	@grep -q 'DockingRotateSpeed" value="10' "$(BUILD)/$(MOD_10X)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML" || (echo "BAD 10x value" >&2; exit 1)
	@if grep -q '!#' "$(BUILD)/$(MOD_INSTANT)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML" "$(BUILD)/$(MOD_10X)/GLOBALS/GCSPACESHIPGLOBALS.GLOBAL.EXML"; then echo "marker tags present" >&2; exit 1; fi
	@echo "verify: OK (instant=100, 10x=10, no marker tags)"

clean:
	rm -rf "$(BUILD)" "$(DIST)"
