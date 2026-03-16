# Benchmark Task Expansion Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand benchmark suite from 5 hand-written tasks to 50+ by importing from HumanEval, MBPP, Aider Exercism, Aider Refactoring, and ClassEval via a converter script.

**Architecture:** A single Python script (`benchmarks/import-tasks.py`) reads source data formats (JSONL, per-directory) and generates our standard task directory structure (task.json, prompt.md, verify.sh, fixture/). Source data is downloaded to `benchmarks/sources/` (gitignored). Each importer is a function that reads its format, applies selection criteria, and calls a shared `create_task_dir()` helper.

**Tech Stack:** Python 3 stdlib only (json, argparse, gzip, os, stat, textwrap). No pip installs.

**Spec:** `.claude/context-benchmark-expansion.md`

---

## Chunk 1: Foundation + HumanEval Importer

### Task 1: Create import-tasks.py scaffold

**Files:**
- Create: `benchmarks/import-tasks.py`

- [ ] **Step 1: Write the CLI scaffold with shared helpers**

```python
#!/usr/bin/env python3
"""Import benchmark tasks from open-source LLM code benchmarks.

Usage:
    python3 benchmarks/import-tasks.py --source humaneval [--filter ID1,ID2] [--dry-run]
    python3 benchmarks/import-tasks.py --source mbpp [--filter ID1,ID2] [--dry-run]
    python3 benchmarks/import-tasks.py --source exercism [--filter name1,name2] [--dry-run]
    python3 benchmarks/import-tasks.py --source classeval [--filter ID1,ID2] [--dry-run]
    python3 benchmarks/import-tasks.py --source refactoring [--filter ID1,ID2] [--dry-run]
"""
import argparse
import gzip
import json
import os
import stat
import sys
import textwrap

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TASKS_DIR = os.path.join(SCRIPT_DIR, "tasks")
SOURCES_DIR = os.path.join(SCRIPT_DIR, "sources")


def create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files=None, dry_run=False):
    """Create a complete task directory.

    Args:
        name: Task directory name (e.g. "he-002-truncate-number")
        task_json: Dict for task.json
        prompt_md: String content for prompt.md
        verify_sh: String content for verify.sh
        fixture_files: Dict of {relative_path: content} for fixture/
        dry_run: If True, print what would be created but don't write
    """
    task_dir = os.path.join(TASKS_DIR, name)

    if dry_run:
        print(f"  [dry-run] Would create: {task_dir}/")
        print(f"    task.json: {task_json['category']}/{task_json['difficulty']}")
        if fixture_files:
            for path in fixture_files:
                print(f"    fixture/{path}")
        return

    os.makedirs(os.path.join(task_dir, "fixture"), exist_ok=True)

    # task.json
    with open(os.path.join(task_dir, "task.json"), "w") as f:
        json.dump(task_json, f, indent=2)
        f.write("\n")

    # prompt.md
    with open(os.path.join(task_dir, "prompt.md"), "w") as f:
        f.write(prompt_md)

    # verify.sh (must be executable)
    verify_path = os.path.join(task_dir, "verify.sh")
    with open(verify_path, "w") as f:
        f.write(verify_sh)
    os.chmod(verify_path, os.stat(verify_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    # fixture files
    if fixture_files:
        for rel_path, content in fixture_files.items():
            fpath = os.path.join(task_dir, "fixture", rel_path)
            os.makedirs(os.path.dirname(fpath), exist_ok=True)
            with open(fpath, "w") as f:
                f.write(content)

    print(f"  Created: {name}")


def estimate_complexity(solution_code):
    """Estimate expected_complexity from solution code."""
    lines = [l for l in solution_code.strip().split("\n") if l.strip()]
    num_lines = len(lines)

    # Count functions and classes
    num_functions = sum(1 for l in lines if l.strip().startswith("def "))
    num_classes = sum(1 for l in lines if l.strip().startswith("class "))

    return {
        "max_files": 2,
        "max_classes": max(num_classes, 1) if num_classes > 0 else 0,
        "max_functions": max(num_functions + 2, 5),
        "max_lines": max(num_lines * 3, 30),
        "disallow_patterns": []
    }


def difficulty_from_lines(num_lines):
    """Map solution line count to difficulty."""
    if num_lines <= 5:
        return "basic"
    elif num_lines <= 15:
        return "medium"
    else:
        return "advanced"


def main():
    parser = argparse.ArgumentParser(description="Import benchmark tasks from open-source suites")
    parser.add_argument("--source", required=True,
                        choices=["humaneval", "mbpp", "exercism", "classeval", "refactoring"],
                        help="Source benchmark to import from")
    parser.add_argument("--filter", default=None,
                        help="Comma-separated task IDs to import (default: auto-select)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview what would be created without writing")
    parser.add_argument("--max", type=int, default=None,
                        help="Maximum number of tasks to import")
    args = parser.parse_args()

    filter_ids = None
    if args.filter:
        filter_ids = [x.strip() for x in args.filter.split(",")]

    importers = {
        "humaneval": import_humaneval,
        "mbpp": import_mbpp,
        "exercism": import_exercism,
        "classeval": import_classeval,
        "refactoring": import_refactoring,
    }

    print(f"Importing from {args.source}...")
    count = importers[args.source](filter_ids=filter_ids, dry_run=args.dry_run, max_tasks=args.max)
    print(f"Done. {count} tasks {'would be' if args.dry_run else ''} imported.")


# === Importers (added in subsequent tasks) ===

def import_humaneval(filter_ids=None, dry_run=False, max_tasks=None):
    raise NotImplementedError("HumanEval importer not yet implemented")

def import_mbpp(filter_ids=None, dry_run=False, max_tasks=None):
    raise NotImplementedError("MBPP importer not yet implemented")

def import_exercism(filter_ids=None, dry_run=False, max_tasks=None):
    raise NotImplementedError("Exercism importer not yet implemented")

def import_classeval(filter_ids=None, dry_run=False, max_tasks=None):
    raise NotImplementedError("ClassEval importer not yet implemented")

def import_refactoring(filter_ids=None, dry_run=False, max_tasks=None):
    raise NotImplementedError("Refactoring importer not yet implemented")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Verify CLI parses correctly**

Run: `python3 benchmarks/import-tasks.py --help`
Expected: Usage message with --source, --filter, --dry-run, --max options

- [ ] **Step 3: Commit scaffold**

```bash
git add benchmarks/import-tasks.py
git commit -m "Add import-tasks.py scaffold with CLI and shared helpers"
```

---

### Task 2: Implement HumanEval importer

**Files:**
- Modify: `benchmarks/import-tasks.py` (replace `import_humaneval` stub)

**Depends on:** Task 1

- [ ] **Step 1: Download HumanEval data**

```bash
mkdir -p benchmarks/sources
curl -L https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz -o benchmarks/sources/HumanEval.jsonl.gz
gunzip -f benchmarks/sources/HumanEval.jsonl.gz
```

Verify: `wc -l benchmarks/sources/HumanEval.jsonl` → should be 164

- [ ] **Step 2: Inspect a few HumanEval entries to confirm format**

```bash
head -3 benchmarks/sources/HumanEval.jsonl | python3 -m json.tool
```

Confirm fields: `task_id`, `prompt`, `canonical_solution`, `entry_point`, `test`

- [ ] **Step 3: Replace import_humaneval with full implementation**

Replace the `import_humaneval` stub in `benchmarks/import-tasks.py` with:

```python
def import_humaneval(filter_ids=None, dry_run=False, max_tasks=None):
    """Import tasks from HumanEval JSONL.

    Selection criteria (when no filter): skip trivial problems (solution < 5 lines)
    and very complex ones (> 40 lines). Target medium-difficulty problems.
    """
    jsonl_path = os.path.join(SOURCES_DIR, "HumanEval.jsonl")
    if not os.path.exists(jsonl_path):
        # Try .gz
        gz_path = jsonl_path + ".gz"
        if os.path.exists(gz_path):
            print(f"  Decompressing {gz_path}...")
            import gzip as gz
            with gz.open(gz_path, "rb") as f_in:
                with open(jsonl_path, "wb") as f_out:
                    f_out.write(f_in.read())
        else:
            print(f"  ERROR: {jsonl_path} not found. Download with:")
            print(f"    curl -L https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz \\")
            print(f"      -o {gz_path} && gunzip {gz_path}")
            return 0

    # Load all entries
    entries = []
    with open(jsonl_path) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    # Filter or auto-select
    if filter_ids:
        selected = [e for e in entries if e["task_id"] in filter_ids
                    or e["task_id"].split("/")[-1] in filter_ids]
    else:
        # Auto-select: medium difficulty (5-40 solution lines, non-trivial logic)
        selected = []
        for e in entries:
            sol_lines = [l for l in e["canonical_solution"].strip().split("\n") if l.strip()]
            if 5 <= len(sol_lines) <= 40:
                selected.append(e)

    if max_tasks and len(selected) > max_tasks:
        selected = selected[:max_tasks]

    print(f"  Selected {len(selected)} of {len(entries)} HumanEval tasks")

    count = 0
    for entry in selected:
        task_id = entry["task_id"]  # e.g. "HumanEval/2"
        num = task_id.split("/")[-1]
        entry_point = entry["entry_point"]
        # Slugify: he-002-truncate-number
        slug = entry_point.replace("_", "-")
        name = f"he-{int(num):03d}-{slug}"

        # Check if already exists
        if os.path.exists(os.path.join(TASKS_DIR, name)) and not dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        prompt_text = entry["prompt"]  # function signature + docstring
        canonical = entry["canonical_solution"]
        test_code = entry["test"]

        sol_lines = [l for l in canonical.strip().split("\n") if l.strip()]
        difficulty = difficulty_from_lines(len(sol_lines))

        # task.json
        task_json = {
            "name": name,
            "description": f"HumanEval/{num}: Implement {entry_point}",
            "category": "function-completion",
            "capability": "python-coding",
            "difficulty": difficulty,
            "timeout": 120,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": estimate_complexity(canonical),
            "source": {
                "benchmark": "HumanEval",
                "task_id": task_id,
                "license": "MIT"
            }
        }

        # prompt.md — tell the agent to implement the function in solution.py
        prompt_md = textwrap.dedent(f"""\
            Complete the implementation of the function in `solution.py`.

            The file contains a function signature and docstring. Write the function body
            so that all tests in `test_solution.py` pass.

            Run tests with: `python3 test_solution.py`

            Do not modify `test_solution.py`. Only edit `solution.py`.
        """)

        # fixture/solution.py — stub with signature + docstring + pass
        # The HumanEval prompt is the function def up to the body
        stub = prompt_text.rstrip()
        if not stub.endswith(":"):
            stub += "\n    pass\n"
        else:
            stub += "\n    pass\n"

        # fixture/test_solution.py — runs the HumanEval test assertions
        test_file = textwrap.dedent(f"""\
            # Auto-generated test for {task_id}
            from solution import {entry_point}

            {test_code}
            check({entry_point})
            print("ALL_TESTS_PASSED")
        """)

        # verify.sh
        verify_sh = textwrap.dedent(f"""\
            #!/usr/bin/env bash
            set -euo pipefail
            dir="$1"
            scorer="$(dirname "$0")/../../score-metrics.py"

            cd "$dir"

            if [ ! -f "solution.py" ]; then
            \techo "FAIL: solution.py not found"
            \techo "SCORE:0"
            \texit 1
            fi

            output="$(python3 test_solution.py 2>&1)" || true
            echo "$output"

            # Run shared metrics
            python3 "$scorer" "$dir" '["solution.py", "test_solution.py"]' "python" 2>/dev/null || true

            if echo "$output" | grep -q "ALL_TESTS_PASSED"; then
            \techo "PASS"
            \techo "SCORE:100"
            \texit 0
            else
            \techo "FAIL"
            \techo "SCORE:0"
            \texit 1
            fi
        """)

        create_task_dir(
            name=name,
            task_json=task_json,
            prompt_md=prompt_md,
            verify_sh=verify_sh,
            fixture_files={
                "solution.py": stub,
                "test_solution.py": test_file,
            },
            dry_run=dry_run,
        )
        count += 1

    return count
