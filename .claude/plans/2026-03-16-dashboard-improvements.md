# Dashboard Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix analyzer bugs, improve dashboard visualizations, and add statistical rigor to the benchmark comparison system.

**Architecture:** Three independent workstreams — Research (analyzer investigation + experimental design), Development (dashboard code changes), and Testing (validation + multi-run execution). Research must complete before Development starts on analyzer-dependent changes, but the dashboard UI work can proceed in parallel. Testing validates everything at the end.

**Tech Stack:** Python 3 (AST-based analyzers), HTML/CSS/JS (Chart.js 4.4.7 dashboard), bash (benchmark runner via `./setup.sh benchmark`)

---

## Chunk 1: All Tasks

### Task 1: Research — Analyzer Investigation & Experimental Design

**Owner:** Research team
**Goal:** Fix the duplicate_blocks analyzer bug, diagnose why personality_compliance < 100 for opinionated, and document the statistical protocol for multi-run experiments.

**Files:**
- Modify: `benchmarks/analyzers/duplicate_blocks.py`
- Modify: `benchmarks/analyzers/personality_compliance.py`
- Create: `.claude/context-multi-run-protocol.md`

#### Part A: Fix duplicate_blocks analyzer

The duplicate_blocks analyzer reports `DUPLICATE_BLOCKS:280` for a 278-line file — this is a bug. The root cause is that variable name normalization (`VAR_NAME_RE` replacing all lowercase identifiers with `VAR0`, `VAR1`, etc.) makes structurally different functions appear identical, and the 0.8 similarity threshold is too low for normalized code.

- [ ] **Step 1: Write a test script to reproduce the bug**

Create `benchmarks/analyzers/test_duplicate_blocks.py`:

```python
#!/usr/bin/env python3
"""Test duplicate_blocks analyzer against known inputs."""
import os
import subprocess
import sys
import tempfile

def run_analyzer(code):
	"""Run duplicate_blocks.py on a temp directory containing code, return output."""
	with tempfile.TemporaryDirectory() as tmpdir:
		filepath = os.path.join(tmpdir, 'module.py')
		with open(filepath, 'w') as f:
			f.write(code)
		result = subprocess.run(
			[sys.executable, os.path.join(os.path.dirname(__file__), 'duplicate_blocks.py'), tmpdir],
			capture_output=True, text=True
		)
		return result.stdout.strip()

# Test 1: Two genuinely different functions should NOT be duplicates
different_funcs = '''
def add(a, b):
    return a + b

def multiply(x, y):
    result = x * y
    return result

def greet(name):
    message = f"Hello, {name}!"
    print(message)
    return message
'''

output = run_analyzer(different_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks <= 1, f"Expected <= 1 duplicate blocks for different functions, got {blocks}"
print(f"PASS: different functions → {blocks} duplicates")

# Test 2: Two actually identical functions (different names) SHOULD be duplicates
# Bodies are intentionally long (>50 chars after normalization) to exceed MIN_BODY_LENGTH
identical_funcs = '''
def process_alpha(items):
    result = []
    for item in items:
        if item > 0:
            transformed = item * 2
            result.append(transformed)
        elif item == 0:
            result.append(0)
        else:
            result.append(abs(item))
    return sorted(result)

def process_beta(entries):
    output = []
    for entry in entries:
        if entry > 0:
            modified = entry * 2
            output.append(modified)
        elif entry == 0:
            output.append(0)
        else:
            output.append(abs(entry))
    return sorted(output)
'''

output = run_analyzer(identical_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks >= 1, f"Expected >= 1 duplicate block for identical functions, got {blocks}"
print(f"PASS: identical functions → {blocks} duplicates")

# Test 3: Many small functions should not explode the count
many_funcs = '\n'.join(
    f'def func_{i}(x):\n    return x + {i}\n'
    for i in range(20)
)

output = run_analyzer(many_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks < 20, f"Expected < 20 duplicates for trivially similar one-liners, got {blocks}"
print(f"PASS: many small functions → {blocks} duplicates")

print("\nAll tests passed.")
```

- [ ] **Step 2: Run the test to confirm the bug**

Run: `cd /Users/brianruggieri/git/claude_personalities && python3 benchmarks/analyzers/test_duplicate_blocks.py`
Expected: Test 1 FAILS — different functions reported as duplicates because normalization makes them look identical.

- [ ] **Step 3: Fix the analyzer — three changes**

Apply these fixes to `benchmarks/analyzers/duplicate_blocks.py`:

**Fix 1:** Only normalize *local* variable names (names that appear in assignments within the function), not all lowercase identifiers. This preserves function names, module-level names, and imported names.

Replace the `normalize_body` function (find the `def normalize_body(source_lines, node):` definition and replace through its `return normalized` statement) with:

```python
def normalize_body(source_lines, node):
	"""Extract and normalize a function body for comparison.

	Strips whitespace and replaces locally-assigned variable names with
	placeholders to detect structurally similar functions.
	"""
	start = node.lineno - 1
	end = getattr(node, 'end_lineno', None)
	if end is None:
		return ''
	body_lines = source_lines[start:end]
	if not body_lines:
		return ''

	# Collect locally assigned variable names from the function AST
	local_names = set()
	for child in ast.walk(node):
		if isinstance(child, ast.Name) and isinstance(child.ctx, ast.Store):
			local_names.add(child.id)
	# Include function parameters
	for arg in node.args.args + node.args.posonlyargs + node.args.kwonlyargs:
		local_names.add(arg.arg)
	if node.args.vararg:
		local_names.add(node.args.vararg.arg)
	if node.args.kwarg:
		local_names.add(node.args.kwarg.arg)

	text = '\n'.join(line.strip() for line in body_lines if line.strip())

	seen = {}
	counter = [0]

	def replace_var(match):
		name = match.group(0)
		if name in PYTHON_KEYWORDS:
			return name
		if name not in local_names:
			return name  # Preserve non-local names
		if name not in seen:
			seen[name] = f'VAR{counter[0]}'
			counter[0] += 1
		return seen[name]

	normalized = VAR_NAME_RE.sub(replace_var, text)
	return normalized
```

