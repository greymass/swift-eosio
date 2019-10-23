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

.PHONY: clean
clean:
	rm -rf EOSIO.xcodeproj

.PHONY: distclean
distclean: clean
	rm -rf .build
