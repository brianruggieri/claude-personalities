#!/usr/bin/env python3
"""Import benchmark tasks from public coding-challenge datasets.

Supported sources:
  humaneval  — OpenAI HumanEval (function completion)
  mbpp       — Google MBPP (short Python programs)
  exercism   — Exercism Python track (multi-file exercises)
  classeval  — ClassEval (class-level generation)
  refactoring — Aider refactoring benchmarks

Usage:
  python3 import-tasks.py --source humaneval --max 20
  python3 import-tasks.py --source humaneval --filter 2,5,10 --dry-run
"""
import argparse
import json
import os
import re
import stat
import sys
import textwrap

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TASKS_DIR = os.path.join(SCRIPT_DIR, "tasks")
SOURCES_DIR = os.path.join(SCRIPT_DIR, "sources")


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def slugify(name):
    """Convert a CamelCase or mixed name to kebab-case slug."""
    # Insert hyphens before uppercase letters that follow lowercase letters
    s = re.sub(r'([a-z])([A-Z])', r'\1-\2', name)
    # Replace underscores and spaces with hyphens
    s = re.sub(r'[_\s]+', '-', s)
    # Remove non-alphanumeric chars except hyphens
    s = re.sub(r'[^a-z0-9-]', '', s.lower())
    # Collapse multiple hyphens
    s = re.sub(r'-+', '-', s).strip('-')
    return s


def create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files=None, dry_run=False):
    """Create a task directory with all required files.

    Args:
        name: Task directory name (e.g. 'he-002-truncate-number')
        task_json: Dict to serialize as task.json
        prompt_md: String content for prompt.md
        verify_sh: String content for verify.sh (will be made executable)
        fixture_files: Dict of {relative_path: content} for fixture/ files
        dry_run: If True, print what would be created without writing
    """
    task_dir = os.path.join(TASKS_DIR, name)
    fixture_dir = os.path.join(task_dir, "fixture")

    if dry_run:
        print(f"  [dry-run] Would create: {task_dir}/")
        print(f"            task.json, prompt.md, verify.sh")
        if fixture_files:
            for fpath in fixture_files:
                print(f"            fixture/{fpath}")
        return

    os.makedirs(fixture_dir, exist_ok=True)

    # task.json
    with open(os.path.join(task_dir, "task.json"), "w") as f:
        json.dump(task_json, f, indent=2)
        f.write("\n")

    # prompt.md
    with open(os.path.join(task_dir, "prompt.md"), "w") as f:
        f.write(prompt_md)

    # verify.sh (executable)
    verify_path = os.path.join(task_dir, "verify.sh")
    with open(verify_path, "w") as f:
        f.write(verify_sh)
    st = os.stat(verify_path)
    os.chmod(verify_path, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    # fixture files
    if fixture_files:
        for fpath, content in fixture_files.items():
            full_path = os.path.join(fixture_dir, fpath)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)


def estimate_complexity(solution_code):
    """Estimate expected_complexity dict from solution code.

    Returns a dict suitable for task.json expected_complexity field.
    """
    lines = [l for l in solution_code.strip().split('\n') if l.strip()]
    num_lines = len(lines)

    # Count functions and classes
    num_functions = len(re.findall(r'^\s*def\s+', solution_code, re.MULTILINE))
    num_classes = len(re.findall(r'^\s*class\s+', solution_code, re.MULTILINE))

    # Estimate max complexity from decision points
    decision_keywords = ['if ', 'elif ', 'for ', 'while ', 'except ', ' and ', ' or ']
    decisions = sum(
        solution_code.count(kw) for kw in decision_keywords
    )
    # Rough heuristic: complexity ~ 1 + decisions per function
    avg_decisions = decisions / max(num_functions, 1)

    return {
        "max_files": 2,
        "max_classes": max(num_classes, 0),
        "max_functions": max(num_functions + 2, 3),  # allow a couple extra
        "max_lines": max(num_lines * 3, 30),
        "disallow_patterns": []
    }


def difficulty_from_lines(num_lines):
    """Map solution line count to difficulty string."""
    if num_lines <= 3:
        return "trivial"
    elif num_lines <= 8:
        return "basic"
    elif num_lines <= 15:
        return "intermediate"
    elif num_lines <= 30:
        return "advanced"
    else:
        return "expert"


# ---------------------------------------------------------------------------
# Importers
# ---------------------------------------------------------------------------

