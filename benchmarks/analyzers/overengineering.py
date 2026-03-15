#!/usr/bin/env python3
"""Detect over-engineering in benchmark task output.

Usage: python3 overengineering.py <dir> <task_json_path>
Output: OVERENGINEERING_SCORE:<0-100>  (100 = no over-engineering)
Always exits 0.
"""
import ast
import json
import os
import re
import sys

SKIP_PREFIXES = ('.', '_')


def count_python_constructs(filepath):
	classes = functions = 0
	try:
		with open(filepath) as f:
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
	classes = functions = 0
	try:
		with open(filepath) as f:
			content = f.read()
		classes = len(re.findall(r'\bclass\s+\w+', content))
		functions = len(re.findall(r'(?:function\s+\w+|=>\s*\{)', content))
	except OSError:
		pass
	return classes, functions


def count_lines(filepath):
	count = 0
	try:
		with open(filepath, errors='replace') as f:
			for line in f:
				stripped = line.strip()
				if stripped and not stripped.startswith('#') and not stripped.startswith('//'):
					count += 1
	except OSError:
		pass
	return count


try:
	target_dir = sys.argv[1]
	task_json_path = sys.argv[2]

	with open(task_json_path) as f:
		task = json.load(f)

	complexity = task.get('expected_complexity', {})
	max_files = complexity.get('max_files', 10)
	max_classes = complexity.get('max_classes', 5)
	max_functions = complexity.get('max_functions', 10)
	max_lines = complexity.get('max_lines', 200)
	disallow_patterns = complexity.get('disallow_patterns', [])

	# Identify fixture files
	fixture_names = set()
	fixture_dir = os.path.join(os.path.dirname(task_json_path), 'fixture')
	if os.path.isdir(fixture_dir):
		for fname in os.listdir(fixture_dir):
			fixture_names.add(fname)

	generated_files = []
	total_classes = total_functions = total_lines = 0
	disallowed_found = 0

	for fname in os.listdir(target_dir):
		if fname in fixture_names or any(fname.startswith(p) for p in SKIP_PREFIXES):
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
			try:
				with open(filepath, errors='replace') as f:
					content = f.read()
				for pattern in disallow_patterns:
					if pattern in content or fname == pattern:
						disallowed_found += 1
			except OSError:
				pass

	excess_files = max(0, len(generated_files) - max_files)
	excess_classes = max(0, total_classes - max_classes)
	excess_functions = max(0, total_functions - max_functions)
	excess_lines = max(0, total_lines - max_lines)

	deductions = (
		excess_files * 15
		+ excess_classes * 20
		+ excess_functions * 5
		+ (excess_lines // 10) * 2
		+ disallowed_found * 25
	)
	score = max(0, 100 - deductions)

	print(f"OVERENGINEERING_SCORE:{score}")

except Exception:
	print("OVERENGINEERING_SCORE:100")

sys.exit(0)