```

- [ ] **Step 4: Test dry-run to see what would be imported**

Run: `python3 benchmarks/import-tasks.py --source humaneval --dry-run --max 25`
Expected: List of ~20-25 tasks that would be created

- [ ] **Step 5: Import HumanEval tasks for real**

Run: `python3 benchmarks/import-tasks.py --source humaneval --max 20`
Expected: 20 task directories created under `benchmarks/tasks/he-*`

- [ ] **Step 6: Validate 3 imported tasks by running their verify.sh**

Pick 3 tasks and test them by creating a solution from the canonical answer, then running verify.sh:

```bash
# For each of 3 tasks:
task="benchmarks/tasks/he-XXX-name"
tmpdir=$(mktemp -d)
cp -a "$task/fixture/." "$tmpdir/"
# Manually write the canonical solution into $tmpdir/solution.py
# (read it from HumanEval.jsonl)
bash "$task/verify.sh" "$tmpdir"
rm -rf "$tmpdir"
```

Expected: Each verify.sh exits 0 with SCORE:100

- [ ] **Step 7: Fix any issues found during validation**

Common issues to watch for:
- HumanEval `prompt` field may include imports (typing, etc.) — ensure they're in solution.py stub
- Some test code may have METADATA dict — ensure it doesn't interfere
- Tab/space mixing in verify.sh — use tabs consistently

- [ ] **Step 8: Commit HumanEval importer + imported tasks**

```bash
git add benchmarks/import-tasks.py benchmarks/tasks/he-*
git commit -m "Add HumanEval importer and import 20 medium-difficulty tasks"
```

---

## Chunk 2: MBPP Importer

### Task 3: Implement MBPP importer

**Files:**
- Modify: `benchmarks/import-tasks.py` (replace `import_mbpp` stub)

**Depends on:** Task 1

- [ ] **Step 1: Download MBPP data**

```bash
curl -L https://raw.githubusercontent.com/google-research/google-research/master/mbpp/mbpp.jsonl \
  -o benchmarks/sources/mbpp.jsonl
