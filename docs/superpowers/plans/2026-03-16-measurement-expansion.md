# Measurement Expansion Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 new code analyzers, improve the LLM judge rubric, create a minimalism profile variant, and wire everything into the benchmark pipeline.

**Architecture:** Each analyzer is an independent Python script following the existing pattern (read dir, print KEY:VALUE, exit 0). The LLM judge gets an improved rubric with anchored examples. Pipeline integration extends `setup.sh`'s positional arg passing. A minimalism experiment variant provides the "anti-limits" profile for comparison.

**Tech Stack:** Python 3 (AST module), bash (setup.sh pipeline), claude CLI (subscription judge)

**Spec:** `docs/superpowers/specs/2026-03-16-measurement-expansion-design.md`

**Branch:** Execute all tasks on the `main` branch. If `benchmarks/analyzers/test_analyzers.py` does not exist on the working branch, bootstrap it first: `git show main:benchmarks/analyzers/test_analyzers.py > benchmarks/analyzers/test_analyzers.py`

---

## Chunk 1: New Analyzers (Tasks 1-4)

These 4 tasks are fully independent — each creates a new Python file in `benchmarks/analyzers/` and adds tests. They can be executed in parallel.

### Task 1: Function Count Analyzer

**Files:**
- Create: `benchmarks/analyzers/function_count.py`
- Modify: `benchmarks/analyzers/test_analyzers.py`

- [ ] **Step 1: Write the analyzer**

Create `benchmarks/analyzers/function_count.py`:

```python
#!/usr/bin/env python3
"""Count functions in generated code to measure decomposition.

Usage: python3 function_count.py <dir>
Output: FUNCTION_COUNT:<total int>
        FUNCTION_COUNT_AVG_PER_FILE:<float>
Always exits 0.
"""
import ast
import os
import re
import sys


JS_FUNCTION_RE = re.compile(r'(?:function\s+\w+|=>\s*\{)')


def count_python_functions(filepath):
	"""Count functions in a Python file via AST."""
	try:
		with open(filepath) as f:
			tree = ast.parse(f.read())
	except (SyntaxError, OSError):
		return 0
	count = 0
	for node in ast.walk(tree):
		if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
			count += 1
	return count


def count_js_functions(filepath):
	"""Count functions in a JS/TS file via regex. Best-effort."""
	try:
		with open(filepath, errors='replace') as f:
			content = f.read()
	except OSError:
		return 0
	return len(JS_FUNCTION_RE.findall(content))


try:
	target_dir = sys.argv[1]
	total_functions = 0
	file_count = 0

	py_extensions = {'.py'}
	js_extensions = {'.js', '.jsx', '.ts', '.tsx'}

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			_, ext = os.path.splitext(fname)

			if ext in py_extensions:
				total_functions += count_python_functions(filepath)
				file_count += 1
			elif ext in js_extensions:
				total_functions += count_js_functions(filepath)
				file_count += 1

	avg = round(total_functions / file_count, 2) if file_count > 0 else 0.0

	print(f"FUNCTION_COUNT:{total_functions}")
	print(f"FUNCTION_COUNT_AVG_PER_FILE:{avg}")
except Exception:
	print("FUNCTION_COUNT:0")
	print("FUNCTION_COUNT_AVG_PER_FILE:0.0")

sys.exit(0)
```

- [ ] **Step 2: Add tests for function_count.py**

Append to `benchmarks/analyzers/test_analyzers.py` (before the summary block):

```python
# --- function_count.py ---
print("\n=== function_count.py ===")
metrics = parse_metrics(run_analyzer('function_count.py', SAMPLE_CODE))
check('outputs FUNCTION_COUNT', 'FUNCTION_COUNT' in metrics)
check('outputs FUNCTION_COUNT_AVG_PER_FILE', 'FUNCTION_COUNT_AVG_PER_FILE' in metrics)
check('counts 7 functions in sample', metrics.get('FUNCTION_COUNT') == 7,
      f"got {metrics.get('FUNCTION_COUNT')}")
check('avg is 7.0 (one file)', metrics.get('FUNCTION_COUNT_AVG_PER_FILE') == 7.0,
      f"got {metrics.get('FUNCTION_COUNT_AVG_PER_FILE')}")
```

