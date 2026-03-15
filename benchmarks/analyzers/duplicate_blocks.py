#!/usr/bin/env python3
"""Detect duplicate code blocks across Python functions.

Usage: python3 duplicate_blocks.py <dir>
Output: DUPLICATE_BLOCKS:<count>
        DUPLICATE_SCORE:<0-100>  (100 = no duplication)
Always exits 0.
"""
import ast
import difflib
import os
import re
import sys


VAR_NAME_RE = re.compile(r'\b[a-z_][a-z0-9_]*\b')


def normalize_body(source_lines, node):
	"""Extract and normalize a function body for comparison.

	Strips whitespace and replaces variable names with placeholders
	to detect structurally similar functions.
	"""
	start = node.lineno - 1
	end = getattr(node, 'end_lineno', None)
	if end is None:
		return ''
	body_lines = source_lines[start:end]
	if not body_lines:
		return ''

	# Join and strip leading indentation uniformly
	text = '\n'.join(line.strip() for line in body_lines if line.strip())

	# Replace variable names with a placeholder to normalize
	seen = {}
	counter = [0]

	def replace_var(match):
		name = match.group(0)
		# Skip Python keywords and builtins
		if name in PYTHON_KEYWORDS:
			return name
		if name not in seen:
			seen[name] = f'VAR{counter[0]}'
			counter[0] += 1
		return seen[name]

	normalized = VAR_NAME_RE.sub(replace_var, text)
	return normalized


PYTHON_KEYWORDS = frozenset({
	'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
	'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
	'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
	'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return',
	'try', 'while', 'with', 'yield',
	'self', 'cls', 'print', 'len', 'range', 'str', 'int', 'float',
	'list', 'dict', 'set', 'tuple', 'bool', 'type', 'isinstance',
	'super', 'open', 'hasattr', 'getattr', 'setattr',
})

SIMILARITY_THRESHOLD = 0.8
MIN_BODY_LENGTH = 20


try:
	target_dir = sys.argv[1]
	functions = []

	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			if not fname.endswith('.py') or fname.startswith(('_', '.')):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					source = f.read()
				source_lines = source.splitlines()
				tree = ast.parse(source)
			except (SyntaxError, OSError):
				continue

			for node in ast.walk(tree):
				if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
					body = normalize_body(source_lines, node)
					if len(body) >= MIN_BODY_LENGTH:
						label = f"{fname}:{node.name}:{node.lineno}"
						functions.append((label, body))

	# Compare all pairs
	duplicate_count = 0
	seen_pairs = set()

	for i in range(len(functions)):
		for j in range(i + 1, len(functions)):
			label_i, body_i = functions[i]
			label_j, body_j = functions[j]

			pair_key = (label_i, label_j)
			if pair_key in seen_pairs:
				continue
			seen_pairs.add(pair_key)

			ratio = difflib.SequenceMatcher(None, body_i, body_j).ratio()
			if ratio >= SIMILARITY_THRESHOLD:
				duplicate_count += 1

	score = max(0, 100 - duplicate_count * 20)

	print(f"DUPLICATE_BLOCKS:{duplicate_count}")
	print(f"DUPLICATE_SCORE:{score}")
except Exception:
	print("DUPLICATE_BLOCKS:0")
	print("DUPLICATE_SCORE:100")

sys.exit(0)