```

Verify: `wc -l benchmarks/sources/mbpp.jsonl` → should be ~974

- [ ] **Step 2: Inspect MBPP format**

```bash
head -3 benchmarks/sources/mbpp.jsonl | python3 -m json.tool
```

Confirm fields: `text`, `code`, `task_id`, `test_list`

- [ ] **Step 3: Replace import_mbpp with full implementation**

```python
def import_mbpp(filter_ids=None, dry_run=False, max_tasks=None):
    """Import tasks from MBPP JSONL.

    Selection criteria (when no filter): skip trivial (solution < 5 lines)
    and tasks in the first 10 (often used as few-shot examples).
    Prefer tasks with 3+ test assertions and non-trivial logic.
    """
    jsonl_path = os.path.join(SOURCES_DIR, "mbpp.jsonl")
    if not os.path.exists(jsonl_path):
        print(f"  ERROR: {jsonl_path} not found. Download with:")
        print(f"    curl -L https://raw.githubusercontent.com/google-research/google-research/"
              f"master/mbpp/mbpp.jsonl -o {jsonl_path}")
        return 0

    entries = []
    with open(jsonl_path) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    if filter_ids:
        filter_ints = []
        for fid in filter_ids:
            try:
                filter_ints.append(int(fid))
            except ValueError:
                filter_ints.append(fid)
        selected = [e for e in entries if e["task_id"] in filter_ints
                    or str(e["task_id"]) in filter_ids]
    else:
        # Auto-select: skip first 10 (few-shot examples), require 3+ tests,
        # solution 5-30 lines
        selected = []
        for e in entries:
            if e["task_id"] <= 10:
                continue
            sol_lines = [l for l in e["code"].strip().split("\n") if l.strip()]
            if len(sol_lines) < 5:
                continue
            if len(e.get("test_list", [])) < 3:
                continue
            selected.append(e)

    if max_tasks and len(selected) > max_tasks:
        selected = selected[:max_tasks]

    print(f"  Selected {len(selected)} of {len(entries)} MBPP tasks")

    count = 0
    for entry in selected:
        task_id = entry["task_id"]
        text = entry["text"]
        code = entry["code"]
        test_list = entry.get("test_list", [])

        # Extract function name from code
        func_name = None
        for line in code.split("\n"):
            stripped = line.strip()
            if stripped.startswith("def "):
                func_name = stripped.split("(")[0].replace("def ", "")
                break
        if not func_name:
            func_name = f"task_{task_id}"

        slug = func_name.replace("_", "-")
        name = f"mbpp-{task_id:03d}-{slug}"

        if os.path.exists(os.path.join(TASKS_DIR, name)) and not dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        sol_lines = [l for l in code.strip().split("\n") if l.strip()]
        difficulty = difficulty_from_lines(len(sol_lines))

        task_json = {
            "name": name,
            "description": f"MBPP/{task_id}: {text[:80]}",
            "category": "function-completion",
            "capability": "python-coding",
            "difficulty": difficulty,
            "timeout": 120,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": estimate_complexity(code),
            "source": {
                "benchmark": "MBPP",
                "task_id": task_id,
                "license": "CC-BY-4.0"
            }
        }

        prompt_md = textwrap.dedent(f"""\
            {text}

            Write your solution in `solution.py`. The function should be named `{func_name}`.

            Tests are in `test_solution.py`. Run with: `python3 test_solution.py`

            Do not modify `test_solution.py`.
        """)

        # Stub file — just the function signature with pass
        stub_lines = []
        in_func = False
        for line in code.split("\n"):
            if line.strip().startswith("def "):
                in_func = True
                stub_lines.append(line)
                stub_lines.append("    pass")
                break
            elif not in_func:
                # Include any imports before the function
                if line.strip().startswith("import ") or line.strip().startswith("from "):
                    stub_lines.append(line)
        stub = "\n".join(stub_lines) + "\n"

        # Test file from test_list assertions
        test_lines = "\n".join(test_list)
        test_file = textwrap.dedent(f"""\
            # Auto-generated test for MBPP/{task_id}
            from solution import *

            {test_lines}
            print("ALL_TESTS_PASSED")
        """)

        verify_sh = textwrap.dedent(f"""\
            #!/usr/bin/env bash
            set -euo pipefail
            dir="$1"
            scorer="$(dirname "$0")/../../score-metrics.py"

            cd "$dir"

            if [ ! -f "solution.py" ]; then
            \techo "FAIL: solution.py not found"
            \techo "SCORE:0"
            \texit 1
            fi

            output="$(python3 test_solution.py 2>&1)" || true
            echo "$output"

            python3 "$scorer" "$dir" '["solution.py", "test_solution.py"]' "python" 2>/dev/null || true

            if echo "$output" | grep -q "ALL_TESTS_PASSED"; then
            \techo "PASS"
            \techo "SCORE:100"
            \texit 0
            else
            \techo "FAIL"
            \techo "SCORE:0"
            \texit 1
            fi
        """)

        create_task_dir(
            name=name,
            task_json=task_json,
            prompt_md=prompt_md,
            verify_sh=verify_sh,
            fixture_files={
                "solution.py": stub,
                "test_solution.py": test_file,
            },
            dry_run=dry_run,
        )
        count += 1

    return count
