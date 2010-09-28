INCLUDES=-IClasses -IiPublicUtility
LIBS=-framework Accelerate -framework AudioUnit -framework CoreAudio
CFLAGS=-Wall


build/tester: tester.cpp build/Fingerprinter.o
	g++ ${CFLAGS} ${LIBS} ${INCLUDES} $^ -o build/tester

build/Fingerprinter.o: Classes/Fingerprinter.cpp Classes/Fingerprinter.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o build/Fingerprinter.o

clean:
	rm build.Fingerprinter.o build/tester

test: build/tester
	./build/tester