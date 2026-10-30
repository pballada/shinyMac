.PHONY: build test app run icon clean

build:
	swift build

test:
	swift test

app:
	./scripts/bundle.sh

run: app
	open build/ShinyMac.app

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
