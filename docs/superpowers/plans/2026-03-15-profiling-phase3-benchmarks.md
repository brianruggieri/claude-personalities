# Phase 3: Benchmark System — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run standardized benchmark tasks against profiles, score them automatically, accumulate results in `_metrics/benchmarks/`, and display comparison tables.

**Architecture:** Benchmark tasks live in `benchmarks/tasks/<name>/` with metadata, prompts, verify scripts, and optional fixtures. The runner (`cmd_benchmark`) creates a temp dir, copies fixtures, invokes `claude -p` non-interactively, runs verify.sh, captures metrics from `~/.claude.json`, and stores results. A `--report` mode reads stored results without running anything.

**Tech Stack:** Bash (setup.sh), Python3 (stdlib only), Claude CLI (`claude -p --dangerously-skip-permissions`)

**CLI note:** The spec references `--cwd` and `--prompt` flags that don't exist. The correct invocation is `cd "$tmpdir" && claude -p "$(cat prompt.md)"`. Using `--dangerously-skip-permissions` for automated, non-interactive runs and `--max-budget-usd` as a safety cap.

---

## Prerequisite

Verify you're on the `main` branch:
```bash
git branch --show-current  # must be "main"
```

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `benchmarks/tasks/hello-world/task.json` | Create | Task metadata |
| `benchmarks/tasks/hello-world/prompt.md` | Create | Prompt sent to Claude |
| `benchmarks/tasks/hello-world/verify.sh` | Create | Pass/fail check |
| `benchmarks/tasks/fix-python-bug/task.json` | Create | Task metadata |
| `benchmarks/tasks/fix-python-bug/prompt.md` | Create | Prompt sent to Claude |
| `benchmarks/tasks/fix-python-bug/verify.sh` | Create | Pass/fail check |
| `benchmarks/tasks/fix-python-bug/fixture/` | Create | Buggy starter code + failing test |
| `benchmarks/tasks/create-react-component/task.json` | Create | Task metadata |
| `benchmarks/tasks/create-react-component/prompt.md` | Create | Prompt sent to Claude |
| `benchmarks/tasks/create-react-component/verify.sh` | Create | Pass/fail check |
| `benchmarks/tasks/write-unit-tests/task.json` | Create | Task metadata |
| `benchmarks/tasks/write-unit-tests/prompt.md` | Create | Prompt sent to Claude |
| `benchmarks/tasks/write-unit-tests/verify.sh` | Create | Pass/fail check |
| `benchmarks/tasks/write-unit-tests/fixture/` | Create | Untested Python module |
| `benchmarks/tasks/review-code-diff/task.json` | Create | Task metadata |
| `benchmarks/tasks/review-code-diff/prompt.md` | Create | Prompt sent to Claude |
| `benchmarks/tasks/review-code-diff/verify.sh` | Create | Pass/fail check |
| `benchmarks/tasks/review-code-diff/fixture/` | Create | Code diff to review |
| `setup.sh` | Modify | Add `cmd_benchmark`, `_benchmark_report`, `_benchmark_results_table`, update `_profile_table()`, `usage()`, dispatch |

---

## Chunk 1: Benchmark Tasks

### Task 1: hello-world benchmark

The simplest possible benchmark — measures pure Claude Code overhead. Every profile should pass.

**Files:**
- Create: `benchmarks/tasks/hello-world/task.json`
- Create: `benchmarks/tasks/hello-world/prompt.md`
- Create: `benchmarks/tasks/hello-world/verify.sh`

- [ ] **Step 1: Create task.json**

```json
{
  "name": "hello-world",
  "description": "Baseline cost measurement — respond with a specific string",
  "category": "baseline",
  "capability": null,
  "difficulty": "trivial",
  "timeout": 30,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

- [ ] **Step 2: Create prompt.md**

```markdown
Create a file called `output.txt` containing exactly this text: `Hello from Claude Code`

Do not add anything else to the file. No extra newlines, no comments, no other files.
```

- [ ] **Step 3: Create verify.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/output.txt" ]; then
	echo "FAIL: output.txt not found"
	exit 1
fi

content="$(cat "$dir/output.txt")"
if [ "$content" = "Hello from Claude Code" ]; then
	echo "PASS"
	exit 0
else
	echo "FAIL: expected 'Hello from Claude Code', got '$content'"
	exit 1
fi
```

