mkfile_path := $(dir $(lastword $(MAKEFILE_LIST)))

SRCLANG := c

APPL_ASMOBJS :=
ifdef USE_CXX
	APPL_CXXOBJS +=
	APPL_COBJS += util.o timer.o horn.o
else
	APPL_COBJS += util.o timer.o horn.o
endif

APPL_DIRS += $(mkfile_path)app $(mkfile_path)../util
INCLUDES += \
	-I$(mkfile_path)app \
	-I$(mkfile_path)../util
