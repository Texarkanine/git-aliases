.PHONY: all aliases subcommands completions

all: aliases subcommands completions

aliases:
	@echo "📥 Installing Git aliases..."
	@for file in aliases/*; do \
		if [ -f "$$file" ] && [ "$$(basename "$$file")" != "README.md" ]; then \
			echo "📃 $$file..."; \
			while IFS= read -r line; do \
				if [ -n "$$line" ] && ! echo "$$line" | grep -q "^[[:space:]]*#"; then \
					name=$$(echo "$$line" | cut -d'=' -f1 | sed 's/^[ \t]*//;s/[ \t]*$$//'); \
					value=$$(echo "$$line" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$$//'); \
					if [ -n "$$name" ] && [ -n "$$value" ]; then \
						echo "	$$name -> $$value"; \
						git config --global "alias.$$name" "$$value"; \
					fi; \
				fi; \
			done < "$$file"; \
		fi; \
	done
	@echo "✅ Git aliases installed successfully!"

subcommands:
	@echo "📥 Installing Git subcommands..."
	@mkdir -p ~/.local/bin
	@find subcommands -name "*.bash" -type f ! -name "*-completion.bash" | while read file; do \
		cmd_name=$$(basename "$$file" .bash); \
		cmd_base=$$(basename "$$cmd_name" | sed 's/^git-//'); \
		target=~/.local/bin/git-$$cmd_base; \
		echo "	git-$$cmd_base"; \
		cp "$$file" "$$target"; \
		chmod +x "$$target"; \
	done
	@echo "✅ Git subcommands installed successfully!"
	@echo "Make sure ~/.local/bin is in your PATH."

completions:
	@echo "📥 Installing bash completions..."
	@chmod +x ./install-bash-completion.sh
	@./install-bash-completion.sh install
	@echo "✅ Bash completions installed successfully!"
	@echo "Note: Source your ~/.bash_completion or restart your shell to enable completions"