def import_humaneval(args):
    """Import tasks from OpenAI HumanEval dataset."""
    source_file = os.path.join(SOURCES_DIR, "HumanEval.jsonl")
    if not os.path.exists(source_file):
        print(f"ERROR: {source_file} not found.")
        print("Download it first:")
        print(f"  mkdir -p {SOURCES_DIR}")
        print(f"  curl -L https://github.com/openai/human-eval/raw/master/data/HumanEval.jsonl.gz -o {SOURCES_DIR}/HumanEval.jsonl.gz")
        print(f"  gunzip -f {SOURCES_DIR}/HumanEval.jsonl.gz")
        sys.exit(1)

    # Load all entries
    entries = []
    with open(source_file) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    print(f"Loaded {len(entries)} HumanEval entries")

    # Filter by IDs if specified
    if args.filter:
        filter_ids = set(int(x.strip()) for x in args.filter.split(','))
        entries = [e for e in entries if _he_num(e['task_id']) in filter_ids]
        print(f"Filtered to {len(entries)} entries by ID")

    # Auto-select: skip trivial (< 5 lines) and very complex (> 40 lines)
    selected = []
    for entry in entries:
        sol_lines = len([l for l in entry['canonical_solution'].strip().split('\n') if l.strip()])
        if sol_lines < 5:
            continue
        if sol_lines > 40:
            continue
        selected.append(entry)

    print(f"Auto-selected {len(selected)} entries (5-40 solution lines)")

    # Apply max limit
    if args.max and args.max < len(selected):
        selected = selected[:args.max]
        print(f"Limited to first {args.max} entries")

    # Import each task
    created = 0
    for entry in selected:
        num = _he_num(entry['task_id'])
        entry_point = entry['entry_point']
        slug = slugify(entry_point)
        name = f"he-{num:03d}-{slug}"

        prompt_code = entry['prompt']
        canonical_solution = entry['canonical_solution']
        test_code = entry['test']

        sol_lines = len([l for l in canonical_solution.strip().split('\n') if l.strip()])
        difficulty = difficulty_from_lines(sol_lines)
        complexity = estimate_complexity(canonical_solution)

        # task.json
        task_json = {
            "name": name,
            "description": f"Complete the {entry_point} function",
            "category": "function-completion",
            "capability": "code-generation",
            "difficulty": difficulty,
            "timeout": 120,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": complexity,
            "source": {
                "dataset": "HumanEval",
                "task_id": entry['task_id'],
                "entry_point": entry_point,
                "license": "MIT"
            }
        }

        # prompt.md
        prompt_md = textwrap.dedent(f"""\
            Complete the implementation of the function in `solution.py`.
            Tests are in `test_solution.py`.
            Run with: `python3 test_solution.py`

            Do not modify test_solution.py.
        """)

        # fixture/solution.py — prompt (signature + docstring) + pass
        solution_py = prompt_code.strip() + "\n    pass\n"

        # fixture/test_solution.py
        test_solution_py = _build_he_test(entry_point, test_code, prompt_code)

        # verify.sh
        verify_sh = _build_he_verify()

        # fixture files
        fixture_files = {
            "solution.py": solution_py,
            "test_solution.py": test_solution_py,
        }

        # Skip if task directory already exists
        task_dir = os.path.join(TASKS_DIR, name)
        if os.path.isdir(task_dir) and not args.dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        print(f"  {'[dry-run] ' if args.dry_run else ''}Creating {name} (difficulty={difficulty}, lines={sol_lines})")
        create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files, dry_run=args.dry_run)
        created += 1

    print(f"\n{'Would create' if args.dry_run else 'Created'} {created} HumanEval tasks")


def _he_num(task_id):
    """Extract numeric ID from HumanEval task_id like 'HumanEval/2'."""
    return int(task_id.split('/')[-1])


