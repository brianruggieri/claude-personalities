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

## Testing Discipline

- Every change that touches logic gets a test. No exceptions.
- New behavior: write a failing test first, then implement, then refactor (red-green-refactor).
- Bug fixes: write a regression test that reproduces the bug before writing the fix.
- Test behavior, not implementation. Tests should survive refactoring.
- Mock boundaries (network, filesystem, databases), not internal logic.
- Verify tests actually catch failures: break the code and confirm the test fails.
- After any code change: run the test suite before reporting done.
