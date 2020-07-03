SOURCES := $(shell find Sources)

EOSIO.xcodeproj:
	swift package generate-xcodeproj \
		--enable-code-coverage \
		--skip-extra-files \
		--xcconfig-overrides SR-11321.xcconfig

.PHONY: test
test:
	swift test

.PHONY: update-tests
update-tests:
	swift test --generate-linuxmain && swiftformat \
		Tests/LinuxMain.swift \
		Tests/EOSIOTests/XCTestManifests.swift

docs: $(SOURCES)
	@command -v swift-doc >/dev/null || (echo "doc generator missing, run: brew install swiftdocorg/formulae/swift-doc"; exit 1)
	swift-doc generate Sources/EOSIO \
		--module-name EOSIO \
		--format html \
		--output docs \
	&& touch docs

.PHONY: deploy-docs
deploy-docs: docs
	@command -v gh-pages >/dev/null || (echo "gh-pages missing, run: yarn global add gh-pages"; exit 1)
	gh-pages -d docs

.PHONY: clean
clean:
	rm -rf EOSIO.xcodeproj docs

.PHONY: distclean
distclean: clean
	rm -rf .build