Note: SAMPLE_CODE has 7 functions: `__init__`, `roll`, `score`, `_is_strike`, `_is_spare`, `_strike_bonus`, `_spare_bonus`.

- [ ] **Step 3: Run tests to verify**

Run: `python3 benchmarks/analyzers/test_analyzers.py`
Expected: All checks pass including the new function_count checks.

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/function_count.py benchmarks/analyzers/test_analyzers.py
git commit -m "Add function count analyzer for decomposition measurement"
```

---

### Task 2: Type Annotation Coverage Analyzer

**Files:**
- Create: `benchmarks/analyzers/type_annotation_coverage.py`
- Modify: `benchmarks/analyzers/test_analyzers.py`

- [ ] **Step 1: Write the analyzer**

Create `benchmarks/analyzers/type_annotation_coverage.py`:

```python
#!/usr/bin/env python3
"""Measure type annotation coverage for Python functions.

Usage: python3 type_annotation_coverage.py <dir>
Output: TYPE_ANNOTATION_COVERAGE:<0-100>
        TYPE_ANNOTATIONS_MISSING:<count>
Always exits 0.
"""
import ast
import os
import sys


def check_function_annotations(node):
	"""Check if a function has full type annotations.

	Returns (is_fully_annotated, missing_count).
	"""
	missing = 0

	if node.returns is None:
		missing += 1

	for arg in node.args.args:
		if arg.arg in ('self', 'cls'):
			continue
		if arg.annotation is None:
			missing += 1

	return missing == 0, missing


try:
	target_dir = sys.argv[1]
	total_functions = 0
	annotated_functions = 0
	total_missing = 0

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					tree = ast.parse(f.read())
			except (SyntaxError, OSError):
				continue

			for node in ast.walk(tree):
				if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
					total_functions += 1
					is_annotated, missing = check_function_annotations(node)
					if is_annotated:
						annotated_functions += 1
					total_missing += missing

	if total_functions > 0:
		coverage = round(annotated_functions / total_functions * 100)
	else:
		coverage = 100

	print(f"TYPE_ANNOTATION_COVERAGE:{coverage}")
	print(f"TYPE_ANNOTATIONS_MISSING:{total_missing}")
except Exception:
	print("TYPE_ANNOTATION_COVERAGE:0")
	print("TYPE_ANNOTATIONS_MISSING:0")

sys.exit(0)
```

- [ ] **Step 2: Add tests for type_annotation_coverage.py**

Append to `benchmarks/analyzers/test_analyzers.py` (before the summary block):

```python
# --- type_annotation_coverage.py ---
print("\n=== type_annotation_coverage.py ===")
metrics = parse_metrics(run_analyzer('type_annotation_coverage.py', SAMPLE_CODE))
check('outputs TYPE_ANNOTATION_COVERAGE', 'TYPE_ANNOTATION_COVERAGE' in metrics)
check('outputs TYPE_ANNOTATIONS_MISSING', 'TYPE_ANNOTATIONS_MISSING' in metrics)
check('coverage is 0 (no annotations in sample)', metrics.get('TYPE_ANNOTATION_COVERAGE') == 0,
      f"got {metrics.get('TYPE_ANNOTATION_COVERAGE')}")
check('missing count > 0', metrics.get('TYPE_ANNOTATIONS_MISSING', 0) > 0,
      f"got {metrics.get('TYPE_ANNOTATIONS_MISSING')}")
