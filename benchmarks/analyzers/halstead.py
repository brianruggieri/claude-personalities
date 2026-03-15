#!/usr/bin/env python3
"""Halstead complexity metrics and Maintainability Index for Python files.

Usage: python3 halstead.py <dir>
Output: HALSTEAD_VOLUME:<float>
        HALSTEAD_DIFFICULTY:<float>
        MAINTAINABILITY_INDEX:<float>
Always exits 0.
"""
import ast
import math
import os
import sys


OPERATOR_NODE_TYPES = (
	ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Mod, ast.Pow, ast.FloorDiv,
	ast.LShift, ast.RShift, ast.BitOr, ast.BitXor, ast.BitAnd,
	ast.And, ast.Or, ast.Not, ast.UAdd, ast.USub, ast.Invert,
	ast.Eq, ast.NotEq, ast.Lt, ast.LtE, ast.Gt, ast.GtE, ast.Is, ast.IsNot,
	ast.In, ast.NotIn,
)


def extract_halstead(tree):
	"""Extract Halstead operator/operand counts from an AST."""
	operators = {}
	operands = {}

	for node in ast.walk(tree):
		# Binary operators
		if isinstance(node, ast.BinOp):
			op_name = type(node.op).__name__
			operators[op_name] = operators.get(op_name, 0) + 1

		# Unary operators
		elif isinstance(node, ast.UnaryOp):
			op_name = type(node.op).__name__
			operators[op_name] = operators.get(op_name, 0) + 1

		# Boolean operators
		elif isinstance(node, ast.BoolOp):
			op_name = type(node.op).__name__
			# BoolOp with N values has N-1 operations
			count = len(node.values) - 1
			operators[op_name] = operators.get(op_name, 0) + count

		# Comparison operators
		elif isinstance(node, ast.Compare):
			for op in node.ops:
				op_name = type(op).__name__
				operators[op_name] = operators.get(op_name, 0) + 1

		# Assignments
		elif isinstance(node, ast.Assign):
			operators['Assign'] = operators.get('Assign', 0) + 1

		elif isinstance(node, ast.AugAssign):
			op_name = 'Aug' + type(node.op).__name__
			operators[op_name] = operators.get(op_name, 0) + 1

		# Operands: names
		elif isinstance(node, ast.Name):
			operands[node.id] = operands.get(node.id, 0) + 1

		# Operands: constants (Num/Str/etc. unified under Constant in 3.8+)
		elif isinstance(node, ast.Constant):
			key = repr(node.value)
			operands[key] = operands.get(key, 0) + 1

	return operators, operands


def cyclomatic_complexity(tree):
	"""Compute cyclomatic complexity for the entire module."""
	complexity = 1
	for node in ast.walk(tree):
		if isinstance(node, (ast.If, ast.For, ast.While, ast.AsyncFor)):
			complexity += 1
		elif isinstance(node, ast.BoolOp) and isinstance(node.op, (ast.And, ast.Or)):
			complexity += len(node.values) - 1
		elif isinstance(node, ast.ExceptHandler):
			complexity += 1
	return complexity


try:
	target_dir = sys.argv[1]
	all_operators = {}
	all_operands = {}
	total_loc = 0
	total_cc = 0
	file_count = 0

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					source = f.read()
				tree = ast.parse(source)
			except (SyntaxError, OSError):
				continue

			file_count += 1

			# Count non-blank, non-comment lines
			for line in source.splitlines():
				stripped = line.strip()
				if stripped and not stripped.startswith('#'):
					total_loc += 1

			total_cc += cyclomatic_complexity(tree)

			ops, opnds = extract_halstead(tree)
			for k, v in ops.items():
				all_operators[k] = all_operators.get(k, 0) + v
			for k, v in opnds.items():
				all_operands[k] = all_operands.get(k, 0) + v

	n1 = len(all_operators)
	n2 = len(all_operands)
	big_n1 = sum(all_operators.values())
	big_n2 = sum(all_operands.values())

	vocab = n1 + n2
	length = big_n1 + big_n2

	if vocab > 0 and n2 > 0:
		volume = length * math.log2(vocab)
		difficulty = (n1 / 2.0) * (big_n2 / n2)
	else:
		volume = 0.0
		difficulty = 0.0

	# Maintainability Index
	avg_cc = total_cc / file_count if file_count > 0 else 0
	if volume > 0 and total_loc > 0:
		raw_mi = 171 - 5.2 * math.log(volume) - 0.23 * avg_cc - 16.2 * math.log(total_loc)
		mi = max(0.0, min(100.0, raw_mi * 100.0 / 171.0))
	else:
		mi = 100.0

	print(f"HALSTEAD_VOLUME:{volume:.2f}")
	print(f"HALSTEAD_DIFFICULTY:{difficulty:.2f}")
	print(f"MAINTAINABILITY_INDEX:{mi:.2f}")
except Exception:
	print("HALSTEAD_VOLUME:0.00")
	print("HALSTEAD_DIFFICULTY:0.00")
	print("MAINTAINABILITY_INDEX:100.00")

sys.exit(0)
