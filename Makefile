.PHONY: all build run clean

all: build

build:
	./build.sh

run:
	./run.sh

clean:
	rm -rf NoNoTurtle NoNoTurtle.app