def _build_he_test(entry_point, test_code, prompt_code):
    """Build test_solution.py from HumanEval test code.

    HumanEval tests define a check() function that calls the entry_point.
    We need to import the entry_point from solution and wire it up.
    Some tests reference helper functions defined in the prompt (e.g. poly),
    so we detect and import those too.
    """
    # Find all top-level function names defined in the prompt
    prompt_funcs = set(re.findall(r'^def\s+(\w+)\s*\(', prompt_code, re.MULTILINE))

    # Determine which prompt functions are referenced in the test code
    # (exclude the entry_point itself since we always import it)
    extra_imports = []
    for func_name in prompt_funcs:
        if func_name == entry_point:
            continue
        # Check if test code references this function name as a call or identifier
        if re.search(r'\b' + re.escape(func_name) + r'\b', test_code):
            extra_imports.append(func_name)

    # Build the import line
    imports = [entry_point] + sorted(extra_imports)
    import_line = f"from solution import {', '.join(imports)}"

    lines = []
    lines.append(import_line)
    lines.append("")
    lines.append("")

    # Add the test code as-is (strip leading blank lines too)
    lines.append(test_code.strip())
    lines.append("")

    # Call check with the entry_point
    lines.append(f"check({entry_point})")
    lines.append("print('ALL_TESTS_PASSED')")
    lines.append("")

    return "\n".join(lines)


def _build_he_verify():
    """Build verify.sh for a HumanEval task."""
    # Using tabs for indentation per project convention
    return (
        '#!/usr/bin/env bash\n'
        'set -euo pipefail\n'
        'dir="$1"\n'
        'scorer="$(dirname "$0")/../../score-metrics.py"\n'
        '\n'
        'cd "$dir"\n'
        'output="$(python3 test_solution.py 2>&1)" || true\n'
        'echo "$output"\n'
        '\n'
        '# Run shared metrics\n'
        'python3 "$scorer" "$dir" \'["solution.py", "test_solution.py"]\' "python" 2>/dev/null || true\n'
        '\n'
        'if echo "$output" | grep -q "ALL_TESTS_PASSED"; then\n'
        '\techo "PASS"\n'
        '\techo "SCORE:100"\n'
        '\texit 0\n'
        'else\n'
        '\techo "FAIL"\n'
        '\techo "SCORE:0"\n'
        '\texit 1\n'
        'fi\n'
    )


def import_mbpp(args):
    """Import tasks from Google MBPP dataset."""
    source_file = os.path.join(SOURCES_DIR, "mbpp.jsonl")
    if not os.path.exists(source_file):
        print(f"ERROR: {source_file} not found.")
        print("Download it first:")
        print(f"  mkdir -p {SOURCES_DIR}")
        print(f"  curl -L https://raw.githubusercontent.com/google-research/google-research/master/mbpp/mbpp.jsonl -o {SOURCES_DIR}/mbpp.jsonl")
        sys.exit(1)

    # Load all entries
    entries = []
    with open(source_file) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    print(f"Loaded {len(entries)} MBPP entries")

    # Filter by IDs if specified
    if args.filter:
        filter_ids = set(int(x.strip()) for x in args.filter.split(','))
        entries = [e for e in entries if e['task_id'] in filter_ids]
        print(f"Filtered to {len(entries)} entries by ID")
    else:
        # Skip first 10 entries (few-shot prompt examples)
        entries = entries[10:]
        print(f"Skipped first 10 few-shot examples, {len(entries)} remaining")

    # Auto-select: require 3+ tests, solution 5-30 lines
    selected = []
    for entry in entries:
        code = entry['code'].replace('\r\n', '\n').replace('\r', '\n')
        sol_lines = len([l for l in code.strip().split('\n') if l.strip()])
        num_tests = len(entry.get('test_list', []))
        if num_tests < 3:
            continue
        if sol_lines < 5:
            continue
        if sol_lines > 30:
            continue
        selected.append(entry)

    print(f"Auto-selected {len(selected)} entries (3+ tests, 5-30 solution lines)")

    # Apply max limit
    if args.max and args.max < len(selected):
        selected = selected[:args.max]
        print(f"Limited to first {args.max} entries")

    # Import each task
    created = 0
    for entry in selected:
        task_id = entry['task_id']
        code = entry['code'].replace('\r\n', '\n').replace('\r', '\n')
        text = entry['text']
        test_list = entry.get('test_list', [])

        # Extract the primary function name from the test assertions
        func_name = _mbpp_extract_func_name(test_list, code)
        if not func_name:
            print(f"  Skipping task_id={task_id} (could not determine function name)")
            continue

        slug = slugify(func_name)
        name = f"mbpp-{task_id:03d}-{slug}"

        sol_lines = len([l for l in code.strip().split('\n') if l.strip()])
        difficulty = difficulty_from_lines(sol_lines)
        complexity = estimate_complexity(code)

        # task.json
        task_json = {
            "name": name,
            "description": text,
            "category": "function-completion",
            "capability": "code-generation",
            "difficulty": difficulty,
            "timeout": 120,
            "scoring": "binary",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": complexity,
            "source": {
                "dataset": "MBPP",
                "task_id": task_id,
                "entry_point": func_name,
                "license": "CC-BY-4.0"
            }
        }

        # prompt.md
        prompt_md = textwrap.dedent(f"""\
            {text}

            Write your solution in `solution.py`. The function should be named `{func_name}`.
            Tests are in `test_solution.py`.
            Run with: `python3 test_solution.py`

            Do not modify test_solution.py.
        """)

        # fixture/solution.py — stub with imports + function signature + pass
        solution_py = _mbpp_build_stub(func_name, code)

        # fixture/test_solution.py
        test_solution_py = _mbpp_build_test(func_name, code, test_list)

        # verify.sh
        verify_sh = _build_mbpp_verify()

        # fixture files
        fixture_files = {
            "solution.py": solution_py,
            "test_solution.py": test_solution_py,
        }

        # Skip if task directory already exists
        task_dir = os.path.join(TASKS_DIR, name)
        if os.path.isdir(task_dir) and not args.dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        print(f"  {'[dry-run] ' if args.dry_run else ''}Creating {name} (difficulty={difficulty}, lines={sol_lines})")
        create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files, dry_run=args.dry_run)
        created += 1

    print(f"\n{'Would create' if args.dry_run else 'Created'} {created} MBPP tasks")


