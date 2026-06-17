.PHONY: all aliases subcommands completions test clean

all: aliases subcommands completions

aliases:
	@chmod +x scripts/install-aliases.sh
	@./scripts/install-aliases.sh

subcommands:
	@chmod +x scripts/install-subcommands.sh
	@./scripts/install-subcommands.sh

completions:
	@chmod +x scripts/install-completions.sh
	@./scripts/install-completions.sh

test:
	@chmod +x tests/test-trim.sh scripts/lib/trim.sh
	@./tests/test-trim.sh

clean:
	@echo "🗑️ Cleaning up git-aliases installations..."
	@chmod +x scripts/install-aliases.sh scripts/install-subcommands.sh scripts/install-completions.sh
	@echo "- Removing subcommands..."
	@./scripts/install-subcommands.sh --uninstall
	@echo "- Removing completions..."
	@./scripts/install-completions.sh --uninstall
	@echo "- Removing aliases..."
	@./scripts/install-aliases.sh --uninstall
	@echo "✅ Clean up complete!"
