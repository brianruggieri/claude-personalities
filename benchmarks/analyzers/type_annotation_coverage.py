#!/usr/bin/env python3
"""Measure type annotation coverage for Python functions.

Usage: python3 type_annotation_coverage.py <dir>
Output: TYPE_ANNOTATION_COVERAGE:<0-100>
        TYPE_ANNOTATIONS_MISSING:<count>
Always exits 0.
"""
import ast
import os
import sys


def check_function_annotations(node):
	"""Check if a function has full type annotations.

	Returns (is_fully_annotated, missing_count).
	"""
	missing = 0

	if node.returns is None:
		missing += 1

	for arg in node.args.args:
		if arg.arg in ('self', 'cls'):
			continue
		if arg.annotation is None:
			missing += 1

	return missing == 0, missing


try:
	target_dir = sys.argv[1]
	total_functions = 0
	annotated_functions = 0
	total_missing = 0

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
				if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
					total_functions += 1
					is_annotated, missing = check_function_annotations(node)
					if is_annotated:
						annotated_functions += 1
					total_missing += missing

	if total_functions > 0:
		coverage = round(annotated_functions / total_functions * 100)
	else:
		coverage = 100

	print(f"TYPE_ANNOTATION_COVERAGE:{coverage}")
	print(f"TYPE_ANNOTATIONS_MISSING:{total_missing}")
except Exception:
	print("TYPE_ANNOTATION_COVERAGE:0")
	print("TYPE_ANNOTATIONS_MISSING:0")

sys.exit(0)