- [ ] **Step 4: Make verify.sh executable**

```bash
chmod +x benchmarks/tasks/hello-world/verify.sh
```

- [ ] **Step 5: Commit**

```bash
git add benchmarks/tasks/hello-world/
git commit -m "Add hello-world benchmark task"
```

---

### Task 2: fix-python-bug benchmark

Tests debugging capability. Fixture has a buggy Python module and a failing test.

**Files:**
- Create: `benchmarks/tasks/fix-python-bug/task.json`
- Create: `benchmarks/tasks/fix-python-bug/prompt.md`
- Create: `benchmarks/tasks/fix-python-bug/verify.sh`
- Create: `benchmarks/tasks/fix-python-bug/fixture/calculator.py`
- Create: `benchmarks/tasks/fix-python-bug/fixture/test_calculator.py`

- [ ] **Step 1: Create fixture/calculator.py (with bug)**

```python
def add(a, b):
    return a + b


def divide(a, b):
    return a / b


def average(numbers):
    total = 0
    for n in numbers:
        total += n
    # Bug: off-by-one — divides by len+1 instead of len
    return divide(total, len(numbers) + 1)
```

- [ ] **Step 2: Create fixture/test_calculator.py**

```python
from calculator import add, divide, average


def test_add():
    assert add(2, 3) == 5


def test_divide():
    assert divide(10, 2) == 5.0


def test_divide_by_zero():
    try:
        divide(1, 0)
        assert False, "Should have raised ZeroDivisionError"
    except ZeroDivisionError:
        pass


def test_average():
    assert average([10, 20, 30]) == 20.0


def test_average_single():
    assert average([42]) == 42.0
```

- [ ] **Step 3: Create task.json**

```json
{
  "name": "fix-python-bug",
  "description": "Fix a failing test in a small Python project",
  "category": "debugging",
  "capability": "tdd-workflow",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

- [ ] **Step 4: Create prompt.md**

```markdown
This directory has a Python module `calculator.py` and tests in `test_calculator.py`.

Some tests are failing. Find and fix the bug(s) so all tests pass.

Run the tests with: `python3 -m pytest test_calculator.py -v`

Do not add new tests or change existing test assertions. Only fix the implementation.
```

- [ ] **Step 5: Create verify.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
dir="$1"

cd "$dir"
if python3 -m pytest test_calculator.py -v 2>&1; then
	echo "PASS"
	exit 0
else
	echo "FAIL: tests did not pass"
	exit 1
fi
```

- [ ] **Step 6: Make verify.sh executable and commit**

```bash
chmod +x benchmarks/tasks/fix-python-bug/verify.sh
git add benchmarks/tasks/fix-python-bug/
git commit -m "Add fix-python-bug benchmark task"
```

---

### Task 3: create-react-component benchmark

Tests frontend capability. No fixture — Claude creates from scratch.

**Files:**
- Create: `benchmarks/tasks/create-react-component/task.json`
- Create: `benchmarks/tasks/create-react-component/prompt.md`
- Create: `benchmarks/tasks/create-react-component/verify.sh`

- [ ] **Step 1: Create task.json**

```json
{
  "name": "create-react-component",
  "description": "Create a React component from a design specification",
  "category": "frontend",
  "capability": "frontend-design",
  "difficulty": "basic",
  "timeout": 180,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

- [ ] **Step 2: Create prompt.md**

```markdown
Create a React component called `StatusBadge` in a file called `StatusBadge.jsx`.

Requirements:
- Accepts a `status` prop: one of "active", "inactive", "pending"
- Accepts an optional `label` prop (string) — if not provided, use the status as the label
- Renders a `<span>` with:
  - A CSS class of `status-badge status-{status}` (e.g., `status-badge status-active`)
  - The label text inside the span
  - A `data-testid="status-badge"` attribute
- Export the component as the default export

Do not use any external libraries. Do not create any other files.
```

- [ ] **Step 3: Create verify.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/StatusBadge.jsx" ]; then
	echo "FAIL: StatusBadge.jsx not found"
	exit 1
fi

content="$(cat "$dir/StatusBadge.jsx")"
errors=""

# Check for default export
if ! echo "$content" | grep -qE "export default|module\.exports"; then
	errors="${errors}Missing default export. "
fi

# Check for status-badge class
if ! echo "$content" | grep -q "status-badge"; then
	errors="${errors}Missing status-badge CSS class. "
fi

# Check for data-testid
if ! echo "$content" | grep -q "data-testid"; then
	errors="${errors}Missing data-testid attribute. "
fi

# Check that it accepts status prop
if ! echo "$content" | grep -q "status"; then
	errors="${errors}Missing status prop usage. "
fi

if [ -z "$errors" ]; then
	echo "PASS"
	exit 0
else
	echo "FAIL: $errors"
	exit 1
fi
```