```

Note: SAMPLE_CODE has zero type annotations, so coverage should be 0%.

- [ ] **Step 3: Run tests to verify**

Run: `python3 benchmarks/analyzers/test_analyzers.py`
Expected: All checks pass.

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/type_annotation_coverage.py benchmarks/analyzers/test_analyzers.py
git commit -m "Add type annotation coverage analyzer"
```

---

### Task 3: Docstring Coverage Analyzer

**Files:**
- Create: `benchmarks/analyzers/docstring_coverage.py`
- Modify: `benchmarks/analyzers/test_analyzers.py`

- [ ] **Step 1: Write the analyzer**

Create `benchmarks/analyzers/docstring_coverage.py`:

```python
#!/usr/bin/env python3
"""Measure docstring coverage for Python functions and classes.

Usage: python3 docstring_coverage.py <dir>
Output: DOCSTRING_COVERAGE:<0-100>
        DOCSTRINGS_MISSING:<count>
Always exits 0.
"""
import ast
import os
import sys


DOCSTRING_NODES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)


try:
	target_dir = sys.argv[1]
	total_nodes = 0
	documented_nodes = 0

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					tree = ast.parse(f.read())
			except (SyntaxError, OSError):
				continue

			for node in ast.walk(tree):
				if isinstance(node, DOCSTRING_NODES):
					total_nodes += 1
					if ast.get_docstring(node) is not None:
						documented_nodes += 1

	if total_nodes > 0:
		coverage = round(documented_nodes / total_nodes * 100)
		missing = total_nodes - documented_nodes
	else:
		coverage = 100
		missing = 0

	print(f"DOCSTRING_COVERAGE:{coverage}")
	print(f"DOCSTRINGS_MISSING:{missing}")
except Exception:
	print("DOCSTRING_COVERAGE:100")
	print("DOCSTRINGS_MISSING:0")

sys.exit(0)
```

- [ ] **Step 2: Add tests for docstring_coverage.py**

Append to `benchmarks/analyzers/test_analyzers.py` (before the summary block):

```python
# --- docstring_coverage.py ---
print("\n=== docstring_coverage.py ===")
metrics = parse_metrics(run_analyzer('docstring_coverage.py', SAMPLE_CODE))
check('outputs DOCSTRING_COVERAGE', 'DOCSTRING_COVERAGE' in metrics)
check('outputs DOCSTRINGS_MISSING', 'DOCSTRINGS_MISSING' in metrics)
# SAMPLE_CODE: class BowlingGame has docstring, __init__ no, roll yes, score yes,
# _is_strike no, _is_spare no, _strike_bonus no, _spare_bonus no = 3/8 = 38%
check('coverage is 38 (3 of 8 have docstrings)', metrics.get('DOCSTRING_COVERAGE') == 38,
      f"got {metrics.get('DOCSTRING_COVERAGE')}")
check('missing is 5', metrics.get('DOCSTRINGS_MISSING') == 5,
      f"got {metrics.get('DOCSTRINGS_MISSING')}")
```

Note: SAMPLE_CODE has 8 nodes (1 class + 7 functions). Docstrings on: BowlingGame, roll, score = 3. Missing = 5.

- [ ] **Step 3: Run tests to verify**

Run: `python3 benchmarks/analyzers/test_analyzers.py`
Expected: All checks pass.

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/docstring_coverage.py benchmarks/analyzers/test_analyzers.py
git commit -m "Add docstring coverage analyzer"
```

---

### Task 4: Error Handling Density Analyzer

**Files:**
- Create: `benchmarks/analyzers/error_handling_density.py`
- Modify: `benchmarks/analyzers/test_analyzers.py`

- [ ] **Step 1: Write the analyzer**

Create `benchmarks/analyzers/error_handling_density.py`:

```python
#!/usr/bin/env python3
"""Measure error handling patterns in Python code.

Usage: python3 error_handling_density.py <dir>
Output: ERROR_HANDLING_TRY_COUNT:<int>
        ERROR_HANDLING_RAISE_COUNT:<int>
        ERROR_HANDLING_GUARD_CLAUSES:<int>
        ERROR_HANDLING_DENSITY:<float>
Always exits 0.
"""
import ast
import os
import sys