**Fix 2:** Raise the similarity threshold from 0.8 to 0.9 (find `SIMILARITY_THRESHOLD = 0.8`):

```python
SIMILARITY_THRESHOLD = 0.9
```

**Fix 3:** Raise the minimum body length from 20 to 50 characters (find `MIN_BODY_LENGTH = 20`) to skip trivially short functions:

```python
MIN_BODY_LENGTH = 50
```

> **Note:** The `PYTHON_KEYWORDS` set (defined below these constants) intentionally includes common builtins like `print`, `len`, `range` — not just language keywords. This is by design so that calls to builtins aren't normalized away.

- [ ] **Step 4: Run the test to verify the fix**

Run: `python3 benchmarks/analyzers/test_duplicate_blocks.py`
Expected: All 3 tests pass.

- [ ] **Step 5: Validate against real benchmark data**

Run the fixed analyzer against the opinionated ex-bowling output to confirm reasonable results.

First check if the workdir exists. If not, use the test suite's SAMPLE_CODE as a fallback:

```bash
# Try real workdir first
if [ -d "_metrics/benchmarks/opinionated/ex-bowling/workdir" ]; then
  python3 benchmarks/analyzers/duplicate_blocks.py _metrics/benchmarks/opinionated/ex-bowling/workdir/
else
  # Fallback: the test_duplicate_blocks.py tests already cover this.
  echo "Workdir not found — relying on test_duplicate_blocks.py results from Step 4"
fi
```

Expected: If workdir exists, `DUPLICATE_BLOCKS` should be a small number (0-5), not 280. If not, Step 4's passing tests are sufficient validation.

- [ ] **Step 6: Commit the fix**

```bash
git add benchmarks/analyzers/duplicate_blocks.py benchmarks/analyzers/test_duplicate_blocks.py
git commit -m "Fix duplicate_blocks analyzer: normalize only local vars, raise thresholds"
```

#### Part B: Investigate personality_compliance for opinionated

The opinionated profile enforces strict rules (function length, naming, etc.) but only scores 83% on personality_compliance for ex-bowling. The `profile_name` parameter is accepted but not used (line 139: `profile_name = sys.argv[2] if len(sys.argv) > 2 else 'main'`). The low score is likely caused by the **magic numbers rule** — bowling scoring uses constants like 10 (pins), 300 (perfect game), etc. which are domain-appropriate but flagged as violations.

- [ ] **Step 7: Run the analyzer with verbose output to identify specific violations**

Add a temporary diagnostic mode. Create `benchmarks/analyzers/test_compliance_verbose.py`:

```python
#!/usr/bin/env python3
"""Diagnostic: show exactly which rules personality_compliance violates."""
import ast
import os
import re
import sys

SAFE_NUMBERS = frozenset({0, 1, 2, -1, True, False, None})
SNAKE_CASE_RE = re.compile(r'^_?_?[a-z][a-z0-9_]*_?_?$')
LOOP_SINGLE_LETTER_ALLOWED = frozenset({'i', 'j', 'k', 'n', '_'})
COMMENTED_CODE_RE = re.compile(r'#\s*(def |class |import |if |for |while |return )')

target_dir = sys.argv[1]

for root, dirs, files in os.walk(target_dir):
	dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
	for fname in files:
		if not fname.endswith('.py') or fname.startswith(('_', '.')):
			continue
		filepath = os.path.join(root, fname)
		with open(filepath) as f:
			source = f.read()
		try:
			tree = ast.parse(source)
		except SyntaxError:
			continue

		loop_targets = set()
		for node in ast.walk(tree):
			if isinstance(node, (ast.For, ast.AsyncFor)):
				for t in ast.walk(node.target):
					if isinstance(t, ast.Name):
						loop_targets.add(t.id)
			if isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
				for gen in node.generators:
					for t in ast.walk(gen.target):
						if isinstance(t, ast.Name):
							loop_targets.add(t.id)

		for node in ast.walk(tree):
			if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
				end = getattr(node, 'end_lineno', None)
				if end and (end - node.lineno + 1) > 50:
					print(f"  VIOLATION: function '{node.name}' is {end - node.lineno + 1} lines (max 50) at line {node.lineno}")

			if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
				if node.value not in SAFE_NUMBERS:
					print(f"  VIOLATION: magic number {node.value} at line {node.lineno}")

			if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
				if len(node.id) == 1 and node.id != '_':
					if node.id not in LOOP_SINGLE_LETTER_ALLOWED or node.id not in loop_targets:
						print(f"  VIOLATION: single-letter var '{node.id}' at line {node.lineno}")
```

- [ ] **Step 8: Run the diagnostic against opinionated's ex-bowling output**

```bash
python3 benchmarks/analyzers/test_compliance_verbose.py _metrics/benchmarks/opinionated/ex-bowling/workdir/
```

Expected: Most violations will be magic numbers (10, 300, etc.) and possibly single-letter variables. Document the findings.

- [ ] **Step 9: Decide on fix approach**

Based on diagnostic output, choose one of:

