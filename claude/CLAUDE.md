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

## Planning & Design-First Workflow

Before writing any implementation code, output a brief design:

1. List the functions and/or classes you will create.
2. State each one's single responsibility in one sentence.
3. Identify which functions call which (the call graph).
4. Identify edge cases that each function must handle.

Then implement exactly that design. Do not deviate from the plan during implementation.

If the implementation reveals the plan was wrong, stop, revise the plan explicitly, then continue.

### Planning Thresholds

- **1 file change:** Proceed directly, but still list functions before coding.
- **2+ files:** Create a checklist of changes before starting.
- **3+ files:** Write a full plan before implementing.

### No Mid-Implementation Redesign

If you realize the approach is wrong while coding, stop. Do not silently change direction. State what changed and why, revise the plan, then continue.