def count_guard_clauses(func_node):
	"""Count guard clauses in a function.

	A guard clause is an ast.If in the first 3 statements of
	a function body that contains a Return or Raise in its
	if-body (not in orelse).
	"""
	count = 0
	body = func_node.body
	check_limit = min(3, len(body))

	for stmt in body[:check_limit]:
		if not isinstance(stmt, ast.If):
			continue
		# Walk only the if-body (stmt.body), not stmt.orelse
		for node in ast.walk(ast.Module(body=stmt.body, type_ignores=[])):
			if isinstance(node, (ast.Return, ast.Raise)):
				count += 1
				break

	return count


def count_lines(filepath):
	"""Count non-blank, non-comment lines."""
	count = 0
	try:
		with open(filepath, errors='replace') as f:
			for line in f:
				stripped = line.strip()
				if stripped and not stripped.startswith('#'):
					count += 1
	except OSError:
		pass
	return count


try:
	target_dir = sys.argv[1]
	try_count = 0
	raise_count = 0
	guard_count = 0
	total_loc = 0

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					tree = ast.parse(f.read())
			except (SyntaxError, OSError):
				continue

			total_loc += count_lines(filepath)

			for node in ast.walk(tree):
				if isinstance(node, ast.Try):
					try_count += 1
				elif isinstance(node, ast.Raise):
					raise_count += 1
				elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
					guard_count += count_guard_clauses(node)

	total_handlers = try_count + raise_count + guard_count
	density = round(total_handlers / total_loc * 100, 2) if total_loc > 0 else 0.0

	print(f"ERROR_HANDLING_TRY_COUNT:{try_count}")
	print(f"ERROR_HANDLING_RAISE_COUNT:{raise_count}")
	print(f"ERROR_HANDLING_GUARD_CLAUSES:{guard_count}")
	print(f"ERROR_HANDLING_DENSITY:{density}")
except Exception:
	print("ERROR_HANDLING_TRY_COUNT:0")
	print("ERROR_HANDLING_RAISE_COUNT:0")
	print("ERROR_HANDLING_GUARD_CLAUSES:0")
	print("ERROR_HANDLING_DENSITY:0.0")

sys.exit(0)
```

- [ ] **Step 2: Add tests for error_handling_density.py**

Append to `benchmarks/analyzers/test_analyzers.py` (before the summary block):

```python
# --- error_handling_density.py ---
print("\n=== error_handling_density.py ===")
metrics = parse_metrics(run_analyzer('error_handling_density.py', SAMPLE_CODE))
check('outputs ERROR_HANDLING_TRY_COUNT', 'ERROR_HANDLING_TRY_COUNT' in metrics)
check('outputs ERROR_HANDLING_RAISE_COUNT', 'ERROR_HANDLING_RAISE_COUNT' in metrics)
check('outputs ERROR_HANDLING_GUARD_CLAUSES', 'ERROR_HANDLING_GUARD_CLAUSES' in metrics)
check('outputs ERROR_HANDLING_DENSITY', 'ERROR_HANDLING_DENSITY' in metrics)
# SAMPLE_CODE: 0 try blocks, 1 raise (in roll), 1 guard clause (if not isinstance... raise)
check('try count is 0', metrics.get('ERROR_HANDLING_TRY_COUNT') == 0,
      f"got {metrics.get('ERROR_HANDLING_TRY_COUNT')}")
check('raise count is 1', metrics.get('ERROR_HANDLING_RAISE_COUNT') == 1,
      f"got {metrics.get('ERROR_HANDLING_RAISE_COUNT')}")
check('guard clauses is 1', metrics.get('ERROR_HANDLING_GUARD_CLAUSES') == 1,
      f"got {metrics.get('ERROR_HANDLING_GUARD_CLAUSES')}")