**(a) Add domain-aware safe numbers** — extend `SAFE_NUMBERS` to include common domain constants when the task type is known (bowling: 10, 300). This requires passing task metadata to the analyzer.

**(b) Document the limitation** — keep the metric as-is but add a note in the dashboard explaining that personality_compliance uses universal rules that penalize domain-specific constants.

**(c) Don't fix** — the 80-83% range with ~112 violations (mostly magic numbers) is a known limitation. The metric still shows relative differences between profiles.

Recommendation: **(b)** — the metric serves as a relative comparison tool, and trying to make it profile-aware adds complexity without improving differentiation power. The dashboard footnote is implemented in Task 2, Part D (the "3 of 5 tasks" finding bullet captures this insight). No separate tooltip needed — the findings text covers it.

- [ ] **Step 10: Commit diagnostic scripts**

```bash
git add benchmarks/analyzers/test_compliance_verbose.py
git commit -m "Add personality_compliance diagnostic script"
```

#### Part C: Design multi-run experimental protocol

- [ ] **Step 11: Write the experimental protocol document**

Create `.claude/context-multi-run-protocol.md`:

```markdown
# Multi-Run Experimental Protocol

## Purpose
Establish variance estimates for benchmark metrics to replace n=1 claims with
statistically grounded observations.

## Design
- **Tasks:** Same 5-task subset (he-000, mbpp-011, ex-bowling, ce-000, rf-001)
- **Profiles:** blank, main, opinionated
- **Repetitions:** 3 per cell (3 profiles x 5 tasks x 3 reps = 45 runs)
- **Estimated cost:** ~$10-15 (based on pilot: $3.50 for 15 single runs)
- **Estimated time:** ~1-2 hours

## Execution
Run from a regular terminal (not inside Claude Code):

```bash
for rep in 1 2 3; do
  for profile in blank main opinionated; do
    git checkout $profile
    for task in he-000-has-close-elements mbpp-011-remove-occ ex-bowling ce-000-regex-utils rf-001-command-output-hash; do
      ./setup.sh benchmark --task $task
    done
  done
done
git checkout main
```

Results land in `_metrics/benchmarks/<profile>/<task>/<timestamp>.json`.
Multiple runs produce multiple timestamped files per task per profile.

## Analysis
For each (profile, task) cell with 3 observations:
- Report median and IQR (not mean/stdev — too few observations for normality)
- For key metrics: cognitive_complexity_max, max_function_length, cost_usd
- Use Wilcoxon signed-rank test (paired by task) to compare profiles
- Report effect sizes (rank-biserial correlation)

## Success Criteria
- Claims using "consistently" require p < 0.05 on paired test
- Claims about "differences" require non-overlapping IQRs
- All findings qualified with sample size (n=3 per cell)
```

- [ ] **Step 12: Commit the protocol**

```bash
git add .claude/context-multi-run-protocol.md
git commit -m "Add multi-run experimental protocol for benchmark variance estimation"
```

---

### Task 2: Development — Dashboard Improvements

**Owner:** Development team
**Goal:** Fix the radar chart, add new metrics, add cost-quality visualization, and qualify findings with n=1 caveats.

**Files:**
- Modify: `_metrics/dashboard-option-b.html`

**Dependency:** None — all changes use existing data in the dashboard. Analyzer fixes from Task 1 will update the *data* in future runs, but the dashboard code changes are independent.

#### Part A: Fix the radar chart

The current 6-axis radar has 3 axes that show no profile differentiation (Conciseness: 6-point spread, Maintainability: ~1-point spread, Personality Compliance: 3-point spread). These compress the visual and make profiles appear more similar than they are on the 3 axes that matter.

- [ ] **Step 1: Replace the 6-axis radar with a focused 3-axis version**

In `_metrics/dashboard-option-b.html`, find the radar chart IIFE (search for `// ─── 4. CODE QUALITY RADAR` through the closing `})();` of the `renderRadar` function). Replace the entire block with:

> **Note:** This code calls `clamp()`, which is already defined in the HELPERS section of the dashboard (`function clamp(v, lo, hi) { ... }`).

