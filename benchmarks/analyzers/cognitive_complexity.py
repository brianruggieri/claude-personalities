#!/usr/bin/env python3
"""Cognitive complexity analysis for Python files.

Usage: python3 cognitive_complexity.py <dir>
Output: COGNITIVE_COMPLEXITY_AVG:<float>
        COGNITIVE_COMPLEXITY_MAX:<int>
Always exits 0.
"""
import ast
import os
import sys


CONTROL_FLOW_TYPES = (
	ast.If, ast.For, ast.While, ast.AsyncFor,
	ast.ExceptHandler,
)

BOOL_OP_TYPES = (ast.And, ast.Or)


def compute_cognitive_complexity(node):
	"""Walk a function AST and return its cognitive complexity score."""
	score = 0

	def walk(current, nesting):
		nonlocal score

		for child in ast.iter_child_nodes(current):
			increment = 0
			new_nesting = nesting

			if isinstance(child, CONTROL_FLOW_TYPES):
				increment = 1 + nesting
				new_nesting = nesting + 1
			elif isinstance(child, ast.BoolOp) and isinstance(child.op, BOOL_OP_TYPES):
				# Each boolean operator in a chain adds 1
				increment = len(child.values) - 1

			score += increment

			# elif counts as +1 (no nesting penalty) but doesn't increase nesting
			# In CPython AST, elif appears as an If inside the orelse of the parent If.
			# We handle this by checking if a child If is the sole orelse entry.
			if isinstance(child, ast.If) and isinstance(current, ast.If):
				if len(current.orelse) == 1 and current.orelse[0] is child:
					# This is an elif: undo nesting penalty, just count +1
					score -= nesting
					walk(child, nesting)
					continue

			walk(child, new_nesting)

	walk(node, 0)
	return score


try:
	target_dir = sys.argv[1]
	scores = []

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
					scores.append(compute_cognitive_complexity(node))

	if scores:
		avg = sum(scores) / len(scores)
		max_score = max(scores)
	else:
		avg = 0.0
		max_score = 0

	print(f"COGNITIVE_COMPLEXITY_AVG:{avg:.2f}")
	print(f"COGNITIVE_COMPLEXITY_MAX:{max_score}")
except Exception:
	print("COGNITIVE_COMPLEXITY_AVG:0.00")
	print("COGNITIVE_COMPLEXITY_MAX:0")

sys.exit(0)