def _mbpp_extract_func_name(test_list, code):
    """Extract the primary function name from MBPP test assertions.

    Tries the test assertions first (most reliable), then falls back
    to the last top-level def in the code.
    """
    # Try to extract from the first test assertion: assert func_name(...)
    for test in test_list:
        m = re.search(r'assert\s+(\w+)\s*\(', test)
        if m:
            return m.group(1)
        # Handle assert ... == func_name(...) patterns
        m = re.search(r'==\s*(\w+)\s*\(', test)
        if m:
            return m.group(1)

    # Fall back to last top-level function def in the code
    funcs = re.findall(r'^def\s+(\w+)\s*\(', code, re.MULTILINE)
    if funcs:
        return funcs[-1]

    return None


def _mbpp_build_stub(func_name, code):
    """Build solution.py stub from MBPP solution code.

    Extracts imports and the target function's signature, returns a stub
    with `pass` as the body. Also includes any global constants or helper
    code that appear before the target function.
    """
    lines = code.strip().split('\n')

    # Collect import lines
    imports = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('import ') or stripped.startswith('from '):
            imports.append(stripped)

    # Find the target function's def line to extract the full signature
    sig_line = None
    for line in lines:
        # Match def func_name(... — could be indented in the original
        m = re.match(r'^(?:def\s+)' + re.escape(func_name) + r'\s*\(', line.strip())
        if m:
            sig_line = line.strip()
            break

    if not sig_line:
        # Fallback: just create a basic signature
        sig_line = f"def {func_name}():"

    # Ensure the signature ends with colon
    if not sig_line.endswith(':'):
        sig_line += ':'

    parts = []
    if imports:
        parts.append('\n'.join(imports))
        parts.append('')
        parts.append('')
    parts.append(sig_line)
    parts.append('    pass')
    parts.append('')

    return '\n'.join(parts)


def _mbpp_build_test(func_name, code, test_list):
    """Build test_solution.py for an MBPP task.

    Uses `from solution import *` so all functions and globals are available
    to the test assertions.
    """
    lines = []
    lines.append("from solution import *")
    lines.append("")
    lines.append("")

    # Add each test assertion
    for test in test_list:
        test = test.strip()
        lines.append(test)

    lines.append("")
    lines.append('print("ALL_TESTS_PASSED")')
    lines.append("")

    return '\n'.join(lines)


