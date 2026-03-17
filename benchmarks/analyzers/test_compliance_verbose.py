#!/usr/bin/env python3
"""Diagnostic: show exactly which rules personality_compliance violates."""
import ast
import os
import re
import sys

SAFE_NUMBERS = frozenset({0, 1, 2, -1, True, False, None})
SNAKE_CASE_RE = re.compile(r'^_?_?[a-z][a-z0-9_]*_?_?$')
LOOP_SINGLE_LETTER_ALLOWED = frozenset({'i', 'j', 'k', 'n', '_'})
COMMENTED_CODE_RE = re.compile(r'#\s*(def |class |import |if |for |while |return )')

target_dir = sys.argv[1]

for root, dirs, files in os.walk(target_dir):
	dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
	for fname in files:
		if not fname.endswith('.py') or fname.startswith(('_', '.')):
			continue
		filepath = os.path.join(root, fname)
		with open(filepath) as f:
			source = f.read()
		try:
			tree = ast.parse(source)
		except SyntaxError:
			continue

		loop_targets = set()
		for node in ast.walk(tree):
			if isinstance(node, (ast.For, ast.AsyncFor)):
				for t in ast.walk(node.target):
					if isinstance(t, ast.Name):
						loop_targets.add(t.id)
			if isinstance(node, (ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
				for gen in node.generators:
					for t in ast.walk(gen.target):
						if isinstance(t, ast.Name):
							loop_targets.add(t.id)

		for node in ast.walk(tree):
			if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
				end = getattr(node, 'end_lineno', None)
				if end and (end - node.lineno + 1) > 50:
					print(f"  VIOLATION: function '{node.name}' is {end - node.lineno + 1} lines (max 50) at line {node.lineno}")

			if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
				if node.value not in SAFE_NUMBERS:
					print(f"  VIOLATION: magic number {node.value} at line {node.lineno}")

			if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
				if len(node.id) == 1 and node.id != '_':
					if node.id not in LOOP_SINGLE_LETTER_ALLOWED or node.id not in loop_targets:
						print(f"  VIOLATION: single-letter var '{node.id}' at line {node.lineno}")
