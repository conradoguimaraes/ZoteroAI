.PHONY: verify plugin helper install-helper package

verify:
	./scripts/verify.sh

plugin:
	./scripts/build-plugin.sh

helper:
	./scripts/build-helper.sh

install-helper:
	./scripts/install-helper.sh

package:
	./scripts/package-release.sh
