#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Veuillez régler DEVKITARM dans votre environnement. export DEVKITARM = <chemin vers> devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/3ds_rules

# ------------------------------------------------- --------------------------------
# TARGET est le nom de la sortie
# BUILD est le répertoire dans lequel les fichiers objets et les fichiers intermédiaires seront placés
# SOURCES est une liste de répertoires contenant le code source
# DATA est une liste de répertoires contenant des fichiers de données
# INCLUDES est une liste de répertoires contenant des fichiers d'en-tête
# GRAPHICS est une liste de répertoires contenant des fichiers graphiques
# GFXBUILD est le répertoire dans lequel les fichiers graphiques convertis seront placés
# S'il est défini sur $ (BUILD), il sera lié statiquement dans le fichier converti
# fichiers comme s'il s'agissait de fichiers de données.
#
# NO_SMDH: s'il est défini sur quelque chose, aucun fichier SMDH n'est généré.
# ROMFS est le répertoire qui contient le RomFS, relatif au Makefile (facultatif)
# APP_TITLE est le nom de l'application stockée dans le fichier SMDH (facultatif)
# APP_DESCRIPTION est la description de l'application stockée dans le fichier SMDH (facultatif)
# APP_AUTHOR est l'auteur de l'application stockée dans le fichier SMDH (facultatif)
# ICON est le nom de fichier de l'icône (.png), relatif au dossier du projet.
# S'il n'est pas défini, il tente d'utiliser l'un des éléments suivants (dans cet ordre):
# - <Nom du projet> .png
# - icon.png
# - <dossier libctru> /default_icon.png

#---------------------------------------------------------------------------------
# Outils externes
#---------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
MAKEROM 	?= ../makerom.exe
BANNERTOOL 	?= ../bannertool.exe

else
MAKEROM 	?= makerom
BANNERTOOL 	?= bannertool

endif

CURRENT_VERSION := $(shell git describe --abbrev=0 --tags)

# Si sur un commit taggé, utilisez le tag au lieu du commit
ifneq ($(shell echo $(shell git tag -l --points-at HEAD) | head -c 1),)
GIT_VER := $(shell git tag -l --points-at HEAD)
else
GIT_VER := $(shell git describe --abbrev=0 --tags)-$(shell git rev-parse --short HEAD)
endif

#---------------------------------------------------------------------------------
# Version number
#---------------------------------------------------------------------------------
ifneq ($(shell echo $(shell git describe --tags) | head -c 2 | tail -c 1),)
VERSION_MAJOR := $(shell echo $(shell git describe --tags) | head -c 2 | tail -c 1)
else
VERSION_MAJOR := 0
endif

ifneq ($(shell echo $(shell git describe --tags) | head -c 4 | tail -c 1),)
VERSION_MINOR := $(shell echo $(shell git describe --tags) | head -c 4 | tail -c 1)
else
VERSION_MINOR := 0
endif

ifneq ($(shell echo $(shell git describe --tags) | head -c 6 | tail -c 1),)
VERSION_MICRO := $(shell echo $(shell git describe --tags) | head -c 6 | tail -c 1)
else
VERSION_MICRO := 0
endif

#---------------------------------------------------------------------------------
TARGET		:=	GhostEshop
BUILD		:=	build
UNIVCORE	:= 	Universal-Core
SOURCES		:=	$(UNIVCORE) source source/download source/gui source/lang source/menu source/overlays \
										source/qr source/screens source/store source/utils
DATA		:=	data
INCLUDES	:=	$(UNIVCORE) include include/download include/gui include/lang include/overlays include/qr include/screens \
												include/store include/utils
GRAPHICS	:=	assets/gfx
ROMFS		:=	romfs
GFXBUILD	:=	$(ROMFS)/gfx
APP_AUTHOR	:=	Ghost Eshop Team's
APP_DESCRIPTION :=	An Alternative eShop for Nintendo 3DS
ICON		:=	app/icon.png
BNR_IMAGE	:=  app/banner.png
BNR_AUDIO	:=	app/BannerAudio.wav
RSF_FILE	:=	app/build-cia.rsf

#---------------------------------------------------------------------------------
# options de génération de code
#---------------------------------------------------------------------------------
ARCH	:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CFLAGS	:=	-g -Wall -Wno-psabi -O2 -mword-relocations \
			-DV_STRING=\"$(GIT_VER)\" \
			-DC_V=\"$(CURRENT_VERSION)\" \
			-fomit-frame-pointer -ffunction-sections \
			$(ARCH)

CFLAGS	+=	$(INCLUDE) -DARM11 -D_3DS -D_GNU_SOURCE=1

CXXFLAGS	:= $(CFLAGS) -fno-rtti -fno-exceptions -std=gnu++17

ASFLAGS	:=	-g $(ARCH)
LDFLAGS	=	-specs=3dsx.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)

LIBS	:= -lcurl -lmbedtls -lmbedx509 -lmbedcrypto -larchive -lbz2 -llzma -lm -lz -lcitro2d -lcitro3d -lctru -lstdc++

#---------------------------------------------------------------------------------
# liste de répertoires contenant des bibliothèques, ce doit être le niveau supérieur contenant
# include et lib
#---------------------------------------------------------------------------------
LIBDIRS	:= $(PORTLIBS) $(CTRULIB)


