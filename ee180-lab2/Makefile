# Set compiler args
CC=g++
CFLAGS=-Wall -c -O3 -mfpu=neon -mcpu=cortex-a9 #-flax-vector-conversions  # -fno-tree-vectorize
LDFLAGS=
LDLIBS=-L /usr/lib $$(pkg-config --cflags --libs opencv) -pthread
ifeq ($(shell arch), armv7l)
	LDLIBS += -lpfm
endif
SOURCES=main.cpp pc.cpp sobel_st.cpp sobel_mt.cpp sobel_calc.cpp
OBJECTS=$(SOURCES:.cpp=.o)
EXECUTABLE=sobel
TAR=lab2.tar.gz
SUBMIT_FILES=lab2/*.cpp lab2/*.h lab2/README lab2/Makefile

all: $(SOURCES) $(EXECUTABLE)

$(EXECUTABLE):$(OBJECTS)
	$(CC) -o $@ $(LDFLAGS) $(OBJECTS) $(LDLIBS)

.cpp.o:
	$(CC) $(CFLAGS) $< -o $@

run:
	./sobel
clean:
	\rm -f *.o $(EXECUTABLE) $(TAR)

submit: clean
	ln -s . lab2
	tar -czf $(TAR) $(SUBMIT_FILES)
	rm -f lab2
