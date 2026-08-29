.PHONY: all aliases subcommands completions shell test shellcheck clean

all: aliases subcommands completions

aliases:
	@chmod +x scripts/install-aliases.sh
	@./scripts/install-aliases.sh

subcommands:
	@chmod +x scripts/install-subcommands.sh
	@./scripts/install-subcommands.sh

completions:
	@chmod +x scripts/install-completions.bash
	@./scripts/install-completions.bash

shell:
	@chmod +x scripts/install-shell-integration.bash
	@./scripts/install-shell-integration.bash

test:
	@chmod +x tests/test-trim.sh tests/test-git-wt.sh tests/test-wt-wrappers.sh tests/test-install-shell-integration.sh tests/test-install-completions.sh tests/test-zsh-completion.sh tests/test-shunit2-smoke.sh tests/test-shellcheck.sh scripts/lib/trim.sh
	@./tests/test-trim.sh
	@./tests/test-git-wt.sh
	@./tests/test-wt-wrappers.sh
	@./tests/test-install-shell-integration.sh
	@./tests/test-install-completions.sh
	@./tests/test-zsh-completion.sh
	@./tests/test-shunit2-smoke.sh
	@./tests/test-shellcheck.sh

shellcheck:
	@chmod +x scripts/run-shellcheck.sh
	@./scripts/run-shellcheck.sh

clean:
	@echo "🗑️ Cleaning up git-aliases installations..."
	@chmod +x scripts/install-aliases.sh scripts/install-subcommands.sh scripts/install-completions.bash scripts/install-shell-integration.bash
	@echo "- Removing subcommands..."
	@./scripts/install-subcommands.sh --uninstall
	@echo "- Removing completions..."
	@./scripts/install-completions.bash --uninstall
	@echo "- Removing aliases..."
	@./scripts/install-aliases.sh --uninstall
	@echo "- Removing shell integration..."
	@./scripts/install-shell-integration.bash --uninstall
	@echo "✅ Clean up complete!"
