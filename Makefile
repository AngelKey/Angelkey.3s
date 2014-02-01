ICED=node_modules/.bin/iced
BUILD_STAMP=build-stamp
TEST_STAMP=test-stamp
UGLIFYJS=node_modules/.bin/uglifyjs
WD=`pwd`

default: build
all: build

lib/%.js: src/%.iced
	$(ICED) -I node -c -o lib $<

$(BUILD_STAMP): \
	lib/cmd.js
	date > $@

build: $(BUILD_STAMP) 

clean:
	rm -f lib/*.js $(BUILD_STAMP) $(TEST_STAMP)

setup:
	npm install -d

.PHONY: clean setup 