```javascript
// ─── 4. CODE QUALITY RADAR ──────────────────────────────────────────────────

(function renderRadar() {
	// Focus on ex-bowling — the task with the most profile differentiation.
	// Only 3 axes that show meaningful differentiation between profiles.
	// Axes are normalized so higher = better code quality.
	const axes = [
		'Function\nDecomposition',
		'Cognitive\nSimplicity',
		'Cyclomatic\nControl'
	];

	// ex-bowling raw values per profile
	const bowling = {};
	PROFILE_ORDER.forEach(pk => {
		bowling[pk] = profiles[pk].data.find(d => d.task === 'ex-bowling');
	});
	// Guard: if ex-bowling data is missing, skip this chart
	if (!bowling[PROFILE_ORDER[0]]) return;

	// Normalization rationale:
	// - Function Decomposition: 100 - max_func_len. Range in data: 19-64.
	//   Maps to 36-81. Good spread across the 100-point scale.
	// - Cognitive Simplicity: 100 - cognitive_max * 2. The *2 amplifies
	//   differences because raw cognitive values (11-38) would only span
	//   62-89 without it. With *2, span is 24-78. Values > 50 clip to 0,
	//   which is appropriate (cognitive_max > 50 = genuinely complex code).
	// - Cyclomatic Control: 100 - complexity_max * 3. Similar rationale:
	//   raw values (8-23) span 77-92 without multiplier. With *3, span is
	//   31-76. The *3 reflects that each branch point has outsized impact
	//   on testability (each branch roughly doubles test paths).
	function computeRadarValues(pk) {
		const d = bowling[pk];
		return [
			clamp(100 - d.max_func_len, 0, 100),
			clamp(100 - d.cognitive_max * 2, 0, 100),
			clamp(100 - d.complexity_max * 3, 0, 100)
		];
	}

	const datasets = PROFILE_ORDER.map(pk => ({
		label: profiles[pk].label,
		data: computeRadarValues(pk),
		borderColor: profiles[pk].color,
		backgroundColor: profiles[pk].colorAlpha,
		pointBackgroundColor: profiles[pk].color,
		pointBorderColor: profiles[pk].color,
		pointRadius: 5,
		borderWidth: 2.5
	}));

	new Chart(document.getElementById('chartRadar'), {
		type: 'radar',
		data: { labels: axes, datasets },
		options: {
			responsive: true,
			maintainAspectRatio: true,
			plugins: {
				legend: {
					position: 'top',
					labels: { usePointStyle: true, pointStyle: 'rectRounded', padding: 16 }
				},
				tooltip: {
					backgroundColor: '#1e293b',
					titleColor: '#f1f5f9',
					bodyColor: '#cbd5e1',
					borderColor: '#475569',
					borderWidth: 1,
					callbacks: {
						label: ctx => ctx.dataset.label + ': ' + ctx.parsed.r.toFixed(1)
					}
				}
			},
			scales: {
				r: {
					min: 0,
					max: 100,
					ticks: { stepSize: 20, color: '#64748b', backdropColor: 'transparent', font: { size: 10 } },
					grid: { color: '#33415544' },
					angleLines: { color: '#33415544' },
					pointLabels: { color: '#cbd5e1', font: { size: 12 } }
				}
			}
		}
	});
})();
```

- [ ] **Step 2: Update the radar chart title in the HTML**

Find the `<h2>` containing "Code Quality Radar" in the HTML section and change from:

```html
<h2>Code Quality Radar — ex-bowling (most differentiating task)</h2>
```

to:

```html
<h2>Code Quality Radar — ex-bowling (3 differentiating axes only)</h2>
```

- [ ] **Step 3: Open the dashboard in a browser and verify the radar chart**

Run: `open /Users/brianruggieri/git/claude_personalities/_metrics/dashboard-option-b.html`

Expected: 3-axis radar with clear visual separation between profiles. Opinionated polygon should be visibly larger than main and blank on all 3 axes.

#### Part B: Add token efficiency and function count metrics

- [ ] **Step 4: Add computed fields to the data section**

In `_metrics/dashboard-option-b.html`, find `const PROFILE_ORDER = ['blank', 'main', 'opinionated'];` and add the following section immediately after it:

```javascript
// ─── DERIVED METRICS ─────────────────────────────────────────────────────────
// Compute token efficiency (output_tokens / lines_generated) for each task.
// Lower = more efficient (fewer tokens wasted on explanation per line of code).

PROFILE_ORDER.forEach(pk => {
	profiles[pk].data.forEach(d => {
		d.token_efficiency = d.lines > 0 ? +(d.output_tokens / d.lines).toFixed(1) : 0;
	});
});
```

- [ ] **Step 5a: Add the Token Efficiency chart canvas (HTML)**

In the HTML section, find the `chartFuncLen` card (the one with `<canvas id="chartFuncLen">`). After its closing `</div>` (the chart-card div), and before the `full-width` heatmap card (`<div class="chart-card full-width">`), insert:

```html
<div class="chart-card">
	<h2>Token Efficiency (output tokens / lines generated)</h2>
	<div class="chart-container">
		<canvas id="chartTokenEff"></canvas>
	</div>
</div>
```

- [ ] **Step 5b: Renumber existing heatmap section and add Token Efficiency chart code (JavaScript)**

First, find `// ─── 6. COMPLEXITY HEATMAP` in the JavaScript and rename it to `// ─── 9. COMPLEXITY HEATMAP` (to make room for the 3 new sections: 6=Token Efficiency, 7=Pareto Scatter, 8=Marginal Cost Table).

Then, find `// ─── 5. MAX FUNCTION LENGTH` and the `new Chart(document.getElementById('chartFuncLen'), ...)` call that follows it. After that chart's closing `});`, add:

```javascript
// ─── 6. TOKEN EFFICIENCY ────────────────────────────────────────────────────

new Chart(document.getElementById('chartTokenEff'), {
	type: 'bar',
	data: { labels: TASK_LABELS, datasets: makeBarDatasets('token_efficiency') },
	options: barChartOptions('Tokens / Line', v => v.toFixed(1) + ' tok/line')
});
```

- [ ] **Step 6: Verify the new chart renders**

Run: `open /Users/brianruggieri/git/claude_personalities/_metrics/dashboard-option-b.html`

Expected: New bar chart showing token efficiency per task per profile. Higher values mean the profile produces more tokens (explanation, comments, etc.) per line of actual code.

#### Part C: Add cost-quality Pareto visualization

- [ ] **Step 7a: Add the Pareto scatter chart canvas (HTML)**

In the HTML, find the Token Efficiency card you just added. After its closing `</div>`, and before the heatmap card (`<div class="chart-card full-width">` with `id="heatmapTable"`), insert:

```html
<div class="chart-card full-width">
	<h2>Cost vs. Cognitive Complexity (lower is better on both axes)</h2>
	<div class="chart-container">
		<canvas id="chartPareto"></canvas>
	</div>
</div>
```

- [ ] **Step 7b: Add the Pareto scatter chart code (JavaScript)**