def _build_mbpp_verify():
    """Build verify.sh for an MBPP task."""
    return (
        '#!/usr/bin/env bash\n'
        'set -euo pipefail\n'
        'dir="$1"\n'
        'scorer="$(dirname "$0")/../../score-metrics.py"\n'
        '\n'
        'cd "$dir"\n'
        'output="$(python3 test_solution.py 2>&1)" || true\n'
        'echo "$output"\n'
        '\n'
        '# Run shared metrics\n'
        'python3 "$scorer" "$dir" \'["solution.py", "test_solution.py"]\' "python" 2>/dev/null || true\n'
        '\n'
        'if echo "$output" | grep -q "ALL_TESTS_PASSED"; then\n'
        '\techo "PASS"\n'
        '\techo "SCORE:100"\n'
        '\texit 0\n'
        'else\n'
        '\techo "FAIL"\n'
        '\techo "SCORE:0"\n'
        '\texit 1\n'
        'fi\n'
    )


def import_exercism(args):
    """Import tasks from Exercism Python track.

    Selects exercises with multi-function solutions, scored by:
        num_functions + num_classes*2 + sol_lines/10
    Skips exercises scoring < 3.
    """
    exercises_dir = os.path.join(SOURCES_DIR, "exercism-python", "exercises", "practice")
    if not os.path.isdir(exercises_dir):
        print(f"ERROR: {exercises_dir} not found.")
        print("Clone it first:")
        print(f"  git clone --depth 1 https://github.com/exercism/python.git {os.path.join(SOURCES_DIR, 'exercism-python')}")
        sys.exit(1)

    # Scan all exercises and score them
    scored = []
    for exercise_name in sorted(os.listdir(exercises_dir)):
        exercise_path = os.path.join(exercises_dir, exercise_name)
        if not os.path.isdir(exercise_path):
            continue

        # Derive the module name (exercise names are kebab-case, modules use underscores)
        module_name = exercise_name.replace("-", "_")

        # Required files
        example_path = os.path.join(exercise_path, ".meta", "example.py")
        stub_path = os.path.join(exercise_path, f"{module_name}.py")
        test_path = os.path.join(exercise_path, f"{module_name}_test.py")

        if not all(os.path.exists(p) for p in [example_path, stub_path, test_path]):
            continue

        # Read the reference solution for scoring
        with open(example_path) as f:
            solution_code = f.read()

        sol_lines = len([l for l in solution_code.strip().split('\n') if l.strip()])
        num_functions = len(re.findall(r'^\s*def\s+', solution_code, re.MULTILINE))
        num_classes = len(re.findall(r'^\s*class\s+', solution_code, re.MULTILINE))

        complexity_score = num_functions + num_classes * 2 + sol_lines // 10
        if complexity_score < 3:
            continue

        # Check for extra .py files that tests might depend on (beyond stub + test)
        extra_py = []
        for fname in os.listdir(exercise_path):
            if fname.endswith('.py') and fname != f"{module_name}.py" and fname != f"{module_name}_test.py":
                extra_py.append(fname)

        scored.append({
            "exercise_name": exercise_name,
            "module_name": module_name,
            "exercise_path": exercise_path,
            "example_path": example_path,
            "stub_path": stub_path,
            "test_path": test_path,
            "extra_py": extra_py,
            "sol_lines": sol_lines,
            "num_functions": num_functions,
            "num_classes": num_classes,
            "complexity_score": complexity_score,
        })

    # Sort by complexity descending
    scored.sort(key=lambda x: x["complexity_score"], reverse=True)

    print(f"Found {len(scored)} eligible exercises (score >= 3)")

    # Filter by name if specified
    if args.filter:
        filter_names = set(x.strip() for x in args.filter.split(','))
        scored = [e for e in scored if e["exercise_name"] in filter_names]
        print(f"Filtered to {len(scored)} exercises by name")

    # Apply max limit
    if args.max and args.max < len(scored):
        scored = scored[:args.max]
        print(f"Limited to top {args.max} exercises by complexity")

    # Import each exercise
    created = 0
    for entry in scored:
        exercise_name = entry["exercise_name"]
        module_name = entry["module_name"]
        name = f"ex-{exercise_name}"

        # Skip if task directory already exists
        task_dir = os.path.join(TASKS_DIR, name)
        if os.path.isdir(task_dir) and not args.dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        # Read source files
        with open(entry["stub_path"]) as f:
            stub_code = f.read()
        with open(entry["test_path"]) as f:
            test_code = f.read()
        with open(entry["example_path"]) as f:
            solution_code = f.read()

        difficulty = difficulty_from_lines(entry["sol_lines"])
        complexity = estimate_complexity(solution_code)

        # task.json
        task_json = {
            "name": name,
            "description": f"Implement the {exercise_name} exercise",
            "category": "implementation",
            "capability": "code-generation",
            "difficulty": difficulty,
            "timeout": 180,
            "scoring": "partial",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": complexity,
            "source": {
                "dataset": "Exercism",
                "exercise": exercise_name,
                "track": "python",
                "license": "Apache-2.0"
            }
        }

        # prompt.md
        prompt_md = (
            f"Implement the solution in `{module_name}.py`.\n"
            f"Run tests with `python3 -m pytest {module_name}_test.py -v`\n\n"
            f"Do not modify {module_name}_test.py.\n"
        )

        # verify.sh
        verify_sh = _build_exercism_verify(module_name)

        # fixture files
        fixture_files = {
            f"{module_name}.py": stub_code,
            f"{module_name}_test.py": test_code,
        }

        # Copy any extra .py files the tests depend on
        for extra_fname in entry["extra_py"]:
            extra_path = os.path.join(entry["exercise_path"], extra_fname)
            with open(extra_path) as f:
                fixture_files[extra_fname] = f.read()

        print(f"  {'[dry-run] ' if args.dry_run else ''}Creating {name} "
              f"(score={entry['complexity_score']}, difficulty={difficulty}, "
              f"funcs={entry['num_functions']}, classes={entry['num_classes']}, "
              f"lines={entry['sol_lines']})")

        create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files, dry_run=args.dry_run)
        created += 1

    print(f"\n{'Would create' if args.dry_run else 'Created'} {created} Exercism tasks")


