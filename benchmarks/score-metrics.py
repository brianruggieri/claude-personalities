#!/usr/bin/env python3
"""Shared code quality metrics scorer for benchmark verify.sh scripts.

Usage: python3 score-metrics.py <workdir> <expected_files_json> [<language>]

Outputs KEY:VALUE lines that the benchmark runner extracts.
Always exits 0 — metrics are advisory, not pass/fail.

Metrics emitted:
  FILES_EXTRA:<n>         — files created beyond expected list
  LINES_GENERATED:<n>     — total lines in generated/modified files
  LINT_ISSUES:<n>         — syntax/style issues found
  COMPLEXITY_AVG:<n>      — average cyclomatic complexity per function
  COMPLEXITY_MAX:<n>      — max cyclomatic complexity of any single function
  MAX_FUNCTION_LENGTH:<n> — longest function in lines
  FUNCTIONS_OVER_50:<n>   — functions exceeding 50-line limit
"""
import ast
import json
import os
import py_compile
import sys
import tempfile


def discover_files(workdir, extensions):
    """Find all files with given extensions, excluding hidden/internal files."""
    found = []
    for root, dirs, files in os.walk(workdir):
        dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
        for f in files:
            if any(f.endswith(ext) for ext in extensions):
                found.append(os.path.join(root, f))
    return found


def count_extra_files(workdir, expected_files):
    """Count files beyond the expected list."""
    all_files = []
    for root, dirs, files in os.walk(workdir):
        dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), workdir)
            all_files.append(rel)

    expected_set = set(expected_files)
    extra = [f for f in all_files if f not in expected_set]
    return len(extra), extra


def count_lines(workdir, extensions):
    """Count total lines across files with given extensions."""
    total = 0
    for fpath in discover_files(workdir, extensions):
        try:
            with open(fpath) as f:
                total += sum(1 for _ in f)
        except Exception:
            pass
    return total


def python_lint_issues(workdir):
    """Check Python files for syntax errors and basic style issues."""
    issues = 0
    for fpath in discover_files(workdir, ['.py']):
        # Syntax check
        try:
            py_compile.compile(fpath, doraise=True)
        except py_compile.PyCompileError:
            issues += 1
            continue

        # Basic style checks via AST
        try:
            with open(fpath) as f:
                source = f.read()
            tree = ast.parse(source)

            for node in ast.walk(tree):
                # Bare except
                if isinstance(node, ast.ExceptHandler) and node.type is None:
                    issues += 1
                # Single-letter variable names in assignments (excluding loop vars)
                if isinstance(node, ast.Assign):
                    for target in node.targets:
                        if isinstance(target, ast.Name) and len(target.id) == 1:
                            if target.id not in ('_', 'i', 'j', 'k', 'n', 'x', 'y'):
                                issues += 1
        except Exception:
            pass
    return issues


def jsx_lint_issues(workdir):
    """Basic lint checks for JSX files (no external tools)."""
    issues = 0
    for fpath in discover_files(workdir, ['.jsx', '.js', '.tsx', '.ts']):
        try:
            with open(fpath) as f:
                content = f.read()
            lines = content.split('\n')
            for line in lines:
                stripped = line.strip()
                # console.log left in
                if 'console.log' in stripped:
                    issues += 1
                # var usage (should be let/const)
                if stripped.startswith('var '):
                    issues += 1
                # dangerouslySetInnerHTML
                if 'dangerouslySetInnerHTML' in stripped:
                    issues += 1
        except Exception:
            pass
    return issues


def python_complexity(workdir):
    """Compute cyclomatic complexity for Python files using AST.

    Cyclomatic complexity = 1 + number of decision points per function.
    Decision points: if, elif, for, while, except, and, or, assert, with,
    ternary (IfExp), comprehension conditions.
    """
    complexities = []
    max_func_length = 0
    funcs_over_50 = 0

    for fpath in discover_files(workdir, ['.py']):
        try:
            with open(fpath) as f:
                source = f.read()
            tree = ast.parse(source)
            lines = source.split('\n')
        except Exception:
            continue

        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                # Complexity
                cc = 1
                for child in ast.walk(node):
                    if isinstance(child, (ast.If, ast.IfExp)):
                        cc += 1
                    elif isinstance(child, ast.For):
                        cc += 1
                    elif isinstance(child, ast.While):
                        cc += 1
                    elif isinstance(child, ast.ExceptHandler):
                        cc += 1
                    elif isinstance(child, ast.Assert):
                        cc += 1
                    elif isinstance(child, ast.With):
                        cc += 1
                    elif isinstance(child, ast.BoolOp):
                        # and/or each add a branch
                        cc += len(child.values) - 1
                complexities.append(cc)

                # Function length
                if hasattr(node, 'end_lineno') and hasattr(node, 'lineno'):
                    func_len = node.end_lineno - node.lineno + 1
                else:
                    func_len = 0
                if func_len > max_func_length:
                    max_func_length = func_len
                if func_len > 50:
                    funcs_over_50 += 1

    avg_complexity = sum(complexities) / len(complexities) if complexities else 0
    max_complexity = max(complexities) if complexities else 0

    return round(avg_complexity, 1), max_complexity, max_func_length, funcs_over_50


try:
    workdir = sys.argv[1]
    expected_files = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
    language = sys.argv[3] if len(sys.argv) > 3 else 'python'

    # Extra files
    extra_count, extra_list = count_extra_files(workdir, expected_files)
    print(f'FILES_EXTRA:{extra_count}')

    # Lines generated
    if language == 'python':
        lines = count_lines(workdir, ['.py'])
    elif language in ('jsx', 'javascript', 'react'):
        lines = count_lines(workdir, ['.jsx', '.js', '.tsx', '.ts'])
    else:
        lines = count_lines(workdir, ['.py', '.js', '.jsx', '.ts', '.tsx', '.sh', '.md'])
    print(f'LINES_GENERATED:{lines}')

    # Lint issues
    if language == 'python':
        lint = python_lint_issues(workdir)
    elif language in ('jsx', 'javascript', 'react'):
        lint = jsx_lint_issues(workdir)
    else:
        lint = 0
    print(f'LINT_ISSUES:{lint}')

    # Complexity (Python only for now)
    if language == 'python':
        avg_cc, max_cc, max_func_len, over_50 = python_complexity(workdir)
    else:
        avg_cc, max_cc, max_func_len, over_50 = 0, 0, 0, 0
    print(f'COMPLEXITY_AVG:{avg_cc}')
    print(f'COMPLEXITY_MAX:{max_cc}')
    print(f'MAX_FUNCTION_LENGTH:{max_func_len}')
    print(f'FUNCTIONS_OVER_50:{over_50}')

except Exception:
    # Always exit 0 — metrics are advisory
    print('FILES_EXTRA:0')
    print('LINES_GENERATED:0')
    print('LINT_ISSUES:0')
    print('COMPLEXITY_AVG:0')
    print('COMPLEXITY_MAX:0')
    print('MAX_FUNCTION_LENGTH:0')
    print('FUNCTIONS_OVER_50:0')
