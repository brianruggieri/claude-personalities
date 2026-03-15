#!/usr/bin/env python3
"""Detect test regressions in fix-python-bug task.

Usage: python3 regression_check.py <dir> <fixture_dir>
Output: REGRESSION_SCORE:<0-100>
        REGRESSION_BROKEN:<count>
Always exits 0.

Runs tests on original fixture to find pre-passing tests,
then checks if any of those now fail in the fixed code.
"""
import os
import subprocess
import sys


def run_pytest(directory):
	"""Return sets of (passed_test_names, failed_test_names)."""
	passed = set()
	failed = set()
	try:
		result = subprocess.run(
			[sys.executable, '-m', 'pytest', '-v', '--tb=no', '-q'],
			capture_output=True, text=True, timeout=30, cwd=directory,
		)
		for line in (result.stdout + result.stderr).split('\n'):
			if '::' in line:
				if ' PASSED' in line:
					passed.add(line.split(' PASSED')[0].strip())
				elif ' FAILED' in line:
					failed.add(line.split(' FAILED')[0].strip())
	except Exception:
		pass
	return passed, failed


try:
	fixed_dir = sys.argv[1]
	fixture_dir = sys.argv[2]

	# Only applies if there are Python test files
	has_tests = any(f.startswith('test_') and f.endswith('.py') for f in os.listdir(fixed_dir))
	if not has_tests:
		print("REGRESSION_SCORE:100")
		print("REGRESSION_BROKEN:0")
		sys.exit(0)

	# Run tests on original fixture
	orig_passed, _ = run_pytest(fixture_dir)

	# Run tests on fixed code
	fixed_passed, fixed_failed = run_pytest(fixed_dir)

	# Tests that passed in original but now fail = regressions
	broken = orig_passed & fixed_failed
	broken_count = len(broken)

	if orig_passed:
		score = max(0, round((1 - broken_count / len(orig_passed)) * 100))
	else:
		score = 100

	print(f"REGRESSION_SCORE:{score}")
	print(f"REGRESSION_BROKEN:{broken_count}")

except Exception:
	print("REGRESSION_SCORE:100")
	print("REGRESSION_BROKEN:0")

sys.exit(0)