- [ ] **Step 4: Make verify.sh executable and commit**

```bash
chmod +x benchmarks/tasks/create-react-component/verify.sh
git add benchmarks/tasks/create-react-component/
git commit -m "Add create-react-component benchmark task"
```

---

### Task 4: write-unit-tests benchmark

Tests whether the profile produces good test coverage for untested code.

**Files:**
- Create: `benchmarks/tasks/write-unit-tests/task.json`
- Create: `benchmarks/tasks/write-unit-tests/prompt.md`
- Create: `benchmarks/tasks/write-unit-tests/verify.sh`
- Create: `benchmarks/tasks/write-unit-tests/fixture/validators.py`

- [ ] **Step 1: Create fixture/validators.py**

```python
import re


def validate_email(email):
    if not isinstance(email, str):
        raise TypeError("email must be a string")
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_password(password, min_length=8):
    if not isinstance(password, str):
        raise TypeError("password must be a string")
    if len(password) < min_length:
        return False, "too short"
    if not re.search(r'[A-Z]', password):
        return False, "missing uppercase"
    if not re.search(r'[a-z]', password):
        return False, "missing lowercase"
    if not re.search(r'[0-9]', password):
        return False, "missing digit"
    return True, "ok"


def validate_username(username):
    if not isinstance(username, str):
        raise TypeError("username must be a string")
    if len(username) < 3 or len(username) > 20:
        return False
    return bool(re.match(r'^[a-zA-Z][a-zA-Z0-9_]*$', username))
```

- [ ] **Step 2: Create task.json**

```json
{
  "name": "write-unit-tests",
  "description": "Write comprehensive unit tests for an untested Python module",
  "category": "testing",
  "capability": "tdd-workflow",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

- [ ] **Step 3: Create prompt.md**

```markdown
This directory has a Python module `validators.py` with three validation functions: `validate_email`, `validate_password`, and `validate_username`.

Write comprehensive unit tests in a file called `test_validators.py`.

Requirements:
- Test all three functions
- Test both valid and invalid inputs for each function
- Test edge cases (empty strings, wrong types, boundary lengths)
- All tests must pass when run with: `python3 -m pytest test_validators.py -v`

Do not modify `validators.py`.
```

- [ ] **Step 4: Create verify.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/test_validators.py" ]; then
	echo "FAIL: test_validators.py not found"
	exit 1
fi

cd "$dir"

# Tests must pass
if ! python3 -m pytest test_validators.py -v 2>&1; then
	echo "FAIL: tests did not pass"
	exit 1
fi

# Must test all three functions (at least one test per function)
content="$(cat test_validators.py)"
missing=""
for func in validate_email validate_password validate_username; do
	if ! echo "$content" | grep -q "$func"; then
		missing="${missing}$func "
	fi
done

if [ -n "$missing" ]; then
	echo "FAIL: missing tests for: $missing"
	exit 1
fi

# Must have at least 8 test functions (reasonable minimum for 3 validators)
test_count="$(grep -c 'def test_' "$dir/test_validators.py")"
if [ "$test_count" -lt 8 ]; then
	echo "FAIL: only $test_count tests, expected at least 8"
	exit 1
fi

echo "PASS ($test_count tests)"
exit 0
```

- [ ] **Step 5: Make verify.sh executable and commit**

```bash
chmod +x benchmarks/tasks/write-unit-tests/verify.sh
git add benchmarks/tasks/write-unit-tests/
git commit -m "Add write-unit-tests benchmark task"
```

---

### Task 5: review-code-diff benchmark

Tests code review capability. Fixture is a diff with intentional issues.

**Files:**
- Create: `benchmarks/tasks/review-code-diff/task.json`
- Create: `benchmarks/tasks/review-code-diff/prompt.md`
- Create: `benchmarks/tasks/review-code-diff/verify.sh`
- Create: `benchmarks/tasks/review-code-diff/fixture/diff.patch`