check('density > 0', metrics.get('ERROR_HANDLING_DENSITY', 0) > 0,
      f"got {metrics.get('ERROR_HANDLING_DENSITY')}")
```

Note: SAMPLE_CODE has 1 raise in `roll()` and 1 guard clause (`if not isinstance(pins, int) or pins < 0: raise`).

- [ ] **Step 3: Run tests to verify**

Run: `python3 benchmarks/analyzers/test_analyzers.py`
Expected: All checks pass.

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/error_handling_density.py benchmarks/analyzers/test_analyzers.py
git commit -m "Add error handling density analyzer"
```

---

## Chunk 2: LLM Judge Improvements (Task 5)

### Task 5: Improve LLM Judge Rubric and Add Task Context

**Files:**
- Modify: `benchmarks/analyzers/llm_judge.py`

- [ ] **Step 1: Replace the RUBRIC constant with anchored version**

In `benchmarks/analyzers/llm_judge.py`, replace the `RUBRIC` string (lines 21-33) with:

```python
RUBRIC = """Rate this code on 5 dimensions, each scored 1-10.
Use the anchored examples to calibrate your scores.

1. READABILITY: Is the code easy to understand?
   3 = Dense logic, unclear variable flow, no whitespace grouping
   5 = Functional but takes effort to follow
   7 = Clear flow, good whitespace, could improve naming in spots
   9 = Immediately understandable, self-documenting structure

2. NAMING: Are names descriptive and consistent?
   3 = Generic names (data, result, temp), inconsistent conventions
   5 = Adequate names, mostly consistent
   7 = Descriptive names, consistent conventions, minor abbreviations
   9 = Every name reveals intent, perfect convention adherence

3. ERROR_HANDLING: Does the code handle edge cases and errors?
   3 = No edge case handling, bare except blocks, silent failures
   5 = Some handling, but gaps in coverage
   7 = Key edge cases handled, specific exceptions, some gaps
   9 = All edge cases handled, custom exceptions where appropriate

4. IDIOMATIC: Does the code follow language idioms and best practices?
   3 = Transliterated from another language, ignores standard library
   5 = Basic usage, misses some language features
   7 = Uses language features correctly, follows most conventions
   9 = Expert-level idioms, leverages stdlib perfectly, zero anti-patterns

5. ABSTRACTION: Is the level of abstraction appropriate for the problem?
   3 = God function or premature abstraction, wrong level of granularity
   5 = Works but decomposition could be better
   7 = Reasonable decomposition, could be slightly better
   9 = Perfect granularity for the problem, each unit has one clear purpose

Respond ONLY with a JSON object, no other text:
{"readability": N, "naming": N, "error_handling": N, "idiomatic": N, "abstraction": N}
"""
```

- [ ] **Step 2: Add task context support**

Update the `llm_judge.py` to accept `sys.argv[3]` as the task directory path and read `prompt.md` for context. Replace lines 59-73 (the try block start through prompt construction) with:

```python
try:
	workdir = sys.argv[1]
	task_name = sys.argv[2] if len(sys.argv) > 2 else "unknown"
	task_dir = sys.argv[3] if len(sys.argv) > 3 else None

	# Read task prompt for context
	task_context = ""
	if task_dir:
		prompt_path = os.path.join(task_dir, "prompt.md")
		if os.path.exists(prompt_path):
			with open(prompt_path) as f:
				task_context = f"Task: {task_name}\nPrompt: {f.read().strip()}\n\n"

	code = collect_code(workdir)
	if not code.strip():
		print("JUDGE_SCORE:50")
		print("JUDGE_READABILITY:5")
		print("JUDGE_NAMING:5")
		print("JUDGE_ERROR_HANDLING:5")
		print("JUDGE_IDIOMATIC:5")
		print("JUDGE_ABSTRACTION:5")
		sys.exit(0)

	prompt = task_context + RUBRIC + code
```

