.PHONY: build test app run icon release clean

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

release:
	./scripts/release.sh $(VERSION)

clean:
	rm -rf .build build
