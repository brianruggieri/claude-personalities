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

- **Functions:** Maximum 20 lines. Decompose into smaller, named helpers with clear single responsibilities.
- **Cyclomatic complexity:** Maximum 5 per function. Extract conditions into named predicates. Replace nested chains with dispatch tables or early returns.
- **Cognitive complexity:** Maximum 8 per function. Reduce nesting by extracting inner blocks. Flatten control flow with guard clauses.
- **Conciseness:** Prefer concise solutions. Don't decompose trivial problems that are clear as a single function.
- **No unnecessary abstractions.** No wrapper functions, adapter patterns, or helper functions that are called only once unless they improve readability.
- **No magic numbers.** Every numeric literal (except 0, 1, -1) must be a named constant.
- **No commented-out code.** Delete it.