- [ ] **Step 3: Fix `collect_code` to use `os.walk` for recursive traversal**

Replace the `collect_code` function (lines 37-56) with:

```python
def collect_code(workdir):
	"""Collect all generated code files into a single string."""
	code_parts = []
	for root, dirs, files in os.walk(workdir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in sorted(files):
			if fname.startswith(('.', '_')):
				continue
			_, ext = os.path.splitext(fname)
			if ext not in ('.py', '.js', '.jsx', '.ts', '.tsx', '.md'):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					content = f.read()
				if content.strip():
					rel_path = os.path.relpath(filepath, workdir)
					code_parts.append(f"--- {rel_path} ---\n{content}")
			except OSError:
				pass
	return "\n\n".join(code_parts)
```

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/llm_judge.py
git commit -m "Improve LLM judge with anchored rubric and task context"
```

---

## Chunk 3: Minimalism Profile (Task 6)

### Task 6: Create Minimalism Profile Variant

**Files:**
- Create: `_experiment/claude-md-minimalism.md`
- Modify: `run-isolation-experiment.sh`

- [ ] **Step 1: Get the blank machine environment section**

Read the blank profile's CLAUDE.md to get the machine environment section:

```bash
git show blank:claude/CLAUDE.md
```

- [ ] **Step 2: Create the minimalism variant**

Create `_experiment/claude-md-minimalism.md` with the blank machine environment header followed by:

```markdown
## Code Standards — Hard Limits

- Maximum 3 functions per file. Inline helper logic rather than extracting.
- No function may exist solely to be called once. If it's called once, inline it.
- No function length limit. A single function may be as long as needed.
- Solve problems in the fewest lines possible. Conciseness is correctness.
- No wrapper functions, no adapter patterns, no unnecessary abstractions.
- No docstrings unless the function signature is genuinely ambiguous.
```

- [ ] **Step 3: Update the experiment runner**

In `run-isolation-experiment.sh`, change the `VARIANTS` array from:

```bash
VARIANTS=(limits-amplified)
```

to:

```bash
VARIANTS=(limits-amplified minimalism)
```

Update the header comments to reflect the new count:

```bash
echo "║  Limits-Amplified + Minimalism Experiment             ║"
echo "║  2 profiles × 9 tasks × 3 reps = 54 runs             ║"
```

- [ ] **Step 4: Commit**

```bash
git add _experiment/claude-md-minimalism.md run-isolation-experiment.sh
git commit -m "Add minimalism profile variant for anti-limits experiment"
```

---

## Chunk 4: Pipeline Integration (Task 7)

This task depends on Tasks 1-4 being complete — the analyzer files must exist before wiring them in.

### Task 7: Wire New Analyzers into setup.sh Pipeline

**Files:**
- Modify: `setup.sh`

**Important:** Read `setup.sh` fresh before editing. The line numbers below are approximate — use the actual content for edits.

- [ ] **Step 1: Add analyzer invocations in the Tier 3 block**

Find the line `# Personality compliance` (approx line 1342) and add after the personality_compliance invocation (before the regression check):

```bash
		# Function count
		analyzer_output+="$(python3 "$analyzers_dir/function_count.py" "$tmpdir" 2>/dev/null || true)"$'\n'
		# Type annotation coverage
		analyzer_output+="$(python3 "$analyzers_dir/type_annotation_coverage.py" "$tmpdir" 2>/dev/null || true)"$'\n'
		# Docstring coverage
		analyzer_output+="$(python3 "$analyzers_dir/docstring_coverage.py" "$tmpdir" 2>/dev/null || true)"$'\n'
		# Error handling density
		analyzer_output+="$(python3 "$analyzers_dir/error_handling_density.py" "$tmpdir" 2>/dev/null || true)"$'\n'
```

- [ ] **Step 2: Update the LLM judge invocation to pass task_dir**

