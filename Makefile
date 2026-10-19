.SUFFIXES:

all: documentation lint luals test

# runs all the test files.
test:
	make deps
	nvim --version | head -n 1 && echo ''
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) } })"

# runs all the test files on the nightly version, `bob` must be installed.
test-nightly:
	bob use nightly
	make test

# runs all the test files on the 0.9.5 version, `bob` must be installed.
test-0.9.5:
	bob use 0.9.5
	make test

# installs `mini.nvim`, used for both the tests and documentation.
deps:
	@mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim

# installs deps before running tests, useful for the CI.
test-ci: deps test

# generates the documentation.
documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.doc').generate({ 'lua/github-actions/init.lua', 'lua/github-actions/config.lua' }, 'doc/github-actions.txt')" \
		-c "qa!"

# installs deps before running the documentation generation, useful for the CI.
documentation-ci: deps documentation

# performs a lint check and fixes issue if possible, following the config in `stylua.toml`.
lint:
	stylua . -g '*.lua' -g '!deps/' -g '!nightly/'
	luacheck plugin/ lua/

luals-ci:
	rm -rf .ci/lua-ls/log
	lua-language-server --configpath .luarc.json --logpath .ci/lua-ls/log --check .
	[ -f .ci/lua-ls/log/check.json ] && { cat .ci/lua-ls/log/check.json 2>/dev/null; exit 1; } || true

LUALS_VERSION := 3.7.4
LUALS_PLATFORM := $(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')

luals:
	mkdir -p .ci/lua-ls
	curl -sL "https://github.com/LuaLS/lua-language-server/releases/download/$(LUALS_VERSION)/lua-language-server-$(LUALS_VERSION)-$(LUALS_PLATFORM).tar.gz" | tar xzf - -C "${PWD}/.ci/lua-ls"
	PATH="${PWD}/.ci/lua-ls/bin:${PATH}" make luals-ci
