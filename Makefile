.PHONY: build assets preview icon install uninstall validate golden clean

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

clean:
	rm -rf build
	rm -f docs/preview.jpg
