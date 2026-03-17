#!/usr/bin/env python3
"""Count functions in generated code to measure decomposition.

Usage: python3 function_count.py <dir>
Output: FUNCTION_COUNT:<total int>
        FUNCTION_COUNT_AVG_PER_FILE:<float>
Always exits 0.
"""
import ast
import os
import re
import sys


JS_FUNCTION_RE = re.compile(r'(?:function\s+\w+|=>\s*\{)')


def count_python_functions(filepath):
	"""Count functions in a Python file via AST."""
	try:
		with open(filepath) as f:
			tree = ast.parse(f.read())
	except (SyntaxError, OSError):
		return 0
	count = 0
	for node in ast.walk(tree):
		if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
			count += 1
	return count


def count_js_functions(filepath):
	"""Count functions in a JS/TS file via regex. Best-effort."""
	try:
		with open(filepath, errors='replace') as f:
			content = f.read()
	except OSError:
		return 0
	return len(JS_FUNCTION_RE.findall(content))


try:
	target_dir = sys.argv[1]
	total_functions = 0
	file_count = 0

	py_extensions = {'.py'}
	js_extensions = {'.js', '.jsx', '.ts', '.tsx'}

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			_, ext = os.path.splitext(fname)

			if ext in py_extensions:
				total_functions += count_python_functions(filepath)
				file_count += 1
			elif ext in js_extensions:
				total_functions += count_js_functions(filepath)
				file_count += 1

	avg = round(total_functions / file_count, 2) if file_count > 0 else 0.0

	print(f"FUNCTION_COUNT:{total_functions}")
	print(f"FUNCTION_COUNT_AVG_PER_FILE:{avg}")
except Exception:
	print("FUNCTION_COUNT:0")
	print("FUNCTION_COUNT_AVG_PER_FILE:0.0")

sys.exit(0)