def _build_exercism_verify(module_name):
    """Build verify.sh for an Exercism task using pytest."""
    return (
        '#!/usr/bin/env bash\n'
        'set -euo pipefail\n'
        'dir="$1"\n'
        'scorer="$(dirname "$0")/../../score-metrics.py"\n'
        '\n'
        'cd "$dir"\n'
        '\n'
        '# Check module file exists\n'
        f'if [ ! -f "{module_name}.py" ]; then\n'
        f'\techo "FAIL: {module_name}.py not found"\n'
        '\techo "SCORE:0"\n'
        '\texit 1\n'
        'fi\n'
        '\n'
        '# Run pytest\n'
        f'output="$(python3 -m pytest {module_name}_test.py -v 2>&1)" || true\n'
        'echo "$output"\n'
        '\n'
        '# Count PASSED and FAILED\n'
        'passed="$(echo "$output" | grep -c "PASSED" || true)"\n'
        'failed="$(echo "$output" | grep -c "FAILED" || true)"\n'
        'total=$(( passed + failed ))\n'
        '\n'
        '# Calculate score\n'
        'if [ "$total" -gt 0 ]; then\n'
        '\tscore=$(( passed * 100 / total ))\n'
        'else\n'
        '\tscore=0\n'
        'fi\n'
        '\n'
        '# Run shared metrics\n'
        f'python3 "$scorer" "$dir" \'["{module_name}.py", "{module_name}_test.py"]\' "python" 2>/dev/null || true\n'
        '\n'
        'if [ "$passed" -eq "$total" ] && [ "$total" -gt 0 ]; then\n'
        '\techo "PASS"\n'
        '\techo "SCORE:$score"\n'
        '\texit 0\n'
        'else\n'
        '\techo "FAIL: $passed/$total tests passed"\n'
        '\techo "SCORE:$score"\n'
        '\texit 1\n'
        'fi\n'
    )


