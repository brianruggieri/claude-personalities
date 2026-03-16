# Machine Environment

- **OS:** macOS
- **Shell:** zsh with oh-my-zsh (`~/.zshrc`)
- **Editor:** Zed
- **Repos:** `~/git/`

## Node.js (nvm)

This machine uses nvm. Before running any npm/node/npx commands, activate nvm first:

```bash
source ~/.nvm/nvm.sh && nvm use
```

If a project has `.nvmrc`, `nvm use` picks it up automatically. Otherwise default is Node 22.

## Rust (rustup)

Rust is installed via rustup at `~/.cargo/bin`. The cargo/rustc binaries are not on the default PATH in non-interactive shells. When running Rust tooling:

```bash
source "$HOME/.cargo/env"
```

## Python (pyenv)

pyenv is installed but may not have Python versions configured yet. Check with:

```bash
export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH"
eval "$(pyenv init -)"
pyenv versions
```

If no versions are installed, prompt me before installing one.

## Code Standards — Hard Limits

These are non-negotiable. If code violates any of these, refactor before committing.

- **Functions:** Maximum 20 lines. No exceptions. Decompose into smaller, named helpers with clear single responsibilities.
- **Cyclomatic complexity:** Maximum 5 per function. Extract conditions into named predicate functions. Replace nested if/elif chains with dispatch tables or early returns.
- **Cognitive complexity:** Maximum 8 per function. Reduce nesting depth by extracting inner blocks into named functions. Flatten control flow with guard clauses.
- **Positional parameters:** Maximum 3 per function.
- **Line width:** 100 characters maximum.
- **Imports:** Absolute imports only.
- **No magic numbers.** Every numeric literal (except 0, 1, -1) must be a named constant.
- **No commented-out code.** Delete it.
- **No single-letter variables** outside loop iterators.
