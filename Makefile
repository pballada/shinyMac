.PHONY: build test app run clean

build:
	swift build

test:
	swift test

app:
	./scripts/bundle.sh

run: app
	open build/ShinyMac.app

clean:
	rm -rf .build build
