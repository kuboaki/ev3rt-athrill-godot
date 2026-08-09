APPL_ASMOBJS :=
ifdef USE_CXX
	APPL_CXXOBJS +=
	APPL_COBJS += util.o
else
	APPL_COBJS += util.o
endif