Find the judge invocation line (approx line 1351):

```bash
			analyzer_output+="$(python3 "$analyzers_dir/llm_judge.py" "$tmpdir" "$task_name" 2>/dev/null || true)"$'\n'
```

Change to:

```bash
			analyzer_output+="$(python3 "$analyzers_dir/llm_judge.py" "$tmpdir" "$task_name" "$task_dir" 2>/dev/null || true)"$'\n'
```

- [ ] **Step 3: Add grep/extract lines for new metrics**

After the existing `personality_violations` extraction block (approx line 1469), add:

```bash
	local function_count
	function_count="$(echo "$verify_output" | grep -oE 'FUNCTION_COUNT:[0-9]+' | head -1 | cut -d: -f2 || true)"
	[ -z "$function_count" ] && function_count=0

	local function_count_avg
	function_count_avg="$(echo "$verify_output" | grep -oE 'FUNCTION_COUNT_AVG_PER_FILE:[0-9.]+' | cut -d: -f2 || true)"
	[ -z "$function_count_avg" ] && function_count_avg=0

	local type_annotation_coverage
	type_annotation_coverage="$(echo "$verify_output" | grep -oE 'TYPE_ANNOTATION_COVERAGE:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$type_annotation_coverage" ] && type_annotation_coverage=0

	local type_annotations_missing
	type_annotations_missing="$(echo "$verify_output" | grep -oE 'TYPE_ANNOTATIONS_MISSING:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$type_annotations_missing" ] && type_annotations_missing=0

	local docstring_coverage
	docstring_coverage="$(echo "$verify_output" | grep -oE 'DOCSTRING_COVERAGE:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$docstring_coverage" ] && docstring_coverage=0

	local docstrings_missing
	docstrings_missing="$(echo "$verify_output" | grep -oE 'DOCSTRINGS_MISSING:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$docstrings_missing" ] && docstrings_missing=0

	local error_handling_try_count
	error_handling_try_count="$(echo "$verify_output" | grep -oE 'ERROR_HANDLING_TRY_COUNT:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$error_handling_try_count" ] && error_handling_try_count=0

	local error_handling_raise_count
	error_handling_raise_count="$(echo "$verify_output" | grep -oE 'ERROR_HANDLING_RAISE_COUNT:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$error_handling_raise_count" ] && error_handling_raise_count=0

	local error_handling_guard_clauses
	error_handling_guard_clauses="$(echo "$verify_output" | grep -oE 'ERROR_HANDLING_GUARD_CLAUSES:[0-9]+' | cut -d: -f2 || true)"
	[ -z "$error_handling_guard_clauses" ] && error_handling_guard_clauses=0

	local error_handling_density
	error_handling_density="$(echo "$verify_output" | grep -oE 'ERROR_HANDLING_DENSITY:[0-9.]+' | cut -d: -f2 || true)"
	[ -z "$error_handling_density" ] && error_handling_density=0
```

- [ ] **Step 4: Add new args to the Python JSON writer invocation**

Find the `python3 -` invocation line (approx line 1477). Add the new variables after `"$personality_violations"`:

```bash
		"$function_count" "$function_count_avg" \
		"$type_annotation_coverage" "$type_annotations_missing" \
		"$docstring_coverage" "$docstrings_missing" \
		"$error_handling_try_count" "$error_handling_raise_count" \
		"$error_handling_guard_clauses" "$error_handling_density" <<'PYEOF'
```

- [ ] **Step 5: Add argument parsing in the inline Python**

After `personality_violations = int(sys.argv[33])` (approx line 1528), add:

```python
    function_count = int(sys.argv[34])
    function_count_avg = float(sys.argv[35])
    type_annotation_coverage = int(sys.argv[36])
    type_annotations_missing = int(sys.argv[37])
    docstring_coverage = int(sys.argv[38])
    docstrings_missing = int(sys.argv[39])
    error_handling_try_count = int(sys.argv[40])
    error_handling_raise_count = int(sys.argv[41])
    error_handling_guard_clauses = int(sys.argv[42])
    error_handling_density = float(sys.argv[43])
```

