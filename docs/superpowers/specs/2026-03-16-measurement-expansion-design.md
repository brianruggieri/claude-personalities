# Measurement Expansion: New Analyzers, LLM Judge, and Minimalism Profile

**Date:** 2026-03-16
**Status:** Approved

## Problem

The benchmark system measures 28+ metrics but has gaps. Six LLM judge metrics are captured but always zero (judge disabled). No metrics exist for function count (decomposition), type annotations, docstrings, or error handling density. Additionally, no "anti-limits" profile exists to test whether forcing conciseness (opposite of decomposition) produces measurably different code.

## Context

Experiments show that hard numerical limits on function length and complexity are the only personality rules that measurably improve code structure. Limits-amplified (10-line CLAUDE.md) outperforms opinionated (1000-line CLAUDE.md) on 4/9 tasks at 35% lower cost. Expanding the measurement surface may reveal additional dimensions where personality rules differentiate.

## Design

### 1. Four New Analyzers

Each follows the existing pattern: standalone Python script in `benchmarks/analyzers/`, reads a directory of generated code, prints `KEY:VALUE` lines to stdout, always exits 0.

#### 1.1 `function_count.py` — Decomposition Measurement

Purpose: Measures whether limits rules force more function decomposition.

- Walks Python AST for `FunctionDef`/`AsyncFunctionDef`
- Counts JS/TS functions via regex (`function\s+\w+`, `=>\s*\{`). Known limitation: misses arrow expressions without braces, class method shorthand, and anonymous functions. JS/TS counting is best-effort; do not compare across languages.
- Counts files analyzed

Output:
```
FUNCTION_COUNT:<total int>
FUNCTION_COUNT_AVG_PER_FILE:<float>
```

#### 1.2 `type_annotation_coverage.py` — Type Hint Presence (Python-only)

Purpose: Measures whether any personality rules affect type annotation behavior.

- Python-only analyzer (matches convention of `naming_quality.py`, `cognitive_complexity.py`)
- For each Python function, checks if `returns` annotation exists
- For each arg (excluding `self`/`cls`), checks if `annotation` attr exists
- Computes coverage as (fully annotated signatures / total signatures) * 100
- Scope: functions only (not classes). This differs from `docstring_coverage.py` which includes classes — intentional, as class-level type annotations are not a Python convention.

Output:
```
TYPE_ANNOTATION_COVERAGE:<0-100>
TYPE_ANNOTATIONS_MISSING:<count>
```

#### 1.3 `docstring_coverage.py` — Documentation Presence (Python-only)

Purpose: Measures whether personality rules affect documentation behavior.

- Python-only analyzer
- Uses `ast.get_docstring()` on each `FunctionDef`, `AsyncFunctionDef`, and `ClassDef`
- Scope includes classes (unlike `type_annotation_coverage.py` which is functions-only) — docstrings on classes are a Python convention
- Computes coverage as (nodes with docstrings / total nodes) * 100

Output:
```
DOCSTRING_COVERAGE:<0-100>
DOCSTRINGS_MISSING:<count>
```

#### 1.4 `error_handling_density.py` — Defensive Coding Patterns (Python-only)

Purpose: Measures error handling strategy differences across profiles.

- Python-only analyzer
- Counts `ast.Try` nodes (try/except blocks)
- Counts `ast.Raise` nodes (explicit error raising)
- Detects guard clauses: an `ast.If` node that is one of the first 3 statements of a `FunctionDef` body and contains a `Return` or `Raise` in its body (not in `orelse`)
- Computes density as (try_count + raise_count + guard_clauses) per 100 non-blank, non-comment lines

Output:
```
ERROR_HANDLING_TRY_COUNT:<int>
ERROR_HANDLING_RAISE_COUNT:<int>
ERROR_HANDLING_GUARD_CLAUSES:<int>
ERROR_HANDLING_DENSITY:<float>
```

### 2. LLM Judge Improvements

The existing `benchmarks/analyzers/llm_judge.py` is fully built but gated behind `BENCHMARK_JUDGE=1`. Two changes:

#### 2.1 Anchored Rubric

Replace the generic rubric with anchored scoring examples for each dimension:

```
READABILITY:
  3 = Dense logic, unclear variable flow, no whitespace grouping
  7 = Clear flow, good whitespace, could improve naming in spots
  9 = Immediately understandable, self-documenting structure

NAMING:
  3 = Generic names (data, result, temp), inconsistent conventions
  7 = Descriptive names, consistent conventions, minor abbreviations
  9 = Every name reveals intent, perfect convention adherence

ERROR_HANDLING:
  3 = No edge case handling, bare except blocks, silent failures
  7 = Key edge cases handled, specific exceptions, some gaps
  9 = All edge cases handled, custom exceptions where appropriate, clear error messages

IDIOMATIC:
  3 = Transliterated from another language, ignores standard library
  7 = Uses language features correctly, follows most conventions
  9 = Expert-level idioms, leverages stdlib perfectly, zero anti-patterns

ABSTRACTION:
  3 = God function or premature abstraction, wrong level of granularity
  7 = Reasonable decomposition, could be slightly better
  9 = Perfect granularity for the problem, each unit has one clear purpose
```

#### 2.2 Task Context

Include the task name and task prompt in the judge input so it can assess appropriateness relative to the problem, not just generic quality.

Format: `"Task: {task_name}\nPrompt: {task_prompt}\n\n{rubric}\n\n{code}"`