- [ ] **Step 1: Create fixture/diff.patch**

```diff
diff --git a/auth.py b/auth.py
index 1234567..abcdefg 100644
--- a/auth.py
+++ b/auth.py
@@ -1,10 +1,25 @@
+import os
 import hashlib
+import sqlite3


-def check_password(stored_hash, password):
-    return hashlib.sha256(password.encode()).hexdigest() == stored_hash
+DB_PASSWORD = "admin123"
+
+def check_password(stored_hash, password, salt=""):
+    return hashlib.md5(password.encode()).hexdigest() == stored_hash


 def login(username, password):
-    user = db.get_user(username)
-    return check_password(user.password_hash, password)
+    conn = sqlite3.connect("users.db")
+    query = f"SELECT * FROM users WHERE username = '{username}'"
+    cursor = conn.execute(query)
+    row = cursor.fetchone()
+    if row and check_password(row[1], password):
+        return True
+    return False
+
+
+def admin_reset(user_id):
+    conn = sqlite3.connect("users.db")
+    conn.execute(f"UPDATE users SET password = '{DB_PASSWORD}' WHERE id = {user_id}")
+    conn.commit()
```

- [ ] **Step 2: Create task.json**

```json
{
  "name": "review-code-diff",
  "description": "Review a code diff and identify security and quality issues",
  "category": "review",
  "capability": "code-review",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"]
}
```

- [ ] **Step 3: Create prompt.md**

```markdown
Review the code diff in `diff.patch` and write your findings to a file called `review.md`.

For each issue found, include:
- A severity level (critical, high, medium, low)
- The specific line or code fragment
- What the issue is
- How to fix it

Focus on security vulnerabilities, bugs, and bad practices. Be thorough.
```

- [ ] **Step 4: Create verify.sh**

The diff has 4 clear issues: SQL injection, hardcoded password, MD5 hashing, and f-string SQL in admin_reset. A good review should catch at least 3.

```bash
#!/usr/bin/env bash
set -euo pipefail
dir="$1"

if [ ! -f "$dir/review.md" ]; then
	echo "FAIL: review.md not found"
	exit 1
fi

content="$(cat "$dir/review.md" | tr '[:upper:]' '[:lower:]')"
found=0

# Check for SQL injection detection
if echo "$content" | grep -qE "sql.?inject|f-string.*sql|string.?format.*query|unsanitized|parameterize"; then
	found=$((found + 1))
fi

# Check for hardcoded password/credential detection
if echo "$content" | grep -qE "hardcoded|hard.?coded|credential|db_password|admin123|secret.*code"; then
	found=$((found + 1))
fi

# Check for weak hashing detection
if echo "$content" | grep -qE "md5|weak.*hash|insecure.*hash|sha256.*removed|downgrade"; then
	found=$((found + 1))
fi

# Check for second SQL injection (admin_reset)
if echo "$content" | grep -qE "admin_reset|update.*inject|f.*update|second.*inject"; then
	found=$((found + 1))
fi

if [ "$found" -ge 3 ]; then
	echo "PASS ($found/4 issues detected)"
	exit 0
else
	echo "FAIL: only detected $found/4 expected issues"
	exit 1
fi
```

- [ ] **Step 5: Make verify.sh executable and commit**

```bash
chmod +x benchmarks/tasks/review-code-diff/verify.sh
git add benchmarks/tasks/review-code-diff/
git commit -m "Add review-code-diff benchmark task"
```

---

## Chunk 2: Benchmark Runner

### Task 6: Add `cmd_benchmark` function — runner mode

**Files:**
- Modify: `setup.sh` — insert after `_session_averages()`, before `# Main dispatch for profile command`

- [ ] **Step 1: Add the core benchmark runner**

Insert after the `_session_averages` closing brace and before `# Main dispatch for profile command`:

```bash
# ─── Benchmarks ───────────────────────────────────────────────────────────────

# Run a single benchmark task. Called by cmd_benchmark.
# Usage: _benchmark_run_task <task_dir> <profile>
_benchmark_run_task() {
	local task_dir="$1"
	local profile="$2"
	local task_name
	task_name="$(basename "$task_dir")"

	# Read task metadata
	local timeout
	timeout="$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get('timeout', 120))
except Exception:
    print('120')
" "$task_dir/task.json")"

	echo "  Running: $task_name (timeout: ${timeout}s)"

	# Create temp working directory
	local tmpdir
	tmpdir="$(mktemp -d)"

	# Copy fixture files if present
	if [ -d "$task_dir/fixture" ]; then
		cp -a "$task_dir/fixture/." "$tmpdir/"
	fi

	# Copy expected files if present (for verify.sh to reference)
	if [ -d "$task_dir/expected" ]; then
		cp -a "$task_dir/expected" "$tmpdir/_expected"
	fi

	# Run claude in print mode
	local prompt
	prompt="$(cat "$task_dir/prompt.md")"
	local claude_exit=0
	local start_time
	start_time="$(date +%s)"

	(cd "$tmpdir" && timeout "$timeout" claude -p \
		--dangerously-skip-permissions \
		--no-session-persistence \
		--max-budget-usd 5 \
		"$prompt" > /dev/null 2>&1) || claude_exit=$?

	local end_time
	end_time="$(date +%s)"
	local wall_seconds=$(( end_time - start_time ))

	# Run verification
	local passed=false
	local verify_output=""
	if [ -f "$task_dir/verify.sh" ]; then
		verify_output="$("$task_dir/verify.sh" "$tmpdir" 2>&1)" && passed=true || passed=false
	fi

	# Capture metrics from ~/.claude.json for the tmpdir project
	local results_dir="$REPO_DIR/_metrics/benchmarks/$profile/$task_name"
	mkdir -p "$results_dir"
	local timestamp
	timestamp="$(date -u +%Y%m%d-%H%M%S)"

	python3 - "$HOME/.claude.json" "$profile" "$task_name" "$tmpdir" \
		"$results_dir/${timestamp}.json" "$passed" "$wall_seconds" <<'PYEOF'
import json, sys, os

try:
    claude_json_path = sys.argv[1]
    profile = sys.argv[2]
    task_name = sys.argv[3]
    tmpdir = sys.argv[4]
    out_path = sys.argv[5]
    passed = sys.argv[6] == 'true'
    wall_seconds = int(sys.argv[7])

    cost = 0
    duration = 0
    input_tokens = 0
    output_tokens = 0
    cache_read = 0
    cache_creation = 0
    model = "unknown"

    try:
        with open(claude_json_path, 'r') as f:
            data = json.load(f)
        proj = data.get('projects', {}).get(tmpdir, {})
        cost = proj.get('lastCost', 0)
        duration = round(proj.get('lastDuration', 0) / 1000)
        input_tokens = proj.get('lastTotalInputTokens', 0)
        output_tokens = proj.get('lastTotalOutputTokens', 0)
        cache_creation = proj.get('lastTotalCacheCreationInputTokens', 0)
        cache_read = proj.get('lastTotalCacheReadInputTokens', 0)
        model_usage = proj.get('lastModelUsage', {})
        if model_usage:
            model = list(model_usage.keys())[0]
    except Exception:
        pass

    # Use wall clock as fallback if no API duration
    if duration == 0:
        duration = wall_seconds

    result = {
        'profile': profile,
        'task': task_name,
        'timestamp': __import__('datetime').datetime.now(
            __import__('datetime').timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'passed': passed,
        'score': 1 if passed else 0,
        'cost_usd': cost,
        'duration_seconds': duration,
        'total_input_tokens': input_tokens,
        'total_output_tokens': output_tokens,
        'cache_read_tokens': cache_read,
        'cache_creation_tokens': cache_creation,
        'model': model,
    }

    with open(out_path, 'w') as f:
        json.dump(result, f, indent=2)
        f.write('\n')

except Exception:
    pass
PYEOF

	# Print result
	if [ "$passed" = "true" ]; then
		echo "    PASS  $verify_output"
	else
		echo "    FAIL  $verify_output"
		if [ "$claude_exit" -ne 0 ]; then
			echo "    (claude exited with code $claude_exit)"
		fi
	fi

	# Clean up temp directory
	rm -r "$tmpdir" 2>/dev/null || true
}

# Main benchmark command.
# Usage: cmd_benchmark [--task <name>] [--report]
cmd_benchmark() {
	local mode="run"
	local single_task=""

	while [ $# -gt 0 ]; do
		case "$1" in
			--task)
				single_task="${2:-}"
				if [ -z "$single_task" ]; then
					echo "usage: ./setup.sh benchmark --task <name>"
					return 1
				fi
				shift 2
				;;
			--report)
				mode="report"
				shift
				;;
			*)
				shift
				;;
		esac
	done

	if [ "$mode" = "report" ]; then
		_benchmark_report
		return
	fi

	local profile
	profile="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "unknown")"
	local tasks_dir="$REPO_DIR/benchmarks/tasks"

	if [ ! -d "$tasks_dir" ]; then
		echo "No benchmark tasks found in benchmarks/tasks/"
		return 1
	fi

	# Check claude CLI is available
	if ! command -v claude &>/dev/null; then
		echo "claude CLI not found. Install Claude Code first."
		return 1
	fi

	echo ""
	echo "Benchmark Runner — Profile: $profile"
	printf '═%.0s' {1..60}; echo ""

	local task_count=0
	local pass_count=0

	for task_dir in "$tasks_dir"/*/; do
		[ -f "$task_dir/task.json" ] || continue
		local name
		name="$(basename "$task_dir")"

		# Filter to single task if specified
		if [ -n "$single_task" ] && [ "$name" != "$single_task" ]; then
			continue
		fi

		_benchmark_run_task "$task_dir" "$profile"
		task_count=$((task_count + 1))

		# Check if passed from the result file
		local latest
		latest="$(ls -t "$REPO_DIR/_metrics/benchmarks/$profile/$name/"*.json 2>/dev/null | head -1)"
		if [ -n "$latest" ]; then
			local did_pass
			did_pass="$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get('passed', False))
except Exception:
    print('False')
" "$latest")"
			[ "$did_pass" = "True" ] && pass_count=$((pass_count + 1))
		fi
	done

	if [ -n "$single_task" ] && [ "$task_count" -eq 0 ]; then
		echo "Task '$single_task' not found in benchmarks/tasks/"
		return 1
	fi

	echo ""
	printf '─%.0s' {1..60}; echo ""
	echo "  Results: $pass_count/$task_count passed"
	echo ""

	# Regression detection
	_benchmark_check_regressions "$profile"
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n setup.sh
```

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "Add benchmark runner with task execution and metric capture"
```

---

### Task 7: Add regression detection, report mode, and profile table integration

**Files:**
- Modify: `setup.sh` — add `_benchmark_check_regressions`, `_benchmark_report`, update `_profile_table()`, `usage()`, dispatch

- [ ] **Step 1: Add `_benchmark_check_regressions` function**

Insert right after `cmd_benchmark`:

```bash
# Check for regressions in benchmark results for a profile.
_benchmark_check_regressions() {
	local profile="$1"
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks/$profile"
	[ -d "$benchmarks_dir" ] || return 0

	python3 - "$benchmarks_dir" <<'PYEOF'
import json, os, sys

try:
    benchmarks_dir = sys.argv[1]

    for task_name in sorted(os.listdir(benchmarks_dir)):
        task_dir = os.path.join(benchmarks_dir, task_name)
        if not os.path.isdir(task_dir):
            continue

        results = []
        for fname in sorted(os.listdir(task_dir)):
            if not fname.endswith('.json'):
                continue
            try:
                with open(os.path.join(task_dir, fname)) as f:
                    results.append(json.load(f))
            except (json.JSONDecodeError, OSError):
                continue

        if len(results) < 2:
            continue

        latest = results[-1]
        previous = results[:-1]

        # Check pass -> fail regression
        prev_passed = any(r.get('passed', False) for r in previous)
        if prev_passed and not latest.get('passed', False):
            print(f'  ⚠ Regression: "{task_name}" — was passing, now failing')

        # Check cost increase >10%
        prev_costs = [r.get('cost_usd', 0) for r in previous if r.get('cost_usd', 0) > 0]
        if prev_costs and latest.get('cost_usd', 0) > 0:
            avg_cost = sum(prev_costs) / len(prev_costs)
            curr_cost = latest['cost_usd']
            if avg_cost > 0 and (curr_cost - avg_cost) / avg_cost > 0.10:
                pct = ((curr_cost - avg_cost) / avg_cost) * 100
                print(f'  ⚠ Cost increase: "{task_name}" — avg ${avg_cost:.2f} → ${curr_cost:.2f} (+{pct:.0f}%)')

except Exception:
    pass
PYEOF
}
```

- [ ] **Step 2: Add `_benchmark_report` function**

Insert after `_benchmark_check_regressions`:

```bash
# Show benchmark results across all profiles (read-only, no execution).
_benchmark_report() {
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks"
	if [ ! -d "$benchmarks_dir" ]; then
		echo "No benchmark data in _metrics/benchmarks/"
		echo "Run './setup.sh benchmark' to generate results."
		return 0
	fi

	python3 - "$benchmarks_dir" "$REPO_DIR/benchmarks/tasks" <<'PYEOF'
import json, os, sys

try:
    benchmarks_dir = sys.argv[1]
    tasks_dir = sys.argv[2]

    # Discover all task names
    task_names = sorted([
        d for d in os.listdir(tasks_dir)
        if os.path.isfile(os.path.join(tasks_dir, d, 'task.json'))
    ]) if os.path.isdir(tasks_dir) else []

    # Discover all profiles with results
    profiles = sorted([
        d for d in os.listdir(benchmarks_dir)
        if os.path.isdir(os.path.join(benchmarks_dir, d))
    ])

    if not profiles:
        print('No benchmark results found.')
        sys.exit(0)

    def get_latest(profile, task):
        task_dir = os.path.join(benchmarks_dir, profile, task)
        if not os.path.isdir(task_dir):
            return None
        files = sorted([f for f in os.listdir(task_dir) if f.endswith('.json')])
        if not files:
            return None
        try:
            with open(os.path.join(task_dir, files[-1])) as f:
                return json.load(f)
        except Exception:
            return None

    def get_run_count(profile, task):
        task_dir = os.path.join(benchmarks_dir, profile, task)
        if not os.path.isdir(task_dir):
            return 0
        return len([f for f in os.listdir(task_dir) if f.endswith('.json')])

    # Header
    print()
    print('Benchmark Results')
    print('═' * 78)
    print()

    # Column widths
    task_w = max(len(t) for t in task_names) if task_names else 20
    task_w = max(task_w, 20)
    col_w = max(max(len(p) for p in profiles), 12)

    # Header row
    header = f'  {"Task":<{task_w}}'
    for p in profiles:
        header += f'  {p:>{col_w}}'
    print(header)
    print('  ' + '─' * (task_w + (col_w + 2) * len(profiles)))

    # Data rows
    totals = {p: {'passed': 0, 'total': 0, 'cost': 0.0} for p in profiles}

    for task in task_names:
        row = f'  {task:<{task_w}}'
        for p in profiles:
            r = get_latest(p, task)
            runs = get_run_count(p, task)
            if r is None:
                row += f'  {"—":>{col_w}}'
            else:
                passed = r.get('passed', False)
                cost = r.get('cost_usd', 0)
                mark = '✓' if passed else '✗'
                cell = f'{mark} ${cost:.2f}'
                if runs > 1:
                    cell += f' ({runs})'
                row += f'  {cell:>{col_w}}'
                totals[p]['total'] += 1
                if passed:
                    totals[p]['passed'] += 1
                totals[p]['cost'] += cost
        print(row)

    # Summary row
    print()
    score_row = f'  {"Score":<{task_w}}'
    cost_row = f'  {"Avg cost":<{task_w}}'
    for p in profiles:
        t = totals[p]
        if t['total'] > 0:
            pct = t['passed'] * 100 // t['total']
            score_row += f'  {f"{t["passed"]}/{t["total"]} ({pct}%)":>{col_w}}'
            avg = t['cost'] / t['total']
            cost_row += f'  {f"${avg:.2f}":>{col_w}}'
        else:
            score_row += f'  {"—":>{col_w}}'
            cost_row += f'  {"—":>{col_w}}'
    print(score_row)
    print(cost_row)
    print()

except Exception as e:
    print(f'Report failed: {e}')
PYEOF
}
```

- [ ] **Step 3: Add benchmark results to `_profile_table()`**

In `_profile_table()`, after the session averages section and before the final `echo ""`, add:

```bash
	# Benchmark results (if data exists)
	local benchmarks_dir="$REPO_DIR/_metrics/benchmarks"
	if [ -d "$benchmarks_dir" ]; then
		local has_data
		has_data="$(find "$benchmarks_dir" -name '*.json' -print -quit 2>/dev/null)"
		if [ -n "$has_data" ]; then
			echo ""
			_benchmark_report
		fi
	fi