- [ ] **Step 6: Add fields to the result dict**

After `'personality_violations': personality_violations,` (approx line 1599), add:

```python
        'function_count': function_count,
        'function_count_avg_per_file': function_count_avg,
        'type_annotation_coverage': type_annotation_coverage,
        'type_annotations_missing': type_annotations_missing,
        'docstring_coverage': docstring_coverage,
        'docstrings_missing': docstrings_missing,
        'error_handling_try_count': error_handling_try_count,
        'error_handling_raise_count': error_handling_raise_count,
        'error_handling_guard_clauses': error_handling_guard_clauses,
        'error_handling_density': error_handling_density,
```

- [ ] **Step 7: Update the fallback block**

In the fallback `except` block (approx line 1608), add these fields to the fallback dict:

```python
            'function_count': 0,
            'function_count_avg_per_file': 0.0,
            'type_annotation_coverage': 0,
            'type_annotations_missing': 0,
            'docstring_coverage': 0,
            'docstrings_missing': 0,
            'error_handling_try_count': 0,
            'error_handling_raise_count': 0,
            'error_handling_guard_clauses': 0,
            'error_handling_density': 0.0,
```

- [ ] **Step 8: Run a quick sanity test**

```bash
./setup.sh benchmark --task hello-world
```

Check the output JSON in `_metrics/benchmarks/` to verify all new fields are present with non-error values.

- [ ] **Step 9: Commit**

```bash
git add setup.sh
git commit -m "Wire 4 new analyzers and judge task context into benchmark pipeline"
```

---

## Chunk 5: Validation (Task 8)

### Task 8: Validate Against Real Benchmark Data

This task runs from a **regular terminal**, not inside Claude Code. It produces the data needed for dashboard updates.

- [ ] **Step 1: Run a single-task smoke test with judge enabled**

From a regular terminal:

```bash
cd ~/git/claude_personalities
BENCHMARK_JUDGE=1 ./setup.sh benchmark --task he-000-has-close-elements
```

Verify the output JSON contains:
- All 4 new analyzer metrics with non-zero values
- Judge scores (non-zero if `BENCHMARK_JUDGE=1` worked)

- [ ] **Step 2: Inspect the result JSON**

```bash
cat _metrics/benchmarks/*/he-000-has-close-elements/*.json | python3 -m json.tool | grep -E 'function_count|type_annotation|docstring|error_handling|judge'
```

Verify all new fields are present and reasonable.

- [ ] **Step 3: Run the full validation suite**

From a regular terminal (this takes ~80 minutes):

```bash
# This runs all 4 profiles × 9 tasks × 3 reps = 108 runs
# with judge enabled for all
BENCHMARK_JUDGE=1 ./run-isolation-experiment.sh
```

Note: The experiment runner needs to be updated to run all 4 profiles (blank, opinionated, limits-amplified, minimalism), not just the variants. You may need to run blank and opinionated separately:

```bash
# Run blank and opinionated manually (the experiment runner only handles variants)
for task in he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash ex-react ce-003-statistics3 ex-linked-list ex-paasio; do
    for rep in 1 2 3; do
        git checkout blank
        BENCHMARK_JUDGE=1 ./setup.sh benchmark --task "$task"
        git checkout opinionated
        BENCHMARK_JUDGE=1 ./setup.sh benchmark --task "$task"
    done
done
git checkout main
```

- [ ] **Step 4: Aggregate and analyze results**

```bash
python3 benchmarks/aggregate-results.py _metrics/
```

Check that the new metrics appear in the aggregation output.

- [ ] **Step 5: Commit any fixes found during validation**

```bash
git add -A
git commit -m "Fix issues found during validation run"
```
