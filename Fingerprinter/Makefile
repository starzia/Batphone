INCLUDES=-IClasses -IiPublicUtility
LIBS=-framework Accelerate -framework AudioUnit -framework CoreAudio
CFLAGS=-Wall -ggdb
OBJS=build/Fingerprinter.o build/Spectrogram.o build/SlidingWindow.o build/SlidingWindow.o build/Heap.o

build/tester: tester.cpp ${OBJS}
	g++ ${CFLAGS} ${LIBS} ${INCLUDES} $^ -o $@

build/Fingerprinter.o: Classes/Fingerprinter.cpp Classes/Fingerprinter.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o $@

build/Spectrogram.o: Classes/Spectrogram.cpp Classes/Spectrogram.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o $@

build/SlidingWindow.o: Classes/SlidingWindow.cpp Classes/SlidingWindow.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o $@

build/Heap.o: Classes/Heap.cpp Classes/Heap.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o $@


clean:
	rm ${OBJS} build/tester

test: build/tester
	./build/tester