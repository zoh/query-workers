REPORTER=spec
TESTS=$(shell find ./spec -type f -name "*spec.coffee")

test:
	@coffee -c workers/*.coffee
	@NODE_ENV=test ../node_modules/.bin/mocha \
		--require should  \
		--compilers iced:iced-coffee-script \
		--reporter $(REPORTER) \
		--timeout 5000 \
		$(TESTS)
	@rm workers/*.js

manager:
	@NODE_ENV=production
	@coffee -c workers/*.coffee
	@coffee manager.coffee

.PHONY: test
