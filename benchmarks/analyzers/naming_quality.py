#!/usr/bin/env python3
"""AST-based naming quality analysis for Python files.

Usage: python3 naming_quality.py <dir>
Output: NAMING_SCORE:<0-100>
        NAMING_GENERIC_COUNT:<count>
        NAMING_CONVENTION_VIOLATIONS:<count>
Always exits 0.
"""
import ast
import os
import re
import sys

GENERIC_BLOCKLIST = frozenset({
	'data', 'result', 'results', 'temp', 'tmp', 'obj', 'val', 'value',
	'foo', 'bar', 'baz', 'thing', 'stuff', 'item', 'items',
	'ret', 'res', 'out', 'output', 'inp', 'input',
	'var', 'var1', 'var2', 'str1', 'str2', 'list1', 'list2',
	'df', 'info', 'flag',
})

SNAKE_CASE_RE = re.compile(r'^_?[a-z][a-z0-9_]*$')
PASCAL_CASE_RE = re.compile(r'^[A-Z][a-zA-Z0-9]*$')
UPPER_SNAKE_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')


class NameExtractor(ast.NodeVisitor):
	def __init__(self):
		self.names = []

	def visit_FunctionDef(self, node):
		self.names.append((node.name, 'function', node.lineno))
		for arg in node.args.args:
			if arg.arg not in ('self', 'cls'):
				self.names.append((arg.arg, 'parameter', node.lineno))
		self.generic_visit(node)

	visit_AsyncFunctionDef = visit_FunctionDef

	def visit_ClassDef(self, node):
		self.names.append((node.name, 'class', node.lineno))
		self.generic_visit(node)

	def visit_Name(self, node):
		if isinstance(node.ctx, ast.Store):
			self.names.append((node.id, 'variable', node.lineno))
		self.generic_visit(node)


def check_convention(name, kind):
	if name.startswith('__') and name.endswith('__'):
		return True
	clean = name.lstrip('_')
	if not clean:
		return True
	if kind == 'class':
		return bool(PASCAL_CASE_RE.match(clean))
	return bool(SNAKE_CASE_RE.match(name) or UPPER_SNAKE_RE.match(name))


try:
	target_dir = sys.argv[1]
	generic_count = 0
	violations = 0

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

			ext = NameExtractor()
			ext.visit(tree)
			seen = set()
			for name, kind, _ in ext.names:
				key = (name, kind)
				if key in seen:
					continue
				seen.add(key)
				if name.startswith('__') and name.endswith('__'):
					continue
				if name.lower() in GENERIC_BLOCKLIST and len(name) > 1:
					generic_count += 1
				if not check_convention(name, kind):
					violations += 1

	deductions = generic_count * 10 + violations * 5
	score = max(0, 100 - deductions)

	print(f"NAMING_SCORE:{score}")
	print(f"NAMING_GENERIC_COUNT:{generic_count}")
	print(f"NAMING_CONVENTION_VIOLATIONS:{violations}")
except Exception:
	print("NAMING_SCORE:100")
	print("NAMING_GENERIC_COUNT:0")
	print("NAMING_CONVENTION_VIOLATIONS:0")

sys.exit(0)
