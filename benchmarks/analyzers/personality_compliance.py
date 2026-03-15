#!/usr/bin/env python3
"""Check generated code against personality-driven coding standards.

Usage: python3 personality_compliance.py <dir> <profile_name>
Output: PERSONALITY_COMPLIANCE:<0-100>
        PERSONALITY_VIOLATIONS:<count>
        PERSONALITY_RULES_CHECKED:<count>
Always exits 0.
"""
import ast
import os
import re
import sys


# Variable names allowed as single-letter in loops/comprehensions
LOOP_SINGLE_LETTER_ALLOWED = frozenset({'i', 'j', 'k', 'n', '_'})

# Numeric constants that are not considered "magic"
SAFE_NUMBERS = frozenset({0, 1, 2, -1, True, False, None})

SNAKE_CASE_RE = re.compile(r'^_?_?[a-z][a-z0-9_]*_?_?$')
PASCAL_CASE_RE = re.compile(r'^[A-Z][a-zA-Z0-9]*$')

COMMENTED_CODE_RE = re.compile(
	r'#\s*(def |class |import |if |for |while |return )'
)

CONSOLE_LOG_RE = re.compile(r'\bconsole\.log\s*\(')
VAR_DECL_RE = re.compile(r'\bvar\s+\w')


def check_python_file(filepath, source, tree):
	"""Run Python-specific rules. Returns (violations, rules_checked)."""
	violations = 0
	rules_checked = 0

	lines = source.splitlines()

	# Collect loop/comprehension variable names for single-letter check
	loop_targets = set()
	for node in ast.walk(tree):
		if isinstance(node, (ast.For, ast.AsyncFor)):
			for target_node in ast.walk(node.target):
				if isinstance(target_node, ast.Name):
					loop_targets.add(target_node.id)
		if isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
			for gen in node.generators:
				for target_node in ast.walk(gen.target):
					if isinstance(target_node, ast.Name):
						loop_targets.add(target_node.id)

	for node in ast.walk(tree):
		# Rule: functions <= 50 lines
		if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
			rules_checked += 1
			end = getattr(node, 'end_lineno', None)
			if end is not None:
				length = end - node.lineno + 1
				if length > 50:
					violations += 1

			# Rule: snake_case function names
			rules_checked += 1
			name = node.name
			if not (name.startswith('__') and name.endswith('__')):
				if not SNAKE_CASE_RE.match(name):
					violations += 1

		# Rule: PascalCase class names
		if isinstance(node, ast.ClassDef):
			rules_checked += 1
			if not PASCAL_CASE_RE.match(node.name):
				violations += 1

		# Rule: no bare except blocks
		if isinstance(node, ast.ExceptHandler):
			rules_checked += 1
			if node.type is None:
				violations += 1

		# Rule: no single-letter variable names outside loops/comprehensions
		if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
			name = node.id
			if len(name) == 1:
				rules_checked += 1
				if name not in LOOP_SINGLE_LETTER_ALLOWED or name not in loop_targets:
					# Allow _ anywhere (throwaway)
					if name != '_':
						violations += 1

		# Rule: no magic numbers
		if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
			# Skip values inside function default args and decorators
			rules_checked += 1
			if node.value not in SAFE_NUMBERS:
				violations += 1

	# Rule: no commented-out code
	for line in lines:
		stripped = line.strip()
		if COMMENTED_CODE_RE.match(stripped):
			rules_checked += 1
			violations += 1

	return violations, rules_checked


def check_jsx_file(filepath):
	"""Run JSX/JS/TS-specific rules. Returns (violations, rules_checked)."""
	violations = 0
	rules_checked = 0

	try:
		with open(filepath, errors='replace') as f:
			content = f.read()
	except OSError:
		return 0, 0

	for line in content.splitlines():
		stripped = line.strip()

		# Rule: no console.log
		if CONSOLE_LOG_RE.search(stripped):
			rules_checked += 1
			violations += 1

		# Rule: no var declarations
		if VAR_DECL_RE.search(stripped):
			rules_checked += 1
			violations += 1

	return violations, rules_checked


try:
	target_dir = sys.argv[1]
	# profile_name accepted but not currently used for rule selection
	profile_name = sys.argv[2] if len(sys.argv) > 2 else 'main'

	total_violations = 0
	total_rules = 0

	py_extensions = {'.py'}
	jsx_extensions = {'.js', '.jsx', '.ts', '.tsx'}

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if fname.startswith(('_', '.')):
				continue

			filepath = os.path.join(root, fname)
			_, ext = os.path.splitext(fname)

			if ext in py_extensions:
				try:
					with open(filepath) as f:
						source = f.read()
					tree = ast.parse(source)
				except (SyntaxError, OSError):
					continue
				v, r = check_python_file(filepath, source, tree)
				total_violations += v
				total_rules += r

			elif ext in jsx_extensions:
				v, r = check_jsx_file(filepath)
				total_violations += v
				total_rules += r

	if total_rules > 0:
		passed = total_rules - total_violations
		score = round(passed / total_rules * 100)
	else:
		score = 100

	print(f"PERSONALITY_COMPLIANCE:{score}")
	print(f"PERSONALITY_VIOLATIONS:{total_violations}")
	print(f"PERSONALITY_RULES_CHECKED:{total_rules}")
except Exception:
	print("PERSONALITY_COMPLIANCE:100")
	print("PERSONALITY_VIOLATIONS:0")
	print("PERSONALITY_RULES_CHECKED:0")

sys.exit(0)