#---------------------------------------------------------------------------------
# pas vraiment besoin de modifier quoi que ce soit au-delà de ce point, sauf si vous devez ajouter des
# règles pour différentes extensions de fichiers
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(GRAPHICS),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
PICAFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.v.pica)))
SHLISTFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.shlist)))
GFXFILES	:=	$(foreach dir,$(GRAPHICS),$(notdir $(wildcard $(dir)/*.t3s)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# utiliser CXX pour lier des projets C ++, CC pour le C standard
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
#---------------------------------------------------------------------------------
	export LD	:=	$(CC)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
	export LD	:=	$(CXX)
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
ifeq ($(GFXBUILD),$(BUILD))
#---------------------------------------------------------------------------------
export T3XFILES :=  $(GFXFILES:.t3s=.t3x)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
export ROMFS_T3XFILES	:=	$(patsubst %.t3s, $(GFXBUILD)/%.t3x, $(GFXFILES))
export T3XHFILES		:=	$(patsubst %.t3s, $(BUILD)/%.h, $(GFXFILES))
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

export OFILES_SOURCES 	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES)) \
			$(PICAFILES:.v.pica=.shbin.o) $(SHLISTFILES:.shlist=.shbin.o)

export OFILES := $(OFILES_BIN) $(OFILES_SOURCES)

export HFILES	:=	$(PICAFILES:.v.pica=_shbin.h) $(SHLISTFILES:.shlist=_shbin.h) \
			$(addsuffix .h,$(subst .,_,$(BINFILES)))

export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
			$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
			-I$(CURDIR)/$(BUILD)

export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

export _3DSXDEPS	:=	$(if $(NO_SMDH),,$(OUTPUT).smdh)

ifeq ($(strip $(ICON)),)
	icons := $(wildcard *.png)
	ifneq (,$(findstring $(TARGET).png,$(icons)))
		export APP_ICON := $(TOPDIR)/$(TARGET).png
	else
		ifneq (,$(findstring icon.png,$(icons)))
			export APP_ICON := $(TOPDIR)/icon.png
		endif
	endif
else
	export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_SMDH)),)
	export _3DSXFLAGS += --smdh=$(CURDIR)/$(TARGET).smdh
endif

ifneq ($(ROMFS),)
	export _3DSXFLAGS += --romfs=$(CURDIR)/$(ROMFS)
endif

.PHONY: all clean

#---------------------------------------------------------------------------------
all: $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(T3XHFILES)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf
	@rm -fr $(OUTDIR)


#---------------------------------------------------------------------------------
cia: $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile cia

#---------------------------------------------------------------------------------
3dsx: $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile 3dsx

#---------------------------------------------------------------------------------
$(GFXBUILD)/%.t3x	$(BUILD)/%.h	:	%.t3s
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	$(DEVKITPRO)/tools/bin/tex3ds -i $< -H $(BUILD)/$*.h -d $(DEPSDIR)/$*.d -o $(GFXBUILD)/$*.t3x

#---------------------------------------------------------------------------------
$(BUILD):
	@[ -d $@ ] || mkdir -p $@

#---------------------------------------------------------------------------------
else

#---------------------------------------------------------------------------------
# cibles principales
#---------------------------------------------------------------------------------
all: $(OUTPUT).cia $(OUTPUT).elf $(OUTPUT).3dsx

$(OUTPUT).elf	:	$(OFILES)

$(OUTPUT).cia	:	$(OUTPUT).elf $(OUTPUT).smdh
	$(BANNERTOOL) makebanner -i "../app/banner.png" -a "../app/BannerAudio.wav" -o "../app/banner.bin"

	$(BANNERTOOL) makesmdh -i "../app/icon.png" -s "$(TARGET)" -l "$(APP_DESCRIPTION)" -p "$(APP_AUTHOR)" -o "../app/icon.bin" \
		--flags visible,ratingrequired,recordusage --cero 153 --esrb 153 --usk 153 --pegigen 153 --pegiptr 153 --pegibbfc 153 --cob 153 --grb 153 --cgsrr 153

	$(MAKEROM) -f cia -target t -exefslogo -o "../$(TARGET).cia" -elf "../$(TARGET).elf" -rsf "../app/build-cia.rsf" -banner "../app/banner.bin" -icon "../app/icon.bin" -logo "../app/logo.bcma.lz" -DAPP_ROMFS="$(TOPDIR)/$(ROMFS)" -major $(VERSION_MAJOR) -minor $(VERSION_MINOR) -DAPP_VERSION_MAJOR="$(VERSION_MAJOR)"
#---------------------------------------------------------------------------------
# vous avez besoin d'une règle comme celle-ci pour chaque extension que vous utilisez comme données binaires
#---------------------------------------------------------------------------------
%.bin.o	%_bin.h :	%.bin
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

#---------------------------------------------------------------------------------
.PRECIOUS	:	%.t3x
#---------------------------------------------------------------------------------
%.t3x.o	%_t3x.h :	%.t3x
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

#---------------------------------------------------------------------------------
# règles d'assemblage de shaders GPU
#---------------------------------------------------------------------------------
define shader-as
	$(eval CURBIN := $*.shbin)
	$(eval DEPSFILE := $(DEPSDIR)/$*.shbin.d)
	echo "$(CURBIN).o: $< $1" > $(DEPSFILE)
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"_end[];" > `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"[];" >> `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u32" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`_size";" >> `(echo $(CURBIN) | tr . _)`.h
	picasso -o $(CURBIN) $1
	bin2s $(CURBIN) | $(AS) -o $*.shbin.o
endef

%.shbin.o %_shbin.h : %.v.pica %.g.pica
	@echo $(notdir $^)
	@$(call shader-as,$^)

%.shbin.o %_shbin.h : %.v.pica
	@echo $(notdir $<)
	@$(call shader-as,$<)

%.shbin.o %_shbin.h : %.shlist
	@echo $(notdir $<)
	@$(call shader-as,$(foreach file,$(shell cat $<),$(dir $<)$(file)))

#---------------------------------------------------------------------------------
%.t3x	%.h	:	%.t3s
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@tex3ds -i $< -H $*.h -d $*.d -o $*.t3x

-include $(DEPSDIR)/*.d

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------