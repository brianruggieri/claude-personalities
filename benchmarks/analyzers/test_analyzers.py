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

# --- function_count.py ---
print("\n=== function_count.py ===")
metrics = parse_metrics(run_analyzer('function_count.py', SAMPLE_CODE))
check('outputs FUNCTION_COUNT', 'FUNCTION_COUNT' in metrics)
check('outputs FUNCTION_COUNT_AVG_PER_FILE', 'FUNCTION_COUNT_AVG_PER_FILE' in metrics)
check('counts 7 functions in sample', metrics.get('FUNCTION_COUNT') == 7,
      f"got {metrics.get('FUNCTION_COUNT')}")
check('avg is 7.0 (one file)', metrics.get('FUNCTION_COUNT_AVG_PER_FILE') == 7.0,
      f"got {metrics.get('FUNCTION_COUNT_AVG_PER_FILE')}")

# --- type_annotation_coverage.py ---
print("\n=== type_annotation_coverage.py ===")
metrics = parse_metrics(run_analyzer('type_annotation_coverage.py', SAMPLE_CODE))
check('outputs TYPE_ANNOTATION_COVERAGE', 'TYPE_ANNOTATION_COVERAGE' in metrics)
check('outputs TYPE_ANNOTATIONS_MISSING', 'TYPE_ANNOTATIONS_MISSING' in metrics)
check('coverage is 0 (no annotations in sample)', metrics.get('TYPE_ANNOTATION_COVERAGE') == 0,
      f"got {metrics.get('TYPE_ANNOTATION_COVERAGE')}")
check('missing count > 0', metrics.get('TYPE_ANNOTATIONS_MISSING', 0) > 0,
      f"got {metrics.get('TYPE_ANNOTATIONS_MISSING')}")

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

# --- Summary ---
print(f"\n{'='*40}")
print(f"Results: {PASS_COUNT} passed, {FAIL_COUNT} failed")
if FAIL_COUNT > 0:
	sys.exit(1)