def import_classeval(args):
    """Import tasks from ClassEval dataset.

    Selects classes with 3+ methods, sorted by method count descending.
    """
    source_dir = os.path.join(SOURCES_DIR, "ClassEval")
    data_file = os.path.join(source_dir, "data", "ClassEval_data.json")
    if not os.path.exists(data_file):
        print(f"ERROR: {data_file} not found.")
        print("Clone it first:")
        print(f"  git clone --depth 1 https://github.com/FudanSELab/ClassEval.git {source_dir}")
        sys.exit(1)

    # Load all entries
    with open(data_file) as f:
        raw = json.load(f)

    # Normalize: could be list or dict
    if isinstance(raw, dict):
        entries = list(raw.values())
    else:
        entries = list(raw)

    print(f"Loaded {len(entries)} ClassEval entries")

    # Selection criteria: classes with 3+ methods
    selected = []
    for entry in entries:
        methods = entry.get("methods_info", [])
        if len(methods) < 3:
            continue
        selected.append(entry)

    print(f"Auto-selected {len(selected)} entries (3+ methods)")

    # Sort by method count descending
    selected.sort(key=lambda e: len(e.get("methods_info", [])), reverse=True)

    # Filter by IDs if specified
    if args.filter:
        filter_ids = set(x.strip() for x in args.filter.split(','))
        selected = [e for e in selected if e['task_id'] in filter_ids]
        print(f"Filtered to {len(selected)} entries by ID")

    # Apply max limit
    if args.max and args.max < len(selected):
        selected = selected[:args.max]
        print(f"Limited to first {args.max} entries")

    # Import each task
    created = 0
    for idx, entry in enumerate(selected):
        class_name = entry["class_name"]
        slug = slugify(class_name)
        name = f"ce-{idx:03d}-{slug}"

        methods = entry.get("methods_info", [])
        num_methods = len(methods)
        solution_code = entry["solution_code"]

        # Type guard: import_statement can be str or list
        imports = entry.get("import_statement", [])
        if isinstance(imports, str):
            imports = [imports] if imports else []

        sol_lines = len([l for l in solution_code.strip().split('\n') if l.strip()])
        difficulty = difficulty_from_lines(sol_lines)
        complexity = estimate_complexity(solution_code)

        # task.json
        task_json = {
            "name": name,
            "description": f"Implement the {class_name} class with {num_methods} methods",
            "category": "class-implementation",
            "capability": "code-generation",
            "difficulty": difficulty,
            "timeout": 180,
            "scoring": "partial",
            "metrics": ["correctness", "cost", "duration", "token_efficiency"],
            "expected_complexity": complexity,
            "source": {
                "dataset": "ClassEval",
                "task_id": entry["task_id"],
                "class_name": class_name,
                "license": "Apache-2.0"
            }
        }

        # prompt.md — describe the class and list methods
        method_lines = []
        for m in methods:
            desc = m.get("method_description", "").strip()
            # Take just the first line of description if multi-line
            first_line = desc.split('\n')[0].strip().strip('"').strip("'").strip()
            if first_line:
                method_lines.append(f"- `{m['method_name']}`: {first_line}")
            else:
                method_lines.append(f"- `{m['method_name']}`")

        class_desc = entry.get("class_description", "").strip().strip('"').strip()
        prompt_md = (
            f"Implement the `{class_name}` class in `solution.py`.\n\n"
            f"{class_desc}\n\n"
            f"## Methods to implement\n\n"
            + "\n".join(method_lines) + "\n\n"
            f"Tests are in `test_solution.py`.\n"
            f"Run with: `python3 -m pytest test_solution.py -v`\n\n"
            f"Do not modify test_solution.py.\n"
        )

        # fixture/solution.py — import statements + skeleton code
        solution_parts = []
        if imports:
            solution_parts.append("\n".join(imports))
            solution_parts.append("")
        skeleton = entry.get("skeleton", "")
        # The skeleton typically already includes imports; strip them to avoid duplication
        skeleton_lines = skeleton.strip().split('\n')
        skeleton_body = []
        for line in skeleton_lines:
            stripped = line.strip()
            if stripped.startswith("import ") or stripped.startswith("from "):
                continue
            skeleton_body.append(line)
        # Remove leading blank lines after stripping imports
        while skeleton_body and not skeleton_body[0].strip():
            skeleton_body.pop(0)
        solution_parts.append("\n".join(skeleton_body))
        solution_parts.append("")
        solution_py = "\n".join(solution_parts)

        # fixture/test_solution.py — imports + test classes + unittest.main
        test_parts = []
        # Add the entry's import statements so tests can reference them
        if imports:
            for imp in imports:
                test_parts.append(imp)
        test_code = entry.get("test", "").strip()
        # The test code typically starts with 'import unittest' — include as-is
        test_parts.append(test_code)
        test_parts.append("")
        # Add import of the class from solution
        # Insert the import right after 'import unittest' line
        test_content = "\n".join(test_parts)
        # Ensure the class is importable from solution.py
        import_from_solution = f"from solution import {class_name}"
        # Build final test file: stdlib imports, then import from solution, then test code
        final_test_lines = []
        if imports:
            for imp in imports:
                final_test_lines.append(imp)
        # The test code usually starts with 'import unittest'
        # Parse it to insert our import after the unittest import
        test_lines = test_code.split('\n')
        inserted = False
        for tl in test_lines:
            final_test_lines.append(tl)
            if not inserted and tl.strip().startswith("import unittest"):
                final_test_lines.append(import_from_solution)
                inserted = True
        if not inserted:
            # If no 'import unittest' found, prepend both
            final_test_lines = ["import unittest", import_from_solution] + final_test_lines
        final_test_lines.append("")
        final_test_lines.append('if __name__ == "__main__":')
        final_test_lines.append("    unittest.main()")
        final_test_lines.append("")
        test_solution_py = "\n".join(final_test_lines)

        # verify.sh
        verify_sh = _build_classeval_verify()

        # fixture files
        fixture_files = {
            "solution.py": solution_py,
            "test_solution.py": test_solution_py,
        }

        # Skip if task directory already exists
        task_dir = os.path.join(TASKS_DIR, name)
        if os.path.isdir(task_dir) and not args.dry_run:
            print(f"  Skipping {name} (already exists)")
            continue

        print(f"  {'[dry-run] ' if args.dry_run else ''}Creating {name} "
              f"(methods={num_methods}, difficulty={difficulty}, lines={sol_lines})")
        create_task_dir(name, task_json, prompt_md, verify_sh, fixture_files, dry_run=args.dry_run)
        created += 1

    print(f"\n{'Would create' if args.dry_run else 'Created'} {created} ClassEval tasks")