In the JavaScript, find the Token Efficiency chart code you added in Step 5b. After its closing `});`, add:

```javascript
// ─── 7. COST vs QUALITY SCATTER (PARETO) ────────────────────────────────────

(function renderPareto() {
	// Shape markers per profile for accessibility
	const SHAPES = { blank: 'circle', main: 'rectRot', opinionated: 'triangle' };

	const datasets = PROFILE_ORDER.map(pk => ({
		label: profiles[pk].label,
		data: profiles[pk].data.map((d, i) => ({
			x: d.cost_usd,
			y: d.cognitive_max,
			task: TASKS[i]
		})),
		backgroundColor: profiles[pk].color,
		borderColor: profiles[pk].color,
		pointStyle: SHAPES[pk],
		pointRadius: 8,
		pointHoverRadius: 11
	}));

	new Chart(document.getElementById('chartPareto'), {
		type: 'scatter',
		data: { datasets },
		options: {
			responsive: true,
			maintainAspectRatio: true,
			plugins: {
				legend: {
					position: 'top',
					labels: { usePointStyle: true, padding: 16 }
				},
				tooltip: {
					backgroundColor: '#1e293b',
					titleColor: '#f1f5f9',
					bodyColor: '#cbd5e1',
					borderColor: '#475569',
					borderWidth: 1,
					callbacks: {
						title: ctx => ctx[0].raw.task,
						label: ctx => {
							const p = ctx.dataset.label;
							return `${p}: $${ctx.raw.x.toFixed(3)} cost, ${ctx.raw.y} cognitive complexity`;
						}
					}
				}
			},
			scales: {
				x: {
					title: { display: true, text: 'Cost (USD)', color: '#94a3b8' },
					ticks: { color: '#94a3b8', callback: v => '$' + v.toFixed(2) },
					grid: { color: '#1e3a5f22' }
				},
				y: {
					title: { display: true, text: 'Cognitive Complexity (max)', color: '#94a3b8' },
					ticks: { color: '#94a3b8' },
					grid: { color: '#1e3a5f22' }
				}
			}
		}
	});
})();
```

- [ ] **Step 8a: Add the marginal cost table element (HTML)**

In the HTML, find the Pareto chart card you just added. After its closing `</div>`, and before the heatmap card, insert:

```html
<div class="chart-card full-width">
	<h2>Marginal Cost of Opinionated vs. Blank</h2>
	<table class="heatmap-table" id="marginalTable"></table>
</div>
```

- [ ] **Step 8b: Add the marginal cost table code (JavaScript)**

In the JavaScript, find the Pareto scatter code you added in Step 7b. After its closing `})();`, add:

```javascript
// ─── 8. MARGINAL COST TABLE ─────────────────────────────────────────────────

(function renderMarginalTable() {
	const table = document.getElementById('marginalTable');

	const thead = document.createElement('thead');
	const hrow = document.createElement('tr');
	['Task', 'Blank Cost', 'Opinionated Cost', 'Cost Premium', 'Cognitive Improvement', 'Verdict'].forEach(h => {
		const th = document.createElement('th');
		th.textContent = h;
		hrow.appendChild(th);
	});
	thead.appendChild(hrow);
	table.appendChild(thead);

	const tbody = document.createElement('tbody');
	TASKS.forEach((task, i) => {
		const blankD = profiles.blank.data[i];
		const opinD = profiles.opinionated.data[i];
		const costDelta = opinD.cost_usd - blankD.cost_usd;
		const cogDelta = blankD.cognitive_max - opinD.cognitive_max;
		const cogPct = blankD.cognitive_max > 0
			? Math.round((cogDelta / blankD.cognitive_max) * 100)
			: 0;

		let verdict, verdictColor;
		if (cogDelta <= 0) {
			verdict = 'No benefit';
			verdictColor = '#ef4444';
		} else if (costDelta <= 0) {
			verdict = 'Free improvement';
			verdictColor = '#22c55e';
		} else {
			verdict = 'Pays off';
			verdictColor = '#f59e0b';
		}

		const row = document.createElement('tr');

		const tdTask = document.createElement('td');
		tdTask.textContent = task;
		row.appendChild(tdTask);

		const tdBlank = document.createElement('td');
		tdBlank.textContent = '$' + blankD.cost_usd.toFixed(3);
		tdBlank.style.backgroundColor = '#1e293b';
		tdBlank.style.color = '#94a3b8';
		row.appendChild(tdBlank);

		const tdOpin = document.createElement('td');
		tdOpin.textContent = '$' + opinD.cost_usd.toFixed(3);
		tdOpin.style.backgroundColor = '#1e293b';
		tdOpin.style.color = '#f59e0b';
		row.appendChild(tdOpin);

		const tdPremium = document.createElement('td');
		tdPremium.textContent = (costDelta >= 0 ? '+' : '') + '$' + costDelta.toFixed(3);
		tdPremium.style.backgroundColor = '#1e293b';
		tdPremium.style.color = costDelta > 0 ? '#ef4444' : '#22c55e';
		row.appendChild(tdPremium);

		const tdCog = document.createElement('td');
		tdCog.textContent = cogDelta > 0 ? `-${cogDelta} (${cogPct}% simpler)` : 'No change';
		tdCog.style.backgroundColor = '#1e293b';
		tdCog.style.color = cogDelta > 0 ? '#22c55e' : '#94a3b8';
		row.appendChild(tdCog);

		const tdVerdict = document.createElement('td');
		tdVerdict.textContent = verdict;
		tdVerdict.style.backgroundColor = '#1e293b';
		tdVerdict.style.color = verdictColor;
		tdVerdict.style.fontWeight = '600';
		row.appendChild(tdVerdict);

		tbody.appendChild(row);
	});
	table.appendChild(tbody);
})();
```

