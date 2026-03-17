#!/usr/bin/env python3
"""Measure error handling patterns in Python code.

Usage: python3 error_handling_density.py <dir>
Output: ERROR_HANDLING_TRY_COUNT:<int>
        ERROR_HANDLING_RAISE_COUNT:<int>
        ERROR_HANDLING_GUARD_CLAUSES:<int>
        ERROR_HANDLING_DENSITY:<float>
Always exits 0.
"""
import ast
import os
import sys


def count_guard_clauses(func_node):
	"""Count guard clauses in a function.

	A guard clause is an ast.If in the first 3 statements of
	a function body that contains a Return or Raise in its
	if-body (not in orelse).
	"""
	count = 0
	body = func_node.body
	check_limit = min(3, len(body))

	for stmt in body[:check_limit]:
		if not isinstance(stmt, ast.If):
			continue
		# Walk only the if-body (stmt.body), not stmt.orelse
		for node in ast.walk(ast.Module(body=stmt.body, type_ignores=[])):
			if isinstance(node, (ast.Return, ast.Raise)):
				count += 1
				break

	return count


def count_lines(filepath):
	"""Count non-blank, non-comment lines."""
	count = 0
	try:
		with open(filepath, errors='replace') as f:
			for line in f:
				stripped = line.strip()
				if stripped and not stripped.startswith('#'):
					count += 1
	except OSError:
		pass
	return count


try:
	target_dir = sys.argv[1]
	try_count = 0
	raise_count = 0
	guard_count = 0
	total_loc = 0

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					tree = ast.parse(f.read())
			except (SyntaxError, OSError):
				continue

			total_loc += count_lines(filepath)

			for node in ast.walk(tree):
				if isinstance(node, ast.Try):
					try_count += 1
				elif isinstance(node, ast.Raise):
					raise_count += 1
				elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
					guard_count += count_guard_clauses(node)

	total_handlers = try_count + raise_count + guard_count
	density = round(total_handlers / total_loc * 100, 2) if total_loc > 0 else 0.0

	print(f"ERROR_HANDLING_TRY_COUNT:{try_count}")
	print(f"ERROR_HANDLING_RAISE_COUNT:{raise_count}")
	print(f"ERROR_HANDLING_GUARD_CLAUSES:{guard_count}")
	print(f"ERROR_HANDLING_DENSITY:{density}")
except Exception:
	print("ERROR_HANDLING_TRY_COUNT:0")
	print("ERROR_HANDLING_RAISE_COUNT:0")
	print("ERROR_HANDLING_GUARD_CLAUSES:0")
	print("ERROR_HANDLING_DENSITY:0.0")

sys.exit(0)