```

- [ ] **Step 4: Dry-run MBPP import**

Run: `python3 benchmarks/import-tasks.py --source mbpp --dry-run --max 15`
Expected: ~10-15 tasks listed

- [ ] **Step 5: Import MBPP tasks**

Run: `python3 benchmarks/import-tasks.py --source mbpp --max 10`
Expected: 10 task directories under `benchmarks/tasks/mbpp-*`

- [ ] **Step 6: Validate 2 imported MBPP tasks**

Same approach as HumanEval validation — write canonical solution, run verify.sh.
Expected: SCORE:100 on each

- [ ] **Step 7: Fix any issues and commit**

```bash
git add benchmarks/import-tasks.py benchmarks/tasks/mbpp-*
git commit -m "Add MBPP importer and import 10 non-trivial tasks"
```

---

## Chunk 3: Exercism Importer (Tier 2 — Profile Differentiation)

### Task 4: Implement Exercism importer

**Files:**
- Modify: `benchmarks/import-tasks.py` (replace `import_exercism` stub)

**Depends on:** Task 1

**Context:** Aider's exercism-python repo has exercises at `exercises/practice/<name>/` with:
- `<name>.py` — student stub file
- `<name>_test.py` — test file (unittest-based)
- `.meta/example.py` — reference solution

These are "edit existing code" tasks — the fixture already has a stub file and tests. This maps naturally to our structure and is the best format for testing profile differentiation (opinionated profile should handle multi-function implementations differently).

- [ ] **Step 1: Clone Exercism data**

```bash
git clone --depth 1 https://github.com/Aider-AI/exercism-python.git benchmarks/sources/exercism-python
```

- [ ] **Step 2: Inspect exercise structure**

```bash
ls benchmarks/sources/exercism-python/exercises/practice/ | head -20
ls benchmarks/sources/exercism-python/exercises/practice/bank-account/
cat benchmarks/sources/exercism-python/exercises/practice/bank-account/.meta/config.json
```

- [ ] **Step 3: Replace import_exercism with full implementation**

```python
def import_exercism(filter_ids=None, dry_run=False, max_tasks=None):
    """Import tasks from Aider's exercism-python repo.

    Selection criteria: exercises with multiple functions in the reference solution
    (these test design decisions and are good for profile differentiation).
    """
    exercises_dir = os.path.join(SOURCES_DIR, "exercism-python", "exercises", "practice")
    if not os.path.exists(exercises_dir):
        print(f"  ERROR: {exercises_dir} not found. Clone with:")
        print(f"    git clone --depth 1 https://github.com/Aider-AI/exercism-python.git "
              f"{os.path.join(SOURCES_DIR, 'exercism-python')}")
        return 0

    exercises = sorted(os.listdir(exercises_dir))
    if filter_ids:
        exercises = [e for e in exercises if e in filter_ids]

    # Score each exercise by solution complexity
    candidates = []
    for exercise_name in exercises:
        ex_dir = os.path.join(exercises_dir, exercise_name)
        if not os.path.isdir(ex_dir):
            continue

        # Find reference solution
        example_path = os.path.join(ex_dir, ".meta", "example.py")
        if not os.path.exists(example_path):
            continue

        # Find test file
        test_path = os.path.join(ex_dir, f"{exercise_name.replace('-', '_')}_test.py")
        if not os.path.exists(test_path):
            continue

        # Find stub file
        stub_path = os.path.join(ex_dir, f"{exercise_name.replace('-', '_')}.py")
        if not os.path.exists(stub_path):
            continue

        with open(example_path) as f:
            solution = f.read()

        sol_lines = [l for l in solution.strip().split("\n") if l.strip()]
        num_functions = sum(1 for l in sol_lines if l.strip().startswith("def "))
        num_classes = sum(1 for l in sol_lines if l.strip().startswith("class "))

        # Prefer exercises with multiple functions or a class with methods
        complexity_score = num_functions + num_classes * 2 + len(sol_lines) // 10
        if not filter_ids and complexity_score < 3:
            continue  # Skip trivial single-function exercises

        candidates.append({
            "name": exercise_name,
            "dir": ex_dir,
            "stub_path": stub_path,
            "test_path": test_path,
            "example_path": example_path,
            "solution": solution,
            "num_functions": num_functions,
            "num_classes": num_classes,
            "sol_lines": len(sol_lines),
            "complexity_score": complexity_score,
        })

    # Sort by complexity (most complex first) for best profile differentiation
    candidates.sort(key=lambda c: c["complexity_score"], reverse=True)

    if max_tasks and len(candidates) > max_tasks:
        candidates = candidates[:max_tasks]

    print(f"  Selected {len(candidates)} of {len(exercises)} Exercism exercises")

    count = 0
    for c in candidates:
        exercise_name = c["name"]
        slug = exercise_name  # Already kebab-case
        name = f"ex-{slug}"

        if os.path.exists(os.path.join(TASKS_DIR, name)) and not dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        difficulty = difficulty_from_lines(c["sol_lines"])
        module_name = exercise_name.replace("-", "_")

        task_json = {
            "name": name,
            "description": f"Exercism: {exercise_name} ({c['num_functions']} functions, {c['num_classes']} classes)",
            "category": "implementation",
            "capability": "python-coding",
            "difficulty": difficulty,
            "timeout": 180,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": estimate_complexity(c["solution"]),
            "source": {
                "benchmark": "Aider-Exercism",
                "exercise": exercise_name,
                "license": "Apache-2.0"
            }
        }

        prompt_md = textwrap.dedent(f"""\
            Implement the solution in `{module_name}.py`.

            The file contains a stub with the expected interface. Fill in the implementation
            so that all tests pass.

            Run tests with: `python3 -m pytest {module_name}_test.py -v`

            Do not modify the test file.
        """)

        # Read fixture files
        with open(c["stub_path"]) as f:
            stub_content = f.read()
        with open(c["test_path"]) as f:
            test_content = f.read()

        # verify.sh — run pytest, count passed/total
        verify_sh = textwrap.dedent(f"""\
            #!/usr/bin/env bash
            set -euo pipefail
            dir="$1"
            scorer="$(dirname "$0")/../../score-metrics.py"

            cd "$dir"

            if [ ! -f "{module_name}.py" ]; then
            \techo "FAIL: {module_name}.py not found"
            \techo "SCORE:0"
            \texit 1
            fi

            output="$(python3 -m pytest {module_name}_test.py -v 2>&1)" || true
            echo "$output"

            passed="$(echo "$output" | grep -c "PASSED" || true)"
            failed="$(echo "$output" | grep -c "FAILED" || true)"
            total=$((passed + failed))
            [ "$total" -eq 0 ] && total=1

            score=$((passed * 100 / total))

            python3 "$scorer" "$dir" '["{module_name}.py", "{module_name}_test.py"]' "python" 2>/dev/null || true

            if [ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]; then
            \techo "PASS ($passed tests)"
            \techo "SCORE:$score"
            \texit 0
            else
            \techo "FAIL: $passed/$total tests passed"
            \techo "SCORE:$score"
            \texit 1
            fi
        """)

        create_task_dir(
            name=name,
            task_json=task_json,
            prompt_md=prompt_md,
            verify_sh=verify_sh,
            fixture_files={
                f"{module_name}.py": stub_content,
                f"{module_name}_test.py": test_content,
            },
            dry_run=dry_run,
        )
        count += 1

    return count
