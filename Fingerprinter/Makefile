INCLUDES=-IClasses -IiPublicUtility
LIBS=-framework Accelerate -framework AudioUnit
CFLAGS=-Wall


tester: tester.cpp Fingerprinter.o
	g++ ${CFLAGS} ${LIBS} ${INCLUDES} $^ -o tester

Fingerprinter.o: Classes/Fingerprinter.cpp Classes/Fingerprinter.h
	g++ -c ${CFLAGS} ${INCLUDES} $< -o Fingerprinter.o

clean:
	rm Fingerprinter.o tester