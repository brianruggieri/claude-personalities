# Tier 3 Code Quality Metrics — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Add five opt-in code quality analyzers to the benchmark system that evaluate generated code beyond pass/fail: LLM-as-judge scoring, over-engineering detection, security smell detection, naming quality analysis, and regression detection.

**Architecture:** Each metric is a standalone Python3 script in `benchmarks/analyzers/` that reads generated code from the benchmark tmpdir and outputs key-value metrics to stdout (`KEY:value` format). The benchmark runner (`_benchmark_run_task` in setup.sh) calls each enabled analyzer after verify.sh, merges their output into the result JSON. Analyzers are opt-in via `--quality-judge` (expensive LLM call) or always-on (cheap static analysis). Per-task expected complexity is defined in a new `complexity` field in task.json.

**Tech Stack:** Bash (setup.sh), Python3 stdlib (ast, re, json, os, sys, subprocess), Claude CLI (`claude -p` for LLM-as-judge only)

---

## Prerequisite

```bash
git branch --show-current  # must be "opinionated"
```

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `benchmarks/analyzers/security_smells.py` | Create | Grep-based security smell detector |
| `benchmarks/analyzers/naming_quality.py` | Create | AST-based naming analysis for Python files |
| `benchmarks/analyzers/overengineering.py` | Create | Counts classes/functions vs. task expected complexity |
| `benchmarks/analyzers/regression_check.py` | Create | Runs full test suite for fix-python-bug |
| `benchmarks/analyzers/llm_judge.py` | Create | Calls `claude -p` to score code quality |
| `benchmarks/analyzers/rubric.md` | Create | Rubric prompt for LLM-as-judge |
| `benchmarks/tasks/*/task.json` | Modify | Add `expected_complexity` field |
| `setup.sh` | Modify | Wire analyzers into `_benchmark_run_task`, add `--quality-judge` flag |

---

## Chunk 1: Static Analyzers (always-on, zero cost)

### Task 1: Security smell detector

Scans all generated files for common security anti-patterns. Language-agnostic grep-based approach.

**Files:**
- Create: `benchmarks/analyzers/security_smells.py`

- [ ] **Step 1: Create the analyzer**

```python
#!/usr/bin/env python3
"""Scan generated files for security anti-patterns.

Usage: python3 security_smells.py <dir> [<extensions>]
Output: SECURITY_SMELLS:<count>
        SECURITY_SMELL_DETAILS:<semicolon-separated list>

Extensions default to .py,.js,.jsx,.ts,.tsx
Always exits 0.
"""
import os
import re
import sys

PATTERNS = [
    ("eval_call", re.compile(r'\beval\s*\(')),
    ("exec_call", re.compile(r'\bexec\s*\(')),
    ("dangerous_inner_html", re.compile(r'dangerouslySetInnerHTML')),
    ("hardcoded_password", re.compile(
        r'''(?:password|passwd|secret|api_key|token)\s*=\s*['"][^'"]{3,}['"]''',
        re.IGNORECASE,
    )),
    ("http_no_tls", re.compile(r'''['"]http://(?!localhost|127\.0\.0\.1|0\.0\.0\.0)''')),
    ("sql_string_concat", re.compile(r'''f['"]\s*(?:SELECT|INSERT|UPDATE|DELETE)\b''')),
    ("sql_format_concat", re.compile(
        r'''(?:SELECT|INSERT|UPDATE|DELETE)\b.*\.format\s*\('''
    )),
    ("sql_percent_concat", re.compile(
        r'''(?:SELECT|INSERT|UPDATE|DELETE)\b.*%\s*\('''
    )),
    ("shell_injection", re.compile(r'os\.system\s*\(|subprocess\.call\s*\(\s*["\']')),
    ("pickle_load", re.compile(r'pickle\.loads?\s*\(')),
]

DEFAULT_EXTENSIONS = {'.py', '.js', '.jsx', '.ts', '.tsx', '.rb', '.go', '.java'}


def scan_file(filepath):
    """Return list of (pattern_name, line_number) for matches."""
    findings = []
    try:
        with open(filepath, 'r', errors='replace') as f:
            for lineno, line in enumerate(f, 1):
                for name, pattern in PATTERNS:
                    if pattern.search(line):
                        findings.append((name, lineno))
    except (OSError, UnicodeDecodeError):
        pass
    return findings


def main():
    try:
        target_dir = sys.argv[1]
        if len(sys.argv) > 2:
            extensions = set('.' + e.lstrip('.') for e in sys.argv[2].split(','))
        else:
            extensions = DEFAULT_EXTENSIONS

        all_findings = []
        for root, _dirs, files in os.walk(target_dir):
            # Skip hidden dirs and _expected
            if any(part.startswith('.') or part.startswith('_') for part in root.split(os.sep)):
                if root != target_dir:
                    continue
            for fname in files:
                _, ext = os.path.splitext(fname)
                if ext not in extensions:
                    continue
                filepath = os.path.join(root, fname)
                findings = scan_file(filepath)
                for name, lineno in findings:
                    rel = os.path.relpath(filepath, target_dir)
                    all_findings.append(f"{name}:{rel}:{lineno}")

        print(f"SECURITY_SMELLS:{len(all_findings)}")
        if all_findings:
            print(f"SECURITY_SMELL_DETAILS:{';'.join(all_findings)}")
    except Exception:
        print("SECURITY_SMELLS:0")

    sys.exit(0)


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Test the analyzer against review-code-diff fixture**

The diff.patch itself is not scannable (it is a patch, not source), but we can test against a Python file with known smells:

```bash
cd ~/git/claude_personalities

# Create a temp test file with known smells
tmpdir=$(mktemp -d)
cat > "$tmpdir/bad.py" << 'EOF'
import os
DB_PASSWORD = "admin123"
query = f"SELECT * FROM users WHERE id = '{user_id}'"
os.system("rm -rf /tmp/cache")
result = eval(user_input)
EOF

python3 benchmarks/analyzers/security_smells.py "$tmpdir"
# Expected: SECURITY_SMELLS:4
# (hardcoded_password, sql_string_concat, shell_injection, eval_call)

rm -r "$tmpdir"
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/analyzers/security_smells.py
git commit -m "Add security smell detector for benchmark quality metrics"
```

---

### Task 2: Naming quality analyzer

Uses Python3 `ast` module to extract variable, function, and class names from generated Python files. Checks against a blocklist of generic names and verifies naming convention consistency (snake_case for functions/vars, PascalCase for classes).

**Files:**
- Create: `benchmarks/analyzers/naming_quality.py`

- [ ] **Step 1: Create the analyzer**

```python
#!/usr/bin/env python3
"""AST-based naming quality analysis for Python files.

Usage: python3 naming_quality.py <dir>
Output: NAMING_SCORE:<0-100>
        NAMING_GENERIC_COUNT:<count>
        NAMING_CONVENTION_VIOLATIONS:<count>
        NAMING_DETAILS:<semicolon-separated list>

Always exits 0.
"""
import ast
import os
import re
import sys

GENERIC_BLOCKLIST = frozenset({
    'data', 'result', 'results', 'temp', 'tmp', 'obj', 'val', 'value',
    'x', 'y', 'z', 'a', 'b', 'c', 'd', 'e', 'f', 'g',
    'foo', 'bar', 'baz', 'thing', 'stuff', 'item', 'items',
    'ret', 'res', 'out', 'output', 'inp', 'input',
    'var', 'var1', 'var2', 'str1', 'str2', 'list1', 'list2',
    'df', 'info', 'flag', 'count',
})

# Single-char names are OK in comprehensions and lambdas — tracked separately
COMPREHENSION_OK = frozenset({'i', 'j', 'k', 'n', 'v', 'x', 'y', 'z', '_'})

SNAKE_CASE_RE = re.compile(r'^_?[a-z][a-z0-9_]*$')
PASCAL_CASE_RE = re.compile(r'^[A-Z][a-zA-Z0-9]*$')
UPPER_SNAKE_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')


class NameExtractor(ast.NodeVisitor):
    """Walk the AST and collect names with their kind."""

    def __init__(self):
        self.names = []  # (name, kind, lineno)

    def visit_FunctionDef(self, node):
        self.names.append((node.name, 'function', node.lineno))
        # Visit arguments
        for arg in node.args.args:
            if arg.arg != 'self' and arg.arg != 'cls':
                self.names.append((arg.arg, 'parameter', node.lineno))
        self.generic_visit(node)

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_ClassDef(self, node):
        self.names.append((node.name, 'class', node.lineno))
        self.generic_visit(node)

    def visit_Name(self, node):
        if isinstance(node.ctx, ast.Store):
            self.names.append((node.id, 'variable', node.lineno))
        self.generic_visit(node)


def check_convention(name, kind):
    """Return True if name follows the expected convention for its kind."""
    if name.startswith('_'):
        check_name = name.lstrip('_')
        if not check_name:
            return True  # bare underscore is OK
    else:
        check_name = name

    if kind == 'class':
        return bool(PASCAL_CASE_RE.match(check_name))
    if kind in ('function', 'parameter', 'variable'):
        # Allow UPPER_SNAKE for module-level constants
        return bool(SNAKE_CASE_RE.match(name) or UPPER_SNAKE_RE.match(name))
    return True


def analyze_file(filepath):
    """Return (generic_names, convention_violations) lists."""
    generic = []
    violations = []

    try:
        with open(filepath, 'r') as f:
            source = f.read()
        tree = ast.parse(source, filename=filepath)
    except (SyntaxError, OSError):
        return generic, violations

    extractor = NameExtractor()
    extractor.visit(tree)

    seen = set()
    for name, kind, lineno in extractor.names:
        key = (name, kind)
        if key in seen:
            continue
        seen.add(key)

        # Skip dunder methods
        if name.startswith('__') and name.endswith('__'):
            continue

        # Generic name check (skip single-char in comprehension context)
        if name.lower() in GENERIC_BLOCKLIST and len(name) > 1:
            generic.append(f"{name}:{kind}:L{lineno}")

        # Convention check
        if not check_convention(name, kind):
            violations.append(f"{name}:{kind}:L{lineno}")

    return generic, violations


def main():
    try:
        target_dir = sys.argv[1]
        total_generic = []
        total_violations = []
        total_names = 0

        for root, _dirs, files in os.walk(target_dir):
            for fname in files:
                if not fname.endswith('.py'):
                    continue
                # Skip test files and hidden/internal files
                if fname.startswith('_') or fname.startswith('.'):
                    continue
                filepath = os.path.join(root, fname)
                generic, violations = analyze_file(filepath)
                total_generic.extend(generic)
                total_violations.extend(violations)

                # Count total names for scoring
                try:
                    with open(filepath, 'r') as f:
                        tree = ast.parse(f.read())
                    ext = NameExtractor()
                    ext.visit(tree)
                    total_names += len(set(
                        (n, k) for n, k, _ in ext.names
                        if not (n.startswith('__') and n.endswith('__'))
                    ))
                except Exception:
                    pass

        # Score: start at 100, deduct 10 per generic name, 5 per convention violation
        # Floor at 0
        deductions = len(total_generic) * 10 + len(total_violations) * 5
        score = max(0, 100 - deductions)

        print(f"NAMING_SCORE:{score}")
        print(f"NAMING_GENERIC_COUNT:{len(total_generic)}")
        print(f"NAMING_CONVENTION_VIOLATIONS:{len(total_violations)}")
        if total_generic or total_violations:
            details = total_generic + [f"CONVENTION:{v}" for v in total_violations]
            print(f"NAMING_DETAILS:{';'.join(details)}")
    except Exception:
        print("NAMING_SCORE:100")
        print("NAMING_GENERIC_COUNT:0")
        print("NAMING_CONVENTION_VIOLATIONS:0")

    sys.exit(0)


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Test against the write-unit-tests fixture**

```bash
cd ~/git/claude_personalities
python3 benchmarks/analyzers/naming_quality.py benchmarks/tasks/write-unit-tests/fixture
# Expected: NAMING_SCORE close to 100 (validators.py uses good names)
```

- [ ] **Step 3: Test against intentionally bad naming**

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/bad_names.py" << 'EOF'
def DoSomething(data, result, temp):
    x = data + result
    obj = temp
    return obj
class my_class:
    pass
EOF

python3 benchmarks/analyzers/naming_quality.py "$tmpdir"
# Expected: NAMING_SCORE < 50, multiple generic names flagged, convention violations for DoSomething and my_class

rm -r "$tmpdir"
```

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/naming_quality.py
git commit -m "Add AST-based naming quality analyzer for Python files"
```

---

### Task 3: Over-engineering detector

Counts structural complexity in generated code (classes, functions, files created) and compares against expected complexity defined in task.json. Flags factory functions, abstract base classes, and config files in simple tasks.

**Files:**
- Create: `benchmarks/analyzers/overengineering.py`
- Modify: `benchmarks/tasks/*/task.json` — add `expected_complexity` field

- [ ] **Step 1: Add `expected_complexity` to each task.json**

Update each task.json to include an `expected_complexity` object. This defines the maximum reasonable counts for a correct solution.

`benchmarks/tasks/hello-world/task.json`:
```json
{
  "name": "hello-world",
  "description": "Baseline cost measurement — respond with a specific string",
  "category": "baseline",
  "capability": null,
  "difficulty": "trivial",
  "timeout": 30,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"],
  "expected_complexity": {
    "max_files": 1,
    "max_classes": 0,
    "max_functions": 0,
    "max_lines": 5,
    "disallow_patterns": ["class ", "def ", "import ", "from "]
  }
}
```

`benchmarks/tasks/fix-python-bug/task.json`:
```json
{
  "name": "fix-python-bug",
  "description": "Fix a failing test in a small Python project",
  "category": "debugging",
  "capability": "tdd-workflow",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"],
  "expected_complexity": {
    "max_files": 2,
    "max_classes": 0,
    "max_functions": 3,
    "max_lines": 30,
    "disallow_patterns": ["ABC", "abstractmethod", "Factory", "config.json", "config.yaml"]
  }
}
```

`benchmarks/tasks/create-react-component/task.json`:
```json
{
  "name": "create-react-component",
  "description": "Create a React component from a design specification",
  "category": "frontend",
  "capability": "frontend-design",
  "difficulty": "basic",
  "timeout": 180,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"],
  "expected_complexity": {
    "max_files": 2,
    "max_classes": 1,
    "max_functions": 3,
    "max_lines": 50,
    "disallow_patterns": ["Factory", "AbstractBase", "config.json"]
  }
}
```

`benchmarks/tasks/write-unit-tests/task.json`:
```json
{
  "name": "write-unit-tests",
  "description": "Write comprehensive unit tests for an untested Python module",
  "category": "testing",
  "capability": "tdd-workflow",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"],
  "expected_complexity": {
    "max_files": 2,
    "max_classes": 2,
    "max_functions": 20,
    "max_lines": 200,
    "disallow_patterns": ["Factory", "AbstractBase", "config.json", "conftest.py"]
  }
}
```

`benchmarks/tasks/review-code-diff/task.json`:
```json
{
  "name": "review-code-diff",
  "description": "Review a code diff and identify security and quality issues",
  "category": "review",
  "capability": "code-review",
  "difficulty": "basic",
  "timeout": 120,
  "scoring": "binary",
  "metrics": ["correctness", "cost", "duration", "token_efficiency"],
  "expected_complexity": {
    "max_files": 1,
    "max_classes": 0,
    "max_functions": 0,
    "max_lines": 100,
    "disallow_patterns": []
  }
}
```

- [ ] **Step 2: Create the over-engineering detector**

```python
#!/usr/bin/env python3
"""Detect over-engineering in benchmark task output.

Usage: python3 overengineering.py <dir> <task_json_path>
Output: OVERENGINEERING_SCORE:<0-100>  (100 = no over-engineering)
        OVERENGINEERING_EXCESS_FILES:<count>
        OVERENGINEERING_EXCESS_CLASSES:<count>
        OVERENGINEERING_EXCESS_FUNCTIONS:<count>
        OVERENGINEERING_EXCESS_LINES:<count>
        OVERENGINEERING_DISALLOWED:<semicolon-separated list>

Always exits 0.
"""
import ast
import json
import os
import re
import sys

FIXTURE_FILES = frozenset()  # populated at runtime
SKIP_PREFIXES = ('.', '_')
SKIP_FILES = frozenset({
    '_claude_output.json', '_expected',
})


def count_python_constructs(filepath):
    """Count classes and function definitions in a Python file."""
    classes = 0
    functions = 0
    try:
        with open(filepath, 'r') as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                classes += 1
            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions += 1
    except (SyntaxError, OSError):
        pass
    return classes, functions


def count_js_constructs(filepath):
    """Regex-based count of classes and functions in JS/JSX/TS files."""
    classes = 0
    functions = 0
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        classes = len(re.findall(r'\bclass\s+\w+', content))
        functions = len(re.findall(
            r'(?:function\s+\w+|(?:const|let|var)\s+\w+\s*=\s*(?:\([^)]*\)|[^=])\s*=>|'
            r'(?:const|let|var)\s+\w+\s*=\s*function)',
            content,
        ))
    except (OSError, UnicodeDecodeError):
        pass
    return classes, functions


def count_lines(filepath):
    """Count non-empty, non-comment lines."""
    count = 0
    try:
        with open(filepath, 'r', errors='replace') as f:
            for line in f:
                stripped = line.strip()
                if stripped and not stripped.startswith('#') and not stripped.startswith('//'):
                    count += 1
    except OSError:
        pass
    return count


def check_disallowed(filepath, patterns):
    """Check if file contains any disallowed patterns."""
    found = []
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read()
        for pattern in patterns:
            if pattern in content:
                rel = os.path.basename(filepath)
                found.append(f"{pattern} in {rel}")
    except OSError:
        pass
    return found


def main():
    try:
        target_dir = sys.argv[1]
        task_json_path = sys.argv[2]

        # Load expected complexity
        with open(task_json_path, 'r') as f:
            task = json.load(f)

        complexity = task.get('expected_complexity', {})
        max_files = complexity.get('max_files', 10)
        max_classes = complexity.get('max_classes', 5)
        max_functions = complexity.get('max_functions', 10)
        max_lines = complexity.get('max_lines', 200)
        disallow_patterns = complexity.get('disallow_patterns', [])

        # Identify fixture files (don't count these as "generated")
        fixture_names = set()
        fixture_dir = os.path.join(os.path.dirname(task_json_path), 'fixture')
        if os.path.isdir(fixture_dir):
            for fname in os.listdir(fixture_dir):
                fixture_names.add(fname)

        # Scan generated files
        generated_files = []
        total_classes = 0
        total_functions = 0
        total_lines = 0
        all_disallowed = []

        for fname in os.listdir(target_dir):
            if fname in SKIP_FILES or fname in fixture_names:
                continue
            if any(fname.startswith(p) for p in SKIP_PREFIXES):
                continue

            filepath = os.path.join(target_dir, fname)
            if not os.path.isfile(filepath):
                continue

            generated_files.append(fname)
            total_lines += count_lines(filepath)

            _, ext = os.path.splitext(fname)
            if ext == '.py':
                c, fn = count_python_constructs(filepath)
                total_classes += c
                total_functions += fn
            elif ext in ('.js', '.jsx', '.ts', '.tsx'):
                c, fn = count_js_constructs(filepath)
                total_classes += c
                total_functions += fn

            if disallow_patterns:
                all_disallowed.extend(check_disallowed(filepath, disallow_patterns))

        # Also check for disallowed filenames
        for fname in generated_files:
            for pattern in disallow_patterns:
                if fname == pattern:
                    all_disallowed.append(f"file:{fname}")

        # Calculate excess
        excess_files = max(0, len(generated_files) - max_files)
        excess_classes = max(0, total_classes - max_classes)
        excess_functions = max(0, total_functions - max_functions)
        excess_lines = max(0, total_lines - max_lines)

        # Score: start at 100, deduct per excess
        deductions = (
            excess_files * 15
            + excess_classes * 20
            + excess_functions * 5
            + (excess_lines // 10) * 2
            + len(all_disallowed) * 25
        )
        score = max(0, 100 - deductions)

        print(f"OVERENGINEERING_SCORE:{score}")
        print(f"OVERENGINEERING_EXCESS_FILES:{excess_files}")
        print(f"OVERENGINEERING_EXCESS_CLASSES:{excess_classes}")
        print(f"OVERENGINEERING_EXCESS_FUNCTIONS:{excess_functions}")
        print(f"OVERENGINEERING_EXCESS_LINES:{excess_lines}")
        if all_disallowed:
            print(f"OVERENGINEERING_DISALLOWED:{';'.join(all_disallowed)}")

    except Exception:
        print("OVERENGINEERING_SCORE:100")
        print("OVERENGINEERING_EXCESS_FILES:0")
        print("OVERENGINEERING_EXCESS_CLASSES:0")
        print("OVERENGINEERING_EXCESS_FUNCTIONS:0")
        print("OVERENGINEERING_EXCESS_LINES:0")

    sys.exit(0)


if __name__ == '__main__':
    main()
```

- [ ] **Step 3: Test over-engineering detection**

```bash
cd ~/git/claude_personalities

# Test against a clean hello-world output (should score 100)
tmpdir=$(mktemp -d)
echo "Hello from Claude Code" > "$tmpdir/output.txt"
python3 benchmarks/analyzers/overengineering.py "$tmpdir" benchmarks/tasks/hello-world/task.json
# Expected: OVERENGINEERING_SCORE:100, all excess counts 0

rm -r "$tmpdir"

# Test against an over-engineered hello-world (should score low)
tmpdir=$(mktemp -d)
cat > "$tmpdir/output.txt" << 'EOF'
Hello from Claude Code
EOF
cat > "$tmpdir/hello_factory.py" << 'EOF'
from abc import ABC, abstractmethod
class AbstractGreeter(ABC):
    @abstractmethod
    def greet(self): pass
class HelloGreeter(AbstractGreeter):
    def greet(self):
        return "Hello from Claude Code"
class GreeterFactory:
    @staticmethod
    def create(kind="hello"):
        if kind == "hello":
            return HelloGreeter()
EOF
cat > "$tmpdir/config.json" << 'EOF'
{"greeting": "Hello from Claude Code"}
EOF

python3 benchmarks/analyzers/overengineering.py "$tmpdir" benchmarks/tasks/hello-world/task.json
# Expected: OVERENGINEERING_SCORE low, excess files/classes/functions flagged

rm -r "$tmpdir"
```

- [ ] **Step 4: Commit**

```bash
git add benchmarks/analyzers/overengineering.py benchmarks/tasks/*/task.json
git commit -m "Add over-engineering detector and expected_complexity to task.json"
```

---

### Task 4: Regression detector for fix-python-bug

For the fix-python-bug task, runs ALL tests (not just the target ones) to verify no pre-existing passing tests were broken. This catches the case where Claude "fixes" the bug by breaking other tests or changing test assertions.

**Files:**
- Create: `benchmarks/analyzers/regression_check.py`

- [ ] **Step 1: Create the regression checker**

```python
#!/usr/bin/env python3
"""Run full test suite and detect regressions in fix-python-bug task.

Usage: python3 regression_check.py <dir> <fixture_dir>
Output: REGRESSION_SCORE:<0-100>
        REGRESSION_TESTS_TOTAL:<count>
        REGRESSION_TESTS_PASSED:<count>
        REGRESSION_TESTS_FAILED:<count>
        REGRESSION_PREEXISTING_BROKEN:<count>
        REGRESSION_DETAILS:<semicolon-separated list>

Compares test results before and after the fix:
1. Runs tests against the original fixture to identify which tests already pass
2. Runs tests against the fixed code to verify nothing regressed

Always exits 0.
"""
import json
import os
import subprocess
import sys
import tempfile
import shutil


def run_pytest(directory):
    """Run pytest and return (total, passed, failed, test_names_passed, test_names_failed)."""
    try:
        result = subprocess.run(
            [sys.executable, '-m', 'pytest', '-v', '--tb=no', '-q'],
            capture_output=True, text=True, timeout=30, cwd=directory,
        )
        output = result.stdout + result.stderr

        passed = set()
        failed = set()
        for line in output.split('\n'):
            if '::' in line:
                if ' PASSED' in line:
                    test_name = line.split(' PASSED')[0].strip()
                    passed.add(test_name)
                elif ' FAILED' in line:
                    test_name = line.split(' FAILED')[0].strip()
                    failed.add(test_name)

        return len(passed) + len(failed), passed, failed
    except Exception:
        return 0, set(), set()


def main():
    try:
        target_dir = sys.argv[1]
        fixture_dir = sys.argv[2]

        # Step 1: Run tests against original fixture (to find pre-existing passes)
        pre_tmpdir = tempfile.mkdtemp()
        try:
            for fname in os.listdir(fixture_dir):
                src = os.path.join(fixture_dir, fname)
                if os.path.isfile(src):
                    shutil.copy2(src, os.path.join(pre_tmpdir, fname))

            _, pre_passed, pre_failed = run_pytest(pre_tmpdir)
        finally:
            shutil.rmtree(pre_tmpdir, ignore_errors=True)

        # Step 2: Run tests against fixed code
        post_total, post_passed, post_failed = run_pytest(target_dir)

        # Step 3: Identify regressions (tests that passed before but fail now)
        regressions = pre_passed - post_passed
        newly_fixed = post_passed - pre_passed

        score = 100
        details = []

        if regressions:
            # Each regression deducts 25 points
            score = max(0, 100 - len(regressions) * 25)
            for test in sorted(regressions):
                details.append(f"REGRESSED:{test}")

        print(f"REGRESSION_SCORE:{score}")
        print(f"REGRESSION_TESTS_TOTAL:{post_total}")
        print(f"REGRESSION_TESTS_PASSED:{len(post_passed)}")
        print(f"REGRESSION_TESTS_FAILED:{len(post_failed)}")
        print(f"REGRESSION_PREEXISTING_BROKEN:{len(regressions)}")
        if details:
            print(f"REGRESSION_DETAILS:{';'.join(details)}")

    except Exception:
        print("REGRESSION_SCORE:100")
        print("REGRESSION_TESTS_TOTAL:0")
        print("REGRESSION_TESTS_PASSED:0")
        print("REGRESSION_TESTS_FAILED:0")
        print("REGRESSION_PREEXISTING_BROKEN:0")

    sys.exit(0)


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Test with the fixture**

```bash
cd ~/git/claude_personalities

# Test against the unmodified fixture (bug still present)
python3 benchmarks/analyzers/regression_check.py \
    benchmarks/tasks/fix-python-bug/fixture \
    benchmarks/tasks/fix-python-bug/fixture
# Expected: REGRESSION_SCORE:100 (no regressions — same code, same results)