```

- [ ] **Step 4: Dry-run Exercism import**

Run: `python3 benchmarks/import-tasks.py --source exercism --dry-run --max 10`
Expected: 8-10 multi-function exercises listed

- [ ] **Step 5: Import Exercism tasks**

Run: `python3 benchmarks/import-tasks.py --source exercism --max 8`
Expected: 5-8 task directories under `benchmarks/tasks/ex-*`

- [ ] **Step 6: Validate 2 Exercism tasks**

Copy canonical solution from `.meta/example.py` into tmpdir, run verify.sh.
Expected: SCORE:100

- [ ] **Step 7: Fix issues and commit**

```bash
git add benchmarks/import-tasks.py benchmarks/tasks/ex-*
git commit -m "Add Exercism importer and import 8 multi-function exercises"
```

---

## Chunk 4: ClassEval Importer (Tier 2 — Class Design)

### Task 5: Implement ClassEval importer

**Files:**
- Modify: `benchmarks/import-tasks.py` (replace `import_classeval` stub)

**Depends on:** Task 1

**Context:** ClassEval tasks require implementing entire classes with multiple methods. These test design decisions (naming, encapsulation, method decomposition) which is exactly where personality profiles should diverge.

- [ ] **Step 1: Clone ClassEval data**

```bash
git clone --depth 1 https://github.com/FudanSELab/ClassEval.git benchmarks/sources/ClassEval
```

- [ ] **Step 2: Inspect ClassEval format**

```bash
ls benchmarks/sources/ClassEval/data/
python3 -c "
import json
with open('benchmarks/sources/ClassEval/data/ClassEval_data.json') as f:
    data = json.load(f)
