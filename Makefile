.PHONY: build assets preview icon install uninstall validate golden dmg bench live notarize clean

build:
	./scripts/build.sh

assets:
	./scripts/make-assets.sh

preview:
	./scripts/make-assets.sh --preview

icon:
	./scripts/make-icon.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

validate:
	./scripts/validate.sh

golden:
	./scripts/golden-test.sh

dmg:
	./scripts/make-dmg.sh

notarize:
	./scripts/notarize.sh build/Quantum-Terminal-Live-*.dmg

live:
	./scripts/build.sh >/dev/null
	./build/RenderPreview Assets/quantum-terminal-live-wallpaper-8k.png docs/preview-live.gif 480 300 12.0 10.0 10

bench:
	swiftc -O -target "$$(uname -m)-apple-macosx14.0" \
		-module-cache-path build/.module-cache \
		Sources/QuantumArtwork.swift Sources/QuantumScene.swift tools/Bench/main.swift \
		-o build/BenchScene \
		-framework AppKit -framework QuartzCore -framework CoreGraphics
	./build/BenchScene

clean:
	rm -rf build
	rm -f docs/preview.jpg
