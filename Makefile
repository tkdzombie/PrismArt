.PHONY: test lint audit check doctor package clean

test:
	swift test

lint:
	bash -n scripts/*.sh
	@for f in $$(find Sources Tests -name '*.swift' | sort); do swiftc -parse "$$f" >/dev/null; done

audit:
	scripts/audit-source.sh

check: test lint audit

doctor:
	scripts/doctor.sh

package:
	scripts/package.sh

clean:
	rm -rf .build dist