print(f'Total tasks: {len(data)}')
print(json.dumps(data[0], indent=2)[:2000])
"
```

Confirm fields: `task_id`, `skeleton`, `test`, `solution_code`, `import_statement`, `class_description`, `methods_info`

- [ ] **Step 3: Replace import_classeval with full implementation**

```python
def import_classeval(filter_ids=None, dry_run=False, max_tasks=None):
    """Import tasks from ClassEval.

    Selection criteria: classes with 3+ methods and interesting design
    (encapsulation, data validation, state management).
    """
    # ClassEval stores data as a JSON array
    data_path = os.path.join(SOURCES_DIR, "ClassEval", "data", "ClassEval_data.json")
    if not os.path.exists(data_path):
        # Try alternate location
        alt_path = os.path.join(SOURCES_DIR, "ClassEval", "data", "benchmark_data.json")
        if os.path.exists(alt_path):
            data_path = alt_path
        else:
            print(f"  ERROR: ClassEval data not found at {data_path}")
            print(f"    git clone --depth 1 https://github.com/FudanSELab/ClassEval.git "
                  f"{os.path.join(SOURCES_DIR, 'ClassEval')}")
            return 0

    with open(data_path) as f:
        data = json.load(f)

    # Handle both list and dict formats
    if isinstance(data, dict):
        entries = list(data.values())
    else:
        entries = data

    if filter_ids:
        selected = [e for e in entries if e.get("task_id") in filter_ids]
    else:
        # Auto-select: classes with 3+ methods
        selected = []
        for e in entries:
            methods = e.get("methods_info", [])
            if len(methods) >= 3:
                selected.append(e)

    # Sort by method count descending
    selected.sort(key=lambda e: len(e.get("methods_info", [])), reverse=True)

    if max_tasks and len(selected) > max_tasks:
        selected = selected[:max_tasks]

    print(f"  Selected {len(selected)} of {len(entries)} ClassEval tasks")

    count = 0
    for entry in selected:
        task_id = entry["task_id"]  # e.g. "ClassEval_0"
        num = task_id.split("_")[-1]

        # Extract class name from skeleton
        class_name = None
        for line in entry.get("skeleton", "").split("\n"):
            if line.strip().startswith("class "):
                class_name = line.strip().split("(")[0].split(":")[0].replace("class ", "")
                break
        if not class_name:
            class_name = f"Class{num}"

        slug = ""
        for ch in class_name:
            if ch.isupper() and slug:
                slug += "-"
            slug += ch.lower()
        name = f"ce-{int(num):03d}-{slug}"

        if os.path.exists(os.path.join(TASKS_DIR, name)) and not dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        solution = entry.get("solution_code", "")
        skeleton = entry.get("skeleton", "")
        test_code = entry.get("test", "")
        imports = entry.get("import_statement", [])
        if isinstance(imports, str):
            imports = [imports] if imports else []
        description = entry.get("class_description", "")
        methods = entry.get("methods_info", [])

        sol_lines = [l for l in solution.strip().split("\n") if l.strip()]
        difficulty = difficulty_from_lines(len(sol_lines))

        task_json = {
            "name": name,
            "description": f"ClassEval/{num}: Implement {class_name} ({len(methods)} methods)",
            "category": "class-implementation",
            "capability": "python-coding",
            "difficulty": difficulty,
            "timeout": 240,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": estimate_complexity(solution),
            "source": {
                "benchmark": "ClassEval",
                "task_id": task_id,
                "license": "Apache-2.0"
            }
        }

        # Build method descriptions for the prompt
        method_desc = ""
        for m in methods:
            m_name = m.get("method_name", "unknown")
            m_desc = m.get("method_description", "")
            if m_desc:
                method_desc += f"- `{m_name}`: {m_desc}\n"

        prompt_md = textwrap.dedent(f"""\
            Implement the `{class_name}` class in `solution.py`.

            {description}

            Methods to implement:
            {method_desc}
            The file contains a skeleton with method signatures. Fill in the implementations.

            Run tests with: `python3 -m pytest test_solution.py -v`

            Do not modify `test_solution.py`.
        """)

        # fixture/solution.py — skeleton
        import_block = "\n".join(imports) + "\n\n" if imports else ""
        stub = import_block + skeleton + "\n"

        # fixture/test_solution.py
        import_stmts = "\n".join(imports) if imports else ""
        test_file = f"""{import_stmts}
import unittest
from solution import {class_name}

{test_code}

if __name__ == "__main__":
    unittest.main()
"""

        # verify.sh
        verify_sh = textwrap.dedent(f"""\
            #!/usr/bin/env bash
            set -euo pipefail
            dir="$1"
            scorer="$(dirname "$0")/../../score-metrics.py"

            cd "$dir"

            if [ ! -f "solution.py" ]; then
            \techo "FAIL: solution.py not found"
            \techo "SCORE:0"
            \texit 1
            fi

            output="$(python3 -m pytest test_solution.py -v 2>&1)" || true
            echo "$output"

            passed="$(echo "$output" | grep -c "PASSED" || true)"
            failed="$(echo "$output" | grep -c "FAILED" || true)"
            total=$((passed + failed))
            [ "$total" -eq 0 ] && total=1

            score=$((passed * 100 / total))

            python3 "$scorer" "$dir" '["solution.py", "test_solution.py"]' "python" 2>/dev/null || true

            if [ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]; then
            \techo "PASS ($passed tests)"
            \techo "SCORE:$score"
            \texit 0
            else
            \techo "FAIL: $passed/$total tests passed"
            \techo "SCORE:$score"
            \texit 1
            fi
        """)

        create_task_dir(
            name=name,
            task_json=task_json,
            prompt_md=prompt_md,
            verify_sh=verify_sh,
            fixture_files={
                "solution.py": stub,
                "test_solution.py": test_file,
            },
            dry_run=dry_run,
        )
        count += 1

    return count