- [ ] **Step 9: Verify the Pareto scatter and marginal table render**

Run: `open /Users/brianruggieri/git/claude_personalities/_metrics/dashboard-option-b.html`

Expected:
- Scatter plot with 15 points (5 tasks x 3 profiles), each labeled on hover with task name, cost, and cognitive complexity.
- The ex-bowling points should show clear separation: opinionated in the lower-right (higher cost, much lower complexity), blank in the lower-left (lower cost, moderate complexity), main in the upper-right (higher cost, highest complexity).
- Marginal cost table showing that ex-bowling is the only task where the opinionated premium "pays off" with measurable cognitive improvement.

#### Part D: Qualify findings with n=1 caveats

- [ ] **Step 10: Update the Key Findings section**

Find the `<ul>` inside the `<div class="findings">` section (search for `Key Findings`). Replace the entire `<ul>...</ul>` block with:

```html
<ul>
	<li><span class="highlight">Caveat: all results are n=1</span> (single run per task per profile). Differences described below are observed, not statistically confirmed. Run 3+ repetitions before drawing conclusions.</li>
	<li><span class="highlight">ex-bowling</span> shows the largest observed profile differentiation: opinionated produced <span class="highlight">max_function_length=19</span> vs main=64, and <span class="highlight">cognitive_complexity_max=11</span> vs main=38. This is the only task where the opinionated cost premium (+$0.10 over blank) corresponded to measurably different code structure.</li>
	<li><span class="highlight">3 of 5 tasks</span> (he-000, ce-000, rf-001) produced identical or near-identical code across all profiles. This suggests personality differentiation only manifests when the task has high design latitude &mdash; multiple valid architectures for the same problem.</li>
	<li><span class="highlight">blank was cheapest in this run</span> &mdash; 30&ndash;45% less expensive than opinionated on most tasks. Whether this holds across repeated runs requires variance estimation.</li>
	<li><span class="highlight">ce-000-regex-utils</span> was the most expensive task ($0.35&ndash;$0.42) across all profiles, likely due to multi-method class construction and extensive test interaction.</li>
</ul>
```

- [ ] **Step 11: Update the subtitle to reflect n=1**

Find the `<div class="subtitle">` element in the header section. Change from:

```html
<div class="subtitle">Generated 2026-03-16 &bull; Profiles: blank, main, opinionated &bull; 5 benchmark tasks</div>
```

to:

```html
<div class="subtitle">Generated 2026-03-16 &bull; Profiles: blank, main, opinionated &bull; 5 benchmark tasks &bull; n=1 per cell (pilot run)</div>
```

- [ ] **Step 12: Commit all dashboard changes**

All edits (radar chart, new charts, findings text, subtitle) are in the same file. Commit them together:

```bash
git add _metrics/dashboard-option-b.html
git commit -m "Improve dashboard: focused radar, token efficiency, Pareto chart, n=1 caveats"
```

---

### Task 3: Testing — Validation & Experiment Execution

**Owner:** Testing team
**Goal:** Validate all changes from Tasks 1 and 2, then provide instructions for multi-run execution.

**Files:**
- Read: `_metrics/dashboard-option-b.html` (validate visually)
- Read: `benchmarks/analyzers/duplicate_blocks.py` (validate fix)
- Create: `benchmarks/analyzers/test_analyzers.py` (consolidated test suite)

**Dependencies:** Tasks 1 and 2 must be complete.

#### Part A: Validate analyzer fixes

- [ ] **Step 1: Write a consolidated analyzer test suite**

Create `benchmarks/analyzers/test_analyzers.py`:

```python
#!/usr/bin/env python3
"""Consolidated test suite for all benchmark analyzers.

Runs each analyzer against known inputs and validates output format
and reasonable values. Not exhaustive — focuses on regressions.
"""
import os
import subprocess
import sys
import tempfile

ANALYZER_DIR = os.path.dirname(os.path.abspath(__file__))
PASS_COUNT = 0
FAIL_COUNT = 0


def run_analyzer(script_name, code, extra_args=None):
	"""Run an analyzer script on temp code, return stdout lines."""
	with tempfile.TemporaryDirectory() as tmpdir:
		filepath = os.path.join(tmpdir, 'module.py')
		with open(filepath, 'w') as f:
			f.write(code)
		cmd = [sys.executable, os.path.join(ANALYZER_DIR, script_name), tmpdir]
		if extra_args:
			cmd.extend(extra_args)
		result = subprocess.run(cmd, capture_output=True, text=True)
		return result.stdout.strip().split('\n')


def parse_metrics(lines):
	"""Parse KEY:VALUE lines into a dict."""
	metrics = {}
	for line in lines:
		if ':' in line:
			key, val = line.split(':', 1)
			try:
				metrics[key] = float(val) if '.' in val else int(val)
			except ValueError:
				metrics[key] = val
	return metrics


def check(name, condition, detail=''):
	global PASS_COUNT, FAIL_COUNT
	if condition:
		PASS_COUNT += 1
		print(f"  PASS: {name}")
	else:
		FAIL_COUNT += 1
		print(f"  FAIL: {name} {detail}")


SAMPLE_CODE = '''
class BowlingGame:
    """A bowling game scorer."""

    def __init__(self):
        self.rolls = []

    def roll(self, pins):
        """Record a roll."""
        if not isinstance(pins, int) or pins < 0:
            raise ValueError("Invalid pins")
        self.rolls.append(pins)

    def score(self):
        """Calculate total score."""
        total = 0
        roll_index = 0
        for frame in range(10):
            if self._is_strike(roll_index):
                total += 10 + self._strike_bonus(roll_index)
                roll_index += 1
            elif self._is_spare(roll_index):
                total += 10 + self._spare_bonus(roll_index)
                roll_index += 2
            else:
                total += self.rolls[roll_index] + self.rolls[roll_index + 1]
                roll_index += 2
        return total

    def _is_strike(self, index):
        return self.rolls[index] == 10

    def _is_spare(self, index):
        return self.rolls[index] + self.rolls[index + 1] == 10

    def _strike_bonus(self, index):
        return self.rolls[index + 1] + self.rolls[index + 2]

    def _spare_bonus(self, index):
        return self.rolls[index + 2]
'''

# --- duplicate_blocks.py ---
print("\n=== duplicate_blocks.py ===")
metrics = parse_metrics(run_analyzer('duplicate_blocks.py', SAMPLE_CODE))
check('outputs DUPLICATE_BLOCKS', 'DUPLICATE_BLOCKS' in metrics)
check('outputs DUPLICATE_SCORE', 'DUPLICATE_SCORE' in metrics)
check('blocks is reasonable (< 10)', metrics.get('DUPLICATE_BLOCKS', 999) < 10,
      f"got {metrics.get('DUPLICATE_BLOCKS')}")

# --- cognitive_complexity.py ---
print("\n=== cognitive_complexity.py ===")
metrics = parse_metrics(run_analyzer('cognitive_complexity.py', SAMPLE_CODE))
check('outputs COGNITIVE_COMPLEXITY_AVG', 'COGNITIVE_COMPLEXITY_AVG' in metrics)
check('outputs COGNITIVE_COMPLEXITY_MAX', 'COGNITIVE_COMPLEXITY_MAX' in metrics)
check('max >= avg', metrics.get('COGNITIVE_COMPLEXITY_MAX', 0) >= metrics.get('COGNITIVE_COMPLEXITY_AVG', 0))

# --- halstead.py ---
print("\n=== halstead.py ===")
metrics = parse_metrics(run_analyzer('halstead.py', SAMPLE_CODE))
check('outputs MAINTAINABILITY_INDEX', 'MAINTAINABILITY_INDEX' in metrics)
check('MI in range 0-100', 0 <= metrics.get('MAINTAINABILITY_INDEX', -1) <= 100,
      f"got {metrics.get('MAINTAINABILITY_INDEX')}")

# --- naming_quality.py ---
print("\n=== naming_quality.py ===")
metrics = parse_metrics(run_analyzer('naming_quality.py', SAMPLE_CODE))
check('outputs NAMING_SCORE', 'NAMING_SCORE' in metrics)
check('score in range 0-100', 0 <= metrics.get('NAMING_SCORE', -1) <= 100)

# --- personality_compliance.py ---
print("\n=== personality_compliance.py ===")
metrics = parse_metrics(run_analyzer('personality_compliance.py', SAMPLE_CODE, ['main']))
check('outputs PERSONALITY_COMPLIANCE', 'PERSONALITY_COMPLIANCE' in metrics)
check('outputs PERSONALITY_VIOLATIONS', 'PERSONALITY_VIOLATIONS' in metrics)
check('compliance in range 0-100', 0 <= metrics.get('PERSONALITY_COMPLIANCE', -1) <= 100)

# --- security_smells.py ---
print("\n=== security_smells.py ===")
metrics = parse_metrics(run_analyzer('security_smells.py', SAMPLE_CODE))
check('outputs SECURITY_SMELLS', 'SECURITY_SMELLS' in metrics)
check('no smells in clean code', metrics.get('SECURITY_SMELLS', -1) == 0)

# --- overengineering.py ---
print("\n=== overengineering.py ===")
# Overengineering needs a task.json — test with a fake one
with tempfile.TemporaryDirectory() as tmpdir:
	with open(os.path.join(tmpdir, 'module.py'), 'w') as f:
		f.write(SAMPLE_CODE)
	task_json = os.path.join(tmpdir, 'task.json')
	with open(task_json, 'w') as f:
		f.write('{"expected_complexity": {"max_files": 2, "max_classes": 2, "max_functions": 10, "max_lines": 100}}')
	result = subprocess.run(
		[sys.executable, os.path.join(ANALYZER_DIR, 'overengineering.py'), tmpdir, task_json],
		capture_output=True, text=True
	)
	metrics = parse_metrics(result.stdout.strip().split('\n'))
check('outputs OVERENGINEERING_SCORE', 'OVERENGINEERING_SCORE' in metrics)

# --- Summary ---
print(f"\n{'='*40}")
print(f"Results: {PASS_COUNT} passed, {FAIL_COUNT} failed")
if FAIL_COUNT > 0:
	sys.exit(1)
```

- [ ] **Step 2: Run the consolidated test suite**

Run: `cd /Users/brianruggieri/git/claude_personalities && python3 benchmarks/analyzers/test_analyzers.py`

Expected: All tests pass. If the duplicate_blocks test fails, the Task 1 fix was not applied correctly — go back and verify.

- [ ] **Step 3: Commit the test suite**

```bash
git add benchmarks/analyzers/test_analyzers.py
git commit -m "Add consolidated analyzer test suite"
```

#### Part B: Validate dashboard visually

- [ ] **Step 4: Open the dashboard and check each visualization**

Run: `open /Users/brianruggieri/git/claude_personalities/_metrics/dashboard-option-b.html`

