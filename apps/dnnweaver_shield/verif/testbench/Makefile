FILELIST = file.list
SRC := $(shell cat $(FILELIST) | egrep -v '\#')

COMPILER = iverilog
COMPILER_FLAGS = #-Wall
COMPILER_OUTPUT = compiler.out

SIMULATOR = vvp
SIMULATOR_FLAGS = -vcd
WAVEFORM = TB.vcd

WAVEFORM_VIEWER = gtkwave
###############################################################################
all: simulate

compile: $(SRC) $(FILELIST)
	$(COMPILER) $(COMPILER_FLAGS) -c $(FILELIST) -o $(COMPILER_OUTPUT)

simulate: $(COMPILER_OUTPUT) $(SRC) $(FILELIST)
	$(SIMULATOR) $(SOPTIONS) $(COMPILER_OUTPUT) $(SIMULATOR_FLAGS)

display: $(WAVEFORM)
	$(WAVEFORM_VIEWER) $(WAVEFORM) &

$(WAVEFORM): $(COMPILER_OUTPUT) $(SRC) $(FILELIST)
	$(SIMULATOR) $(SOPTIONS) $(COMPILER_OUTPUT) $(SIMULATOR_FLAGS)

$(COMPILER_OUTPUT): $(SRC) $(FILELIST)
	$(COMPILER) $(COMPILER_FLAGS) -c $(FILELIST) -o $(COMPILER_OUTPUT)

clean: 
	\rm $(WAVEFORM) $(COMPILER_OUTPUT)