```

- [ ] **Step 4: Dry-run ClassEval import**

Run: `python3 benchmarks/import-tasks.py --source classeval --dry-run --max 6`
Expected: 5-6 multi-method class tasks listed

- [ ] **Step 5: Import ClassEval tasks**

Run: `python3 benchmarks/import-tasks.py --source classeval --max 5`
Expected: 5 task directories under `benchmarks/tasks/ce-*`

- [ ] **Step 6: Validate 2 ClassEval tasks**

Write canonical solution, run verify.sh.
Expected: SCORE:100

- [ ] **Step 7: Fix issues and commit**

```bash
git add benchmarks/import-tasks.py benchmarks/tasks/ce-*
git commit -m "Add ClassEval importer and import 5 multi-method class tasks"
```

---

## Chunk 5: Aider Refactoring Importer (Tier 2 — Best for Profile Differentiation)

### Task 6: Implement Aider Refactoring importer

**Files:**
- Modify: `benchmarks/import-tasks.py` (replace `import_refactoring` stub)

**Depends on:** Task 1

**Context:** The Aider refactor-benchmark contains 89 Python refactoring tasks from real repos. Each task has existing code that needs to be refactored (renamed, restructured, simplified) with tests that verify the refactoring was done correctly. This is the **most valuable source for profile differentiation** — the opinionated profile should outperform blank because it has strong opinions on code structure, naming, and simplicity.

The repo structure is: each task has a directory with source files, a `.docs/` or instructions file describing the refactoring, and test files. The exact structure needs to be confirmed after cloning.

- [ ] **Step 1: Clone Aider refactoring data**

```bash
git clone --depth 1 https://github.com/Aider-AI/refactor-benchmark.git benchmarks/sources/refactor-benchmark
```

- [ ] **Step 2: Inspect refactoring repo structure**

```bash
ls benchmarks/sources/refactor-benchmark/
# Find where tasks/exercises live
find benchmarks/sources/refactor-benchmark -name "*.py" -maxdepth 3 | head -20
# Look for task definitions
find benchmarks/sources/refactor-benchmark -name "*.json" -o -name "*.yaml" -o -name "*.md" | head -20
```

Understand the task format: what files define each refactoring task, where are the tests, how is the expected outcome described.

- [ ] **Step 3: Implement import_refactoring based on discovered format**

The implementation depends on the repo structure discovered in Step 2. The general pattern:

```python
def import_refactoring(filter_ids=None, dry_run=False, max_tasks=None):
    """Import tasks from Aider's refactor-benchmark.

    Each task involves refactoring existing Python code while keeping tests passing.
    These are the highest-value tasks for profile differentiation.
    """
    repo_dir = os.path.join(SOURCES_DIR, "refactor-benchmark")
    if not os.path.exists(repo_dir):
        print(f"  ERROR: {repo_dir} not found. Clone with:")
        print(f"    git clone --depth 1 https://github.com/Aider-AI/refactor-benchmark.git {repo_dir}")
        return 0

    # Discover task structure (adapt after Step 2 inspection)
    # Look for task directories with source + test files
    # Each task should have:
    #   - Source code to refactor (fixture/)
    #   - Instructions describing what to refactor (prompt.md)
    #   - Tests that verify the refactoring (verify.sh runs them)

    # Selection: pick 3-5 tasks that test structural changes
    # (renaming, extracting functions, simplifying logic)
    # Prefer tasks where code quality metrics would differ between profiles

    # ... (implementation adapted to actual repo structure)

    # For each selected task, create_task_dir() with:
    #   category: "refactoring"
    #   capability: "code-quality"
    #   difficulty: "medium" or "advanced"

    raise NotImplementedError(
        "Adapt this after inspecting the refactor-benchmark repo structure in Step 2"
    )