Checklist:
- [ ] Summary cards: 3 cards showing total cost and avg duration per profile
- [ ] Cost per task: 5 grouped bars, 3 colors, readable labels
- [ ] Duration per task: Same layout as cost
- [ ] Radar chart: **3 axes only** (Function Decomposition, Cognitive Simplicity, Cyclomatic Control). Opinionated polygon visibly larger.
- [ ] Max Function Length: Opinionated's ex-bowling bar at 19, main's at 64
- [ ] **NEW** Token Efficiency: 5 grouped bars showing tokens/line
- [ ] **NEW** Cost vs Cognitive Complexity scatter: 15 points, hover shows task name
- [ ] **NEW** Marginal Cost table: 5 rows with verdict column
- [ ] Complexity Heatmap: Green/yellow/red gradient, numbers legible
- [ ] Key Findings: Starts with n=1 caveat, no "consistently" without qualification

- [ ] **Step 5: Test responsive layout**

Resize browser to < 640px width. Verify all charts stack vertically and remain readable.

- [ ] **Step 6: Check for JavaScript errors**

Open browser DevTools (Cmd+Option+I → Console tab). Verify no errors.

#### Part C: Document multi-run execution instructions

- [ ] **Step 7: Verify the multi-run execution script is ready**

Confirm that `./setup.sh benchmark --task <name>` produces timestamped JSON files in `_metrics/benchmarks/<profile>/<task>/`. Multiple runs of the same task should create separate files (not overwrite).

Run a quick check (do NOT actually run a benchmark — just verify the command exists):

```bash
grep -n 'benchmark' setup.sh | head -20
```

Expected: Should see benchmark-related functions in setup.sh.

- [ ] **Step 8: Write a results aggregation script for multi-run data**

Create `benchmarks/aggregate-results.py`:

```python
#!/usr/bin/env python3
"""Aggregate multiple benchmark runs per (profile, task) into summary statistics.

Usage: python3 aggregate-results.py <metrics_dir>
Reads: <metrics_dir>/benchmarks/<profile>/<task>/*.json
Outputs: JSON with median, IQR, and count per metric per (profile, task).
"""
import json
import os
import statistics
import sys


def aggregate(metrics_dir):
	benchmarks_dir = os.path.join(metrics_dir, 'benchmarks')
	if not os.path.isdir(benchmarks_dir):
		print(f"Error: {benchmarks_dir} not found", file=sys.stderr)
		sys.exit(1)

	# Field names match the JSON result files (not the dashboard's JS data objects,
	# which use shorter names like 'output_tokens' and 'lines').
	KEY_METRICS = [
		'cost_usd', 'duration_seconds', 'cognitive_complexity_max',
		'max_function_length', 'complexity_max', 'maintainability_index',
		'personality_compliance', 'lines_generated', 'total_output_tokens'
	]

	results = {}

	for profile in sorted(os.listdir(benchmarks_dir)):
		profile_dir = os.path.join(benchmarks_dir, profile)
		if not os.path.isdir(profile_dir):
			continue

		results[profile] = {}

		for task in sorted(os.listdir(profile_dir)):
			task_dir = os.path.join(profile_dir, task)
			if not os.path.isdir(task_dir):
				continue

			# Collect all JSON result files for this (profile, task)
			runs = []
			for fname in sorted(os.listdir(task_dir)):
				if fname.endswith('.json'):
					with open(os.path.join(task_dir, fname)) as f:
						runs.append(json.load(f))

			if not runs:
				continue

			summary = {'n': len(runs), 'metrics': {}}

			for metric in KEY_METRICS:
				values = [r.get(metric) for r in runs if r.get(metric) is not None]
				if not values:
					continue

				if len(values) == 1:
					summary['metrics'][metric] = {
						'median': values[0],
						'iqr_low': values[0],
						'iqr_high': values[0],
						'n': 1
					}
				else:
					values.sort()
					med = statistics.median(values)
					q1 = statistics.median(values[:len(values)//2])
					q3 = statistics.median(values[len(values)//2 + (len(values) % 2):])
					summary['metrics'][metric] = {
						'median': round(med, 4),
						'iqr_low': round(q1, 4),
						'iqr_high': round(q3, 4),
						'n': len(values)
					}

			results[profile][task] = summary

	print(json.dumps(results, indent=2))


if __name__ == '__main__':
	if len(sys.argv) < 2:
		print("Usage: python3 aggregate-results.py <metrics_dir>")
		sys.exit(1)
	aggregate(sys.argv[1])
```

- [ ] **Step 9: Test the aggregation script against existing single-run data**

```bash
python3 benchmarks/aggregate-results.py _metrics/
```

Expected: JSON output with n=1 for each (profile, task) pair, where median = the single observed value.

- [ ] **Step 10: Commit the aggregation script**

```bash
git add benchmarks/aggregate-results.py
git commit -m "Add multi-run results aggregation script"
```

#### Part D: Final integration check

- [ ] **Step 11: Run all analyzer tests one final time**

```bash
python3 benchmarks/analyzers/test_duplicate_blocks.py && python3 benchmarks/analyzers/test_analyzers.py
```

Expected: All tests pass.

- [ ] **Step 12: Verify git status is clean**

```bash
git status
git log --oneline -5
```

Expected: No uncommitted changes. Recent commits should include:
1. Fix duplicate_blocks analyzer
2. Add personality_compliance diagnostic
3. Add multi-run experimental protocol
4. Improve dashboard (radar, charts, caveats)
5. Add consolidated analyzer test suite
6. Add multi-run results aggregation script