# Test with a "fix" that breaks other tests
tmpdir=$(mktemp -d)
cp benchmarks/tasks/fix-python-bug/fixture/* "$tmpdir/"
# "Fix" average by hardcoding return value (breaks test_average_single)
cat > "$tmpdir/calculator.py" << 'EOF'
def add(a, b):
    return a + b

def divide(a, b):
    return a / b

def average(numbers):
    return 20.0
EOF

python3 benchmarks/analyzers/regression_check.py "$tmpdir" \
    benchmarks/tasks/fix-python-bug/fixture
# Expected: REGRESSION_SCORE < 100 if any pre-passing test now fails

rm -r "$tmpdir"
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/analyzers/regression_check.py
git commit -m "Add regression detector for fix-python-bug benchmark"
```

---

## Chunk 2: LLM-as-Judge (opt-in, expensive)

### Task 5: LLM-as-judge quality scorer

Uses a second `claude -p` call to evaluate generated code against a structured rubric. Opt-in via `--quality-judge` flag because it doubles benchmark cost.

**Files:**
- Create: `benchmarks/analyzers/rubric.md`
- Create: `benchmarks/analyzers/llm_judge.py`

- [ ] **Step 1: Create the rubric prompt**

```markdown
You are a code quality judge. Evaluate the following code against these five dimensions.
Score each dimension 1-10, where 1 is terrible and 10 is perfect.

## Dimensions

1. **Readability** — Is the code easy to understand at a glance? Good formatting, clear structure, logical flow?
2. **Naming Quality** — Are variables, functions, and classes named descriptively? Do names convey intent?
3. **Error Handling** — Does the code handle edge cases? Are errors caught and reported with useful messages?
4. **Idiomatic Usage** — Does the code use language features appropriately? Does it follow community conventions?
5. **Appropriate Abstraction** — Is the level of abstraction right for the task? Not too simple, not over-engineered?

## Task Context

Task: {task_name}
Description: {task_description}
Difficulty: {task_difficulty}

## Code to Evaluate

{code_content}

## Required Output Format

Respond with ONLY a JSON object, no other text:

```json
{
  "readability": <1-10>,
  "naming_quality": <1-10>,
  "error_handling": <1-10>,
  "idiomatic_usage": <1-10>,
  "appropriate_abstraction": <1-10>,
  "overall": <1-10>,
  "rationale": "<one sentence summary>"
}
```
```

- [ ] **Step 2: Create the LLM judge analyzer**

```python
#!/usr/bin/env python3
"""Use Claude as a judge to score code quality.

Usage: python3 llm_judge.py <dir> <task_json_path> <rubric_path>
Output: LLM_JUDGE_SCORE:<0-100>  (overall * 10)
        LLM_JUDGE_READABILITY:<1-10>
        LLM_JUDGE_NAMING:<1-10>
        LLM_JUDGE_ERROR_HANDLING:<1-10>
        LLM_JUDGE_IDIOMATIC:<1-10>
        LLM_JUDGE_ABSTRACTION:<1-10>
        LLM_JUDGE_RATIONALE:<text>
        LLM_JUDGE_COST:<usd>

Always exits 0. Requires `claude` CLI on PATH.
"""
import json
import os
import re
import subprocess
import sys

CODE_EXTENSIONS = {'.py', '.js', '.jsx', '.ts', '.tsx', '.rb', '.go', '.java', '.md'}
SKIP_PREFIXES = ('.', '_')
MAX_CODE_CHARS = 8000


def collect_code(target_dir):
    """Collect all generated code files into a single string."""
    parts = []
    for fname in sorted(os.listdir(target_dir)):
        if any(fname.startswith(p) for p in SKIP_PREFIXES):
            continue
        _, ext = os.path.splitext(fname)
        if ext not in CODE_EXTENSIONS:
            continue
        filepath = os.path.join(target_dir, fname)
        if not os.path.isfile(filepath):
            continue
        try:
            with open(filepath, 'r', errors='replace') as f:
                content = f.read()
            parts.append(f"### {fname}\n```\n{content}\n```")
        except OSError:
            pass

    combined = '\n\n'.join(parts)
    if len(combined) > MAX_CODE_CHARS:
        combined = combined[:MAX_CODE_CHARS] + "\n\n[...truncated...]"
    return combined


def main():
    try:
        target_dir = sys.argv[1]
        task_json_path = sys.argv[2]
        rubric_path = sys.argv[3]

        # Load task metadata
        with open(task_json_path, 'r') as f:
            task = json.load(f)
        task_name = task.get('name', 'unknown')
        task_description = task.get('description', '')
        task_difficulty = task.get('difficulty', 'unknown')

        # Load rubric template
        with open(rubric_path, 'r') as f:
            rubric_template = f.read()

        # Collect generated code
        code_content = collect_code(target_dir)
        if not code_content.strip():
            print("LLM_JUDGE_SCORE:0")
            print("LLM_JUDGE_RATIONALE:No code files found to evaluate")
            sys.exit(0)

        # Build prompt
        prompt = rubric_template.replace('{task_name}', task_name)
        prompt = prompt.replace('{task_description}', task_description)
        prompt = prompt.replace('{task_difficulty}', task_difficulty)
        prompt = prompt.replace('{code_content}', code_content)

        # Call Claude
        result = subprocess.run(
            [
                'claude', '-p',
                '--output-format', 'json',
                '--max-budget-usd', '0.50',
                prompt,
            ],
            capture_output=True, text=True, timeout=60,
        )

        if result.returncode != 0:
            print("LLM_JUDGE_SCORE:0")
            print("LLM_JUDGE_RATIONALE:claude call failed")
            sys.exit(0)

        # Parse claude JSON output to get the text response
        try:
            claude_output = json.loads(result.stdout)
            response_text = claude_output.get('result', '')
            judge_cost = claude_output.get('total_cost_usd', 0)
        except (json.JSONDecodeError, KeyError):
            response_text = result.stdout
            judge_cost = 0

        # Extract JSON from response (may be wrapped in markdown code block)
        json_match = re.search(r'\{[^{}]*\}', response_text, re.DOTALL)
        if not json_match:
            print("LLM_JUDGE_SCORE:0")
            print("LLM_JUDGE_RATIONALE:could not parse judge response")
            sys.exit(0)

        scores = json.loads(json_match.group())

        readability = int(scores.get('readability', 5))
        naming = int(scores.get('naming_quality', 5))
        error_handling = int(scores.get('error_handling', 5))
        idiomatic = int(scores.get('idiomatic_usage', 5))
        abstraction = int(scores.get('appropriate_abstraction', 5))
        overall = int(scores.get('overall', 5))
        rationale = scores.get('rationale', '')

        # Clamp all values to 1-10
        for val_name in ['readability', 'naming', 'error_handling', 'idiomatic', 'abstraction', 'overall']:
            val = locals()[val_name]
            locals()[val_name] = max(1, min(10, val))

        # Overall score mapped to 0-100
        judge_score = overall * 10

        print(f"LLM_JUDGE_SCORE:{judge_score}")
        print(f"LLM_JUDGE_READABILITY:{readability}")
        print(f"LLM_JUDGE_NAMING:{naming}")
        print(f"LLM_JUDGE_ERROR_HANDLING:{error_handling}")
        print(f"LLM_JUDGE_IDIOMATIC:{idiomatic}")
        print(f"LLM_JUDGE_ABSTRACTION:{abstraction}")
        print(f"LLM_JUDGE_RATIONALE:{rationale}")
        print(f"LLM_JUDGE_COST:{judge_cost}")

    except Exception as e:
        print("LLM_JUDGE_SCORE:0")
        print(f"LLM_JUDGE_RATIONALE:analyzer error: {e}")

    sys.exit(0)


if __name__ == '__main__':
    main()
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/analyzers/llm_judge.py benchmarks/analyzers/rubric.md
git commit -m "Add LLM-as-judge code quality scorer with rubric"
```

---

## Chunk 3: Wire Analyzers into Benchmark Runner

### Task 6: Integrate analyzers into `_benchmark_run_task` and `cmd_benchmark`

Modify setup.sh to call analyzers after verify.sh and merge their output into the result JSON. Add `--quality-judge` flag to cmd_benchmark.

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Add `_run_analyzers` helper function**

Insert after `_benchmark_run_task` closing brace and before `_benchmark_check_regressions`:

```bash
# Run Tier 3 analyzers on benchmark output directory.
# Usage: _run_analyzers <tmpdir> <task_dir> <use_llm_judge>
# Outputs key=value pairs for eval.
_run_analyzers() {
	local tmpdir="$1"
	local task_dir="$2"
	local use_llm_judge="$3"
	local task_json="$task_dir/task.json"
	local analyzers_dir="$REPO_DIR/benchmarks/analyzers"

	# Security smells (always run)
	if [ -f "$analyzers_dir/security_smells.py" ]; then
		python3 "$analyzers_dir/security_smells.py" "$tmpdir" 2>/dev/null || true
	fi

	# Naming quality — Python files only
	if [ -f "$analyzers_dir/naming_quality.py" ]; then
		local has_py
		has_py="$(find "$tmpdir" -maxdepth 2 -name '*.py' -not -name '_*' -print -quit 2>/dev/null)"
		if [ -n "$has_py" ]; then
			python3 "$analyzers_dir/naming_quality.py" "$tmpdir" 2>/dev/null || true
		fi
	fi

	# Over-engineering (needs task.json with expected_complexity)
	if [ -f "$analyzers_dir/overengineering.py" ] && [ -f "$task_json" ]; then
		python3 "$analyzers_dir/overengineering.py" "$tmpdir" "$task_json" 2>/dev/null || true
	fi

	# Regression check (fix-python-bug only)
	local task_name
	task_name="$(basename "$task_dir")"
	if [ "$task_name" = "fix-python-bug" ] && [ -f "$analyzers_dir/regression_check.py" ]; then
		local fixture_dir="$task_dir/fixture"
		if [ -d "$fixture_dir" ]; then
			python3 "$analyzers_dir/regression_check.py" "$tmpdir" "$fixture_dir" 2>/dev/null || true
		fi
	fi

	# LLM-as-judge (opt-in only)
	if [ "$use_llm_judge" = "1" ] && [ -f "$analyzers_dir/llm_judge.py" ] && [ -f "$analyzers_dir/rubric.md" ]; then
		echo "    Running LLM judge..."
		python3 "$analyzers_dir/llm_judge.py" "$tmpdir" "$task_json" "$analyzers_dir/rubric.md" 2>/dev/null || true
	fi
}
```

- [ ] **Step 2: Modify `_benchmark_run_task` to accept and use analyzer output**

In `_benchmark_run_task`, after the verify output extraction (after line `[ "$passed" = "true" ] && quality_score=100 || quality_score=0`) and before the Python metrics writer, add:

```bash
	# Run Tier 3 analyzers
	local analyzer_output=""
	analyzer_output="$(_run_analyzers "$tmpdir" "$task_dir" "$BENCHMARK_USE_LLM_JUDGE")"

	# Parse analyzer key:value pairs into shell variables
	local security_smells=0
	local naming_score=100
	local overengineering_score=100
	local regression_score=100
	local llm_judge_score=""

	if [ -n "$analyzer_output" ]; then
		security_smells="$(echo "$analyzer_output" | grep -oE 'SECURITY_SMELLS:[0-9]+' | head -1 | cut -d: -f2)"
		[ -z "$security_smells" ] && security_smells=0

		local ns
		ns="$(echo "$analyzer_output" | grep -oE 'NAMING_SCORE:[0-9]+' | head -1 | cut -d: -f2)"
		[ -n "$ns" ] && naming_score="$ns"

		local oes
		oes="$(echo "$analyzer_output" | grep -oE 'OVERENGINEERING_SCORE:[0-9]+' | head -1 | cut -d: -f2)"
		[ -n "$oes" ] && overengineering_score="$oes"

		local rs
		rs="$(echo "$analyzer_output" | grep -oE 'REGRESSION_SCORE:[0-9]+' | head -1 | cut -d: -f2)"
		[ -n "$rs" ] && regression_score="$rs"

		local ljs
		ljs="$(echo "$analyzer_output" | grep -oE 'LLM_JUDGE_SCORE:[0-9]+' | head -1 | cut -d: -f2)"
		[ -n "$ljs" ] && llm_judge_score="$ljs"
	fi
```

- [ ] **Step 3: Add analyzer metrics to the Python result-writing block**

In the Python heredoc that writes the result JSON, add these fields to the `result` dict (pass as additional sys.argv arguments):

Add to the `python3 -` invocation's argument list:
```bash
	python3 - "$claude_output_file" "$profile" "$task_name" \
		"$results_dir/${timestamp}.json" "$passed" "$quality_score" \
		"$security_smells" "$naming_score" "$overengineering_score" \
		"$regression_score" "$llm_judge_score" <<'PYEOF'
```

In the Python code, after `quality_score = int(sys.argv[6])`:
```python
    security_smells = int(sys.argv[7]) if len(sys.argv) > 7 else 0
    naming_score = int(sys.argv[8]) if len(sys.argv) > 8 else 100
    overengineering_score = int(sys.argv[9]) if len(sys.argv) > 9 else 100
    regression_score = int(sys.argv[10]) if len(sys.argv) > 10 else 100
    llm_judge_score = int(sys.argv[11]) if len(sys.argv) > 11 and sys.argv[11] else None
```

In the `result` dict, after `'quality_score': quality_score,`:
```python
        'security_smells': security_smells,
        'naming_score': naming_score,
        'overengineering_score': overengineering_score,
        'regression_score': regression_score,
        'llm_judge_score': llm_judge_score,
```

- [ ] **Step 4: Add `--quality-judge` flag to `cmd_benchmark`**

In `cmd_benchmark`'s `while` loop, add a new case:

```bash
			--quality-judge)
				BENCHMARK_USE_LLM_JUDGE=1
				shift
				;;
```

And initialize the variable at the top of cmd_benchmark:

```bash
	local BENCHMARK_USE_LLM_JUDGE=0
```

Export it before calling `_benchmark_run_task` so the nested function can read it. Since bash doesn't inherit locals to functions called within the same shell, use a global:

```bash
# At top of cmd_benchmark, after local declarations:
	BENCHMARK_USE_LLM_JUDGE="${BENCHMARK_USE_LLM_JUDGE:-0}"
```

- [ ] **Step 5: Update usage text**

In `usage()`, update the Benchmarking section:

```
Benchmarking:
  benchmark                        Run all benchmark tasks against current profile
  benchmark --task <name>          Run a specific benchmark task
  benchmark --quality-judge        Run with LLM-as-judge scoring (2x cost)
  benchmark --report               Show benchmark results across profiles
  benchmark --report --html        Generate HTML dashboard
```

- [ ] **Step 6: Verify syntax**

```bash
bash -n setup.sh
```

- [ ] **Step 7: Commit**

```bash
git add setup.sh
git commit -m "Wire Tier 3 analyzers into benchmark runner with --quality-judge flag"
```

---

## Chunk 4: Update Report to Show Tier 3 Metrics

### Task 7: Add Tier 3 columns to `_benchmark_report`

Update the terminal report to show the new metrics when data exists.

**Files:**
- Modify: `setup.sh` — update `_benchmark_report` Python block

- [ ] **Step 1: Extend the report table**

In `_benchmark_report`, update the Python heredoc to include new columns. After the existing cost/score display, add:

```python
    # Tier 3 metrics summary (only if data exists)
    has_tier3 = False
    for p in profiles:
        for task in task_names:
            r = get_latest(p, task)
            if r and (r.get('security_smells') is not None
                      or r.get('naming_score') is not None
                      or r.get('overengineering_score') is not None):
                has_tier3 = True
                break
        if has_tier3:
            break

    if has_tier3:
        print()
        print('  Tier 3 Quality Metrics')
        print('  ' + '─' * (task_w + (col_w + 2) * len(profiles)))

        # Header
        header = f'  {"Task":<{task_w}}'
        for p in profiles:
            header += f'  {p:>{col_w}}'
        print(header)
        print('  ' + '─' * (task_w + (col_w + 2) * len(profiles)))

        for task in task_names:
            # Security smells row
            row_sec = f'  {"  " + task + " sec":<{task_w}}'
            # Naming row
            row_name = f'  {"  " + task + " name":<{task_w}}'
            # Over-eng row
            row_oe = f'  {"  " + task + " o/e":<{task_w}}'

            for p in profiles:
                r = get_latest(p, task)
                if r is None:
                    row_sec += f'  {"—":>{col_w}}'
                    row_name += f'  {"—":>{col_w}}'
                    row_oe += f'  {"—":>{col_w}}'
                else:
                    smells = r.get('security_smells', '—')
                    nscore = r.get('naming_score', '—')
                    oescore = r.get('overengineering_score', '—')
                    row_sec += f'  {str(smells):>{col_w}}'
                    row_name += f'  {str(nscore):>{col_w}}'
                    row_oe += f'  {str(oescore):>{col_w}}'

            print(row_sec)
            print(row_name)
            print(row_oe)
```

- [ ] **Step 2: Commit**

```bash
git add setup.sh
git commit -m "Add Tier 3 metrics columns to benchmark report"
```

---

## Chunk 5: Validation

### Task 8: End-to-end test of all analyzers

Run each analyzer standalone against known inputs to verify correct output format.

- [ ] **Step 1: Security smells — verify output format**

```bash
cd ~/git/claude_personalities
tmpdir=$(mktemp -d)
echo 'x = eval(input())' > "$tmpdir/test.py"
output=$(python3 benchmarks/analyzers/security_smells.py "$tmpdir")
echo "$output"
# Must contain: SECURITY_SMELLS:1
echo "$output" | grep -q "SECURITY_SMELLS:[0-9]" && echo "OK: format correct" || echo "FAIL: bad format"
rm -r "$tmpdir"
```

- [ ] **Step 2: Naming quality — verify output format**

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/good.py" << 'EOF'
def calculate_total(price_list):
    running_total = 0
    for price in price_list:
        running_total += price
    return running_total
EOF
output=$(python3 benchmarks/analyzers/naming_quality.py "$tmpdir")
echo "$output"
echo "$output" | grep -q "NAMING_SCORE:[0-9]" && echo "OK: format correct" || echo "FAIL: bad format"
rm -r "$tmpdir"
```

- [ ] **Step 3: Over-engineering — verify against hello-world**

```bash
tmpdir=$(mktemp -d)
echo "Hello from Claude Code" > "$tmpdir/output.txt"
output=$(python3 benchmarks/analyzers/overengineering.py "$tmpdir" benchmarks/tasks/hello-world/task.json)
echo "$output"
echo "$output" | grep -q "OVERENGINEERING_SCORE:100" && echo "OK: clean output" || echo "WARN: unexpected score"
rm -r "$tmpdir"
```

- [ ] **Step 4: Regression check — verify with correct fix**

```bash
tmpdir=$(mktemp -d)
cp benchmarks/tasks/fix-python-bug/fixture/* "$tmpdir/"
# Apply the correct fix
cat > "$tmpdir/calculator.py" << 'EOF'
def add(a, b):
    return a + b

def divide(a, b):
    return a / b

def average(numbers):
    total = 0
    for n in numbers:
        total += n
    return divide(total, len(numbers))
EOF
output=$(python3 benchmarks/analyzers/regression_check.py "$tmpdir" benchmarks/tasks/fix-python-bug/fixture)
echo "$output"
echo "$output" | grep -q "REGRESSION_SCORE:100" && echo "OK: no regressions" || echo "FAIL: false regression"
rm -r "$tmpdir"
```

- [ ] **Step 5: Verify setup.sh syntax after all changes**

```bash
bash -n setup.sh
```

- [ ] **Step 6: Run a single benchmark to verify full pipeline**

```bash
./setup.sh benchmark --task hello-world
# Verify result JSON now includes security_smells, naming_score, overengineering_score fields
latest=$(ls -t _metrics/benchmarks/*/hello-world/*.json 2>/dev/null | head -1)
[ -n "$latest" ] && python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    r = json.load(f)
for key in ['security_smells', 'naming_score', 'overengineering_score']:
    print(f'{key}: {r.get(key, \"MISSING\")}')
" "$latest"
```

- [ ] **Step 7: Run benchmark report to verify new columns**

```bash
./setup.sh benchmark --report
# Verify Tier 3 section appears if data includes the new fields
```

---

## Summary of Changes

| What | Where | Lines (est.) |
|------|-------|-------------|
| `security_smells.py` | `benchmarks/analyzers/` | ~95 |
| `naming_quality.py` | `benchmarks/analyzers/` | ~145 |
| `overengineering.py` | `benchmarks/analyzers/` | ~140 |
| `regression_check.py` | `benchmarks/analyzers/` | ~105 |
| `llm_judge.py` | `benchmarks/analyzers/` | ~125 |
| `rubric.md` | `benchmarks/analyzers/` | ~30 |
| task.json updates (5 files) | `benchmarks/tasks/*/` | ~50 total |
| `_run_analyzers()` | `setup.sh` | ~40 |
| `_benchmark_run_task` changes | `setup.sh` | ~30 |
| `cmd_benchmark` flag parsing | `setup.sh` | ~5 |
| `_benchmark_report` Tier 3 section | `setup.sh` | ~40 |
| Usage text update | `setup.sh` | ~3 |
| **Total** | | **~810 lines across 12 files** |

## Cost Impact

| Analyzer | Cost per task | When |
|----------|---------------|------|
| security_smells.py | $0 | Always |
| naming_quality.py | $0 | Always (Python files only) |
| overengineering.py | $0 | Always |
| regression_check.py | $0 | fix-python-bug only |
| llm_judge.py | ~$0.05-0.15 | `--quality-judge` flag only |

Without `--quality-judge`: zero additional cost.
With `--quality-judge`: ~$0.50 extra per full benchmark run (5 tasks).