Implementation: `llm_judge.py` receives a third argument (`sys.argv[3]`) pointing to the task directory. It reads `prompt.md` from that directory. In `setup.sh`, the invocation becomes: `python3 "$analyzers_dir/llm_judge.py" "$tmpdir" "$task_name" "$task_dir"`

#### 2.3 Execution

Subscription only via `claude -p --dangerously-skip-permissions --output-format json`. No API usage. Gated behind `BENCHMARK_JUDGE=1`.

Drive-by fix: change `collect_code` from `os.listdir` to `os.walk` to match all other analyzers' recursive traversal pattern.

### 3. Minimalism Profile Variant

File: `_experiment/claude-md-minimalism.md`

Content: Blank machine environment section + hard minimalism rules:

```markdown
## Code Standards — Hard Limits

- Maximum 3 functions per file. Inline helper logic rather than extracting.
- No function may exist solely to be called once. If it's called once, inline it.
- No function length limit. A single function may be as long as needed.
- Solve problems in the fewest lines possible. Conciseness is correctness.
- No wrapper functions, no adapter patterns, no unnecessary abstractions.
- No docstrings unless the function signature is genuinely ambiguous.
```

Experiment runner (`run-isolation-experiment.sh`) updated to include `minimalism` in the `VARIANTS` array. Header and run-count comments updated to reflect 2 profiles × 9 tasks × 3 reps = 54 runs.

### 4. Pipeline Integration (`setup.sh`)

Extend the existing pattern (positional args to inline Python):

1. Add 4 analyzer invocations in the Tier 3 block (~line 1330):
   ```bash
   analyzer_output+="$(python3 "$analyzers_dir/function_count.py" "$tmpdir" 2>/dev/null || true)"$'\n'
   analyzer_output+="$(python3 "$analyzers_dir/type_annotation_coverage.py" "$tmpdir" 2>/dev/null || true)"$'\n'
   analyzer_output+="$(python3 "$analyzers_dir/docstring_coverage.py" "$tmpdir" 2>/dev/null || true)"$'\n'
   analyzer_output+="$(python3 "$analyzers_dir/error_handling_density.py" "$tmpdir" 2>/dev/null || true)"$'\n'
   ```

2. Add grep/extract lines for each key (~line 1390)
3. Add ~8 new positional args to the Python JSON writer (~line 1477)
4. Add fields to the result dict (~line 1557)
5. Add zero-value defaults in the fallback block

New positional arg mapping (extending existing `sys.argv[1]`–`sys.argv[33]`):

| `sys.argv` | Field | Type | Default |
|------------|-------|------|---------|
| 34 | `function_count` | int | 0 |
| 35 | `function_count_avg_per_file` | float | 0.0 |
| 36 | `type_annotation_coverage` | int | 0 |
| 37 | `type_annotations_missing` | int | 0 |
| 38 | `docstring_coverage` | int | 0 |
| 39 | `docstrings_missing` | int | 0 |
| 40 | `error_handling_try_count` | int | 0 |
| 41 | `error_handling_raise_count` | int | 0 |
| 42 | `error_handling_guard_clauses` | int | 0 |
| 43 | `error_handling_density` | float | 0.0 |

New metrics in JSON output:
- `function_count`, `function_count_avg_per_file`
- `type_annotation_coverage`, `type_annotations_missing`
- `docstring_coverage`, `docstrings_missing`
- `error_handling_try_count`, `error_handling_raise_count`, `error_handling_guard_clauses`, `error_handling_density`

### 5. Validation Plan

After all code is integrated, run a full benchmark suite from a regular terminal:

| Profile | Tasks | Reps | Runs |
|---------|-------|------|------|
| blank | 9 | 3 | 27 |
| opinionated | 9 | 3 | 27 |
| variant-limits-amplified | 9 | 3 | 27 |
| variant-minimalism | 9 | 3 | 27 |
| **Total** | | | **108** |

With `BENCHMARK_JUDGE=1` enabled for all runs. Estimated cost: ~$35, time: ~80 minutes.

After validation, update the dashboard (`_metrics/dashboard-option-b.html`) with the new profiles and metrics.

## Testing

- Add test cases to `benchmarks/analyzers/test_analyzers.py` for each new analyzer
- Each analyzer tested with: known Python input → expected output
- LLM judge tested with mock subprocess (rubric format validation only — can't unit test LLM output)

## Files Modified

| File | Change |
|------|--------|
| `benchmarks/analyzers/function_count.py` | NEW — function count analyzer |
| `benchmarks/analyzers/type_annotation_coverage.py` | NEW — type annotation analyzer |
| `benchmarks/analyzers/docstring_coverage.py` | NEW — docstring analyzer |
| `benchmarks/analyzers/error_handling_density.py` | NEW — error handling analyzer |
| `benchmarks/analyzers/llm_judge.py` | MODIFY — improved rubric + task context |
| `benchmarks/analyzers/test_analyzers.py` | MODIFY — add tests for 4 new analyzers |
| `_experiment/claude-md-minimalism.md` | NEW — minimalism profile variant |
| `setup.sh` | MODIFY — wire 4 analyzers + new metrics into pipeline |
| `run-isolation-experiment.sh` | MODIFY — add minimalism variant |

## Out of Scope

- Dashboard updates (deferred until validation data exists)
- New benchmark tasks (current 9 are sufficient for this phase)
- Retroactive analysis of existing data (generated code was deleted)
- API-based judge execution (all Claude usage is subscription via `claude -p`)