```

- [ ] **Step 4: Add to usage text**

In `usage()`, after the Metrics section and before Setup, add:

```
Benchmarking:
  benchmark                        Run all benchmark tasks against current profile
  benchmark --task <name>          Run a specific benchmark task
  benchmark --report               Show benchmark results across profiles
```

- [ ] **Step 5: Add to dispatch**

In the `case` dispatch block, add before the `*)` catch-all:

```bash
benchmark)    shift; cmd_benchmark "$@" ;;
```

- [ ] **Step 6: Verify syntax**

```bash
bash -n setup.sh
```

- [ ] **Step 7: Test report with no data**

```bash
./setup.sh benchmark --report
```
Expected: "No benchmark data" message.

- [ ] **Step 8: Test usage text**

```bash
./setup.sh 2>&1 | grep -A3 "Benchmarking:"
```
Expected: Shows benchmark commands.

- [ ] **Step 9: Commit**

```bash
git add setup.sh
git commit -m "Add benchmark report, regression detection, and profile table integration"
```

---

## Chunk 3: Run Benchmarks

### Task 8: Run hello-world benchmark on main

This validates the full pipeline end-to-end before running all 5 tasks.

- [ ] **Step 1: Run single task**

```bash
./setup.sh benchmark --task hello-world
```
Expected: "PASS" with a result file in `_metrics/benchmarks/main/hello-world/`.

- [ ] **Step 2: Verify result file**

```bash
cat _metrics/benchmarks/main/hello-world/*.json | python3 -m json.tool
```
Expected: Valid JSON with passed=true, cost, duration, tokens.

- [ ] **Step 3: Verify report works**

```bash
./setup.sh benchmark --report
```
Expected: Table showing hello-world result for main.

---

### Task 9: Run all benchmarks on main, then propagate and run on other profiles

- [ ] **Step 1: Run all benchmarks on main**

```bash
./setup.sh benchmark
```
Expected: All 5 tasks run, results displayed.

- [ ] **Step 2: Verify report**

```bash
./setup.sh benchmark --report
```
Expected: Table with all 5 tasks for main profile.

- [ ] **Step 3: Propagate setup.sh and benchmarks/tasks/ to other branches**

```bash
mkdir -p .worktrees
git worktree add .worktrees/blank blank
git worktree add .worktrees/opinionated opinionated
```

For each branch, copy setup.sh and benchmark tasks:

```bash
for wt in blank opinionated; do
    cp setup.sh ".worktrees/$wt/setup.sh"
    cp -r benchmarks/tasks ".worktrees/$wt/benchmarks/tasks"
    cd ".worktrees/$wt"
    git add setup.sh benchmarks/tasks/
    git commit -m "Propagate Phase 3 benchmark system from main"
    cd "$REPO_DIR"
done
```

- [ ] **Step 4: Run benchmarks on blank profile**

```bash
cd .worktrees/blank
./setup.sh benchmark
cd "$REPO_DIR"
```

Note: Results write to `_metrics/benchmarks/blank/` (shared gitignored dir).

- [ ] **Step 5: Run benchmarks on opinionated profile**

```bash
cd .worktrees/opinionated
./setup.sh benchmark
cd "$REPO_DIR"
```

- [ ] **Step 6: View cross-profile report**

```bash
./setup.sh benchmark --report
```
Expected: Table with results for all 3 profiles.

- [ ] **Step 7: Clean up worktrees**

```bash
git worktree remove .worktrees/blank
git worktree remove .worktrees/opinionated
git worktree prune
```

- [ ] **Step 8: Final profile table**

```bash
./setup.sh profile
```
Expected: Full profile comparison with session averages AND benchmark results.

---

## Summary of Changes

| What | Where | Lines (est.) |
|------|-------|-------------|
| 5 benchmark task dirs | `benchmarks/tasks/` | ~30 files |
| `_benchmark_run_task()` | setup.sh | ~120 |
| `cmd_benchmark()` | setup.sh | ~70 |
| `_benchmark_check_regressions()` | setup.sh | ~40 |
| `_benchmark_report()` | setup.sh | ~100 |
| Profile table integration | `_profile_table()` in setup.sh | ~10 |
| Usage text + dispatch | setup.sh | ~5 |
| **Total** | | **~345 lines in setup.sh + task files** |
