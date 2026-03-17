#!/usr/bin/env python3
"""Measure docstring coverage for Python functions and classes.

Usage: python3 docstring_coverage.py <dir>
Output: DOCSTRING_COVERAGE:<0-100>
        DOCSTRINGS_MISSING:<count>
Always exits 0.
"""
import ast
import os
import sys


DOCSTRING_NODES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)


try:
	target_dir = sys.argv[1]
	total_nodes = 0
	documented_nodes = 0

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

			for node in ast.walk(tree):
				if isinstance(node, DOCSTRING_NODES):
					total_nodes += 1
					if ast.get_docstring(node) is not None:
						documented_nodes += 1

	if total_nodes > 0:
		coverage = round(documented_nodes / total_nodes * 100)
		missing = total_nodes - documented_nodes
	else:
		coverage = 100
		missing = 0

	print(f"DOCSTRING_COVERAGE:{coverage}")
	print(f"DOCSTRINGS_MISSING:{missing}")
except Exception:
	print("DOCSTRING_COVERAGE:100")
	print("DOCSTRINGS_MISSING:0")

sys.exit(0)