def _build_classeval_verify():
    """Build verify.sh for a ClassEval task using pytest."""
    return (
        '#!/usr/bin/env bash\n'
        'set -euo pipefail\n'
        'dir="$1"\n'
        'scorer="$(dirname "$0")/../../score-metrics.py"\n'
        '\n'
        'cd "$dir"\n'
        '\n'
        '# Check solution.py exists\n'
        'if [ ! -f "solution.py" ]; then\n'
        '\techo "FAIL: solution.py not found"\n'
        '\techo "SCORE:0"\n'
        '\texit 1\n'
        'fi\n'
        '\n'
        '# Run pytest\n'
        'output="$(python3 -m pytest test_solution.py -v 2>&1)" || true\n'
        'echo "$output"\n'
        '\n'
        '# Count PASSED and FAILED\n'
        'passed="$(echo "$output" | grep -c "PASSED" || true)"\n'
        'failed="$(echo "$output" | grep -c "FAILED" || true)"\n'
        'total=$(( passed + failed ))\n'
        '\n'
        '# Calculate score\n'
        'if [ "$total" -gt 0 ]; then\n'
        '\tscore=$(( passed * 100 / total ))\n'
        'else\n'
        '\tscore=0\n'
        'fi\n'
        '\n'
        '# Run shared metrics\n'
        'python3 "$scorer" "$dir" \'["solution.py", "test_solution.py"]\' "python" 2>/dev/null || true\n'
        '\n'
        'if [ "$passed" -eq "$total" ] && [ "$total" -gt 0 ]; then\n'
        '\techo "PASS"\n'
        '\techo "SCORE:$score"\n'
        '\texit 0\n'
        'else\n'
        '\techo "FAIL: $passed/$total tests passed"\n'
        '\techo "SCORE:$score"\n'
        '\texit 1\n'
        'fi\n'
    )


def import_refactoring(args):
    """Import tasks from Aider refactoring benchmarks."""
    raise NotImplementedError("Refactoring importer not yet implemented")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

IMPORTERS = {
    "humaneval": import_humaneval,
    "mbpp": import_mbpp,
    "exercism": import_exercism,
    "classeval": import_classeval,
    "refactoring": import_refactoring,
}


def main():
    parser = argparse.ArgumentParser(
        description="Import benchmark tasks from public coding-challenge datasets"
    )
    parser.add_argument(
        "--source",
        required=True,
        choices=sorted(IMPORTERS.keys()),
        help="Dataset source to import from",
    )
    parser.add_argument(
        "--filter",
        default=None,
        help="Comma-separated task IDs to import (e.g. '2,5,10')",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be created without writing files",
    )
    parser.add_argument(
        "--max",
        type=int,
        default=None,
        help="Maximum number of tasks to import",
    )

    args = parser.parse_args()

    print(f"Importing from: {args.source}")
    if args.dry_run:
        print("DRY RUN — no files will be written")

    IMPORTERS[args.source](args)


if __name__ == "__main__":
    main()
