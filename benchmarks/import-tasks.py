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
    if num_lines <= 5:
        return "trivial"
    elif num_lines <= 10:
        return "basic"
    elif num_lines <= 20:
        return "intermediate"
    elif num_lines <= 35:
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
                "entry_point": entry_point
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
        solution_py = prompt_code.rstrip() + "\n    pass\n"

        # fixture/test_solution.py
        test_solution_py = _build_he_test(entry_point, test_code, prompt_code)

        # verify.sh
        verify_sh = _build_he_verify()

        # fixture files
        fixture_files = {
            "solution.py": solution_py,
            "test_solution.py": test_solution_py,
        }

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

    # Add the test code as-is
    lines.append(test_code.rstrip())
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
    raise NotImplementedError("MBPP importer not yet implemented")


def import_exercism(args):
    """Import tasks from Exercism Python track."""
    raise NotImplementedError("Exercism importer not yet implemented")


def import_classeval(args):
    """Import tasks from ClassEval dataset."""
    raise NotImplementedError("ClassEval importer not yet implemented")


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