```

**Note:** This importer cannot be fully pre-written because the Aider refactor-benchmark repo structure needs to be inspected first. The implementing agent should:
1. Clone and inspect the repo
2. Identify how tasks are defined (look for README, task manifests, directory conventions)
3. Write the importer to match the actual format
4. Follow the same patterns as the Exercism importer (fixture files, pytest-based verify.sh)

Task naming convention: `rf-<num>-<short-description>`

- [ ] **Step 4: Dry-run refactoring import**

Run: `python3 benchmarks/import-tasks.py --source refactoring --dry-run --max 5`

- [ ] **Step 5: Import refactoring tasks**

Run: `python3 benchmarks/import-tasks.py --source refactoring --max 5`
Expected: 3-5 task directories under `benchmarks/tasks/rf-*`

- [ ] **Step 6: Validate 1-2 refactoring tasks**

Apply the reference solution, run verify.sh.
Expected: SCORE:100

- [ ] **Step 7: Commit**

```bash
git add benchmarks/import-tasks.py benchmarks/tasks/rf-*
git commit -m "Add Aider Refactoring importer and import 5 refactoring tasks"
```

---

## Chunk 6: Validation + Integration

### Task 7: Full validation pass

**Files:** None (validation only)

**Depends on:** Tasks 2, 3, 4, 5, 6

- [ ] **Step 1: Count total imported tasks**

```bash
ls -d benchmarks/tasks/he-* benchmarks/tasks/mbpp-* benchmarks/tasks/ex-* benchmarks/tasks/ce-* benchmarks/tasks/rf-* 2>/dev/null | wc -l
```

Expected: 45-50 new tasks (20 HumanEval + 10 MBPP + 8 Exercism + 5 ClassEval + 5 Refactoring)

- [ ] **Step 2: Verify all task.json files are valid JSON**

```bash
for f in benchmarks/tasks/*/task.json; do
    python3 -c "import json; json.load(open('$f'))" || echo "INVALID: $f"
done
```

Expected: No "INVALID" lines

- [ ] **Step 3: Verify all verify.sh are executable**

```bash
for f in benchmarks/tasks/*/verify.sh; do
    [ -x "$f" ] || echo "NOT EXECUTABLE: $f"
done
```

Expected: No "NOT EXECUTABLE" lines

- [ ] **Step 4: Spot-check 1 task from each source with canonical solution**

For each source (he, mbpp, ex, ce, rf), pick one task, write the canonical solution into a tmpdir, and run verify.sh. All should exit 0 with SCORE:100.

- [ ] **Step 5: Fix any remaining issues and commit**

```bash
git add benchmarks/
git commit -m "Fix validation issues in imported benchmark tasks"
```

### Task 8: Run benchmark suite on all profiles

**Files:** None (benchmark execution)

**Depends on:** Task 7

**NOTE:** Running the full benchmark suite (45+ tasks x 3 profiles) will take significant time and API cost. The user should decide whether to run all tasks or a subset.

- [ ] **Step 1: Confirm with user before running**

The full suite (~45 tasks x 3 profiles = ~135 claude -p invocations) will take time and cost. Suggest running a subset first:

```bash
# Run 3 tasks per source to validate, on main profile only
./setup.sh benchmark --task he-002-truncate-number
./setup.sh benchmark --task mbpp-056-find-max
./setup.sh benchmark --task ex-bank-account
./setup.sh benchmark --task ce-000-access-gateway-filter
```

- [ ] **Step 2: Run full suite if approved**

```bash
./setup.sh benchmark
```

- [ ] **Step 3: Generate dashboard**

```bash
./setup.sh benchmark --report --html
```

Expected: Updated `_metrics/dashboard.html` with all tasks and profiles

- [ ] **Step 4: Review results for profile differentiation**

Check if Tier 2 tasks (ex-*, rf-*, ce-*) show meaningful differences between profiles:
- Does the opinionated profile score differently on code quality metrics?
- Do blank and main profiles differ in overengineering or naming scores?
- Do refactoring tasks (rf-*) show the strongest differentiation?

- [ ] **Step 5: Commit benchmark results**

```bash
git add _metrics/
git commit -m "Run benchmark expansion suite and regenerate dashboard"
```

### Task 9: Propagate shared files to other branches

**Files:** None (git operations)

**Depends on:** Task 8

**Context:** The spec requires propagating `benchmarks/` to the blank and opinionated branches so they have the same tasks available. The benchmark runner reads tasks from the current checkout, but having them on all branches keeps things consistent.

- [ ] **Step 1: Confirm with user before modifying other branches**

This will cherry-pick benchmark-related commits to the blank and opinionated branches. Confirm this is desired.

- [ ] **Step 2: Propagate to blank branch**

```bash
# Get the commit hashes for benchmark work on main
commits=$(git log --oneline main --grep="import" --grep="benchmark" --all-match | head -5 | awk '{print $1}')
# Cherry-pick to blank
git checkout blank
git cherry-pick $commits
git checkout main
```

Alternatively, if many commits, merge the benchmarks/ directory:
```bash
git checkout blank
git checkout main -- benchmarks/
git add benchmarks/
git commit -m "Sync benchmark tasks from main"
git checkout main
```

- [ ] **Step 3: Propagate to opinionated branch**

Same approach as Step 2 but for the opinionated branch.

- [ ] **Step 4: Verify all branches have the tasks**

```bash
git show blank:benchmarks/tasks/ | head -20
git show opinionated:benchmarks/tasks/ | head -20
```

- [ ] **Step 5: Return to main**

```bash
git checkout main
```

---

## Parallelization Notes

Tasks 3, 4, 5, and 6 (MBPP, Exercism, ClassEval, Refactoring importers) are independent and can be executed in parallel after Task 2 (HumanEval) validates the pattern. Each modifies a different function in `import-tasks.py` and creates non-overlapping task directories.

**Recommended execution order:**
1. Tasks 1+2 sequentially (scaffold + HumanEval — validates the pattern)
2. Tasks 3, 4, 5, 6 in parallel (MBPP, Exercism, ClassEval, Refactoring)
3. Task 7 sequentially (validation)
4. Task 8 sequentially (benchmark run — requires user confirmation)
5. Task 9 sequentially (branch propagation — requires user confirmation)
