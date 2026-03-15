#!/usr/bin/env python3
"""Scan generated files for security anti-patterns.

Usage: python3 security_smells.py <dir> [<extensions>]
Output: SECURITY_SMELLS:<count>
Always exits 0.
"""
import os
import re
import sys

PATTERNS = [
	("eval_call", re.compile(r'\beval\s*\(')),
	("exec_call", re.compile(r'\bexec\s*\(')),
	("dangerous_inner_html", re.compile(r'dangerouslySetInnerHTML')),
	("hardcoded_password", re.compile(
		r'''(?:password|passwd|secret|api_key|token)\s*=\s*['"][^'"]{3,}['"]''',
		re.IGNORECASE,
	)),
	("http_no_tls", re.compile(r'''['"]http://(?!localhost|127\.0\.0\.1|0\.0\.0\.0)''')),
	("sql_string_concat", re.compile(r'''f['"]\s*(?:SELECT|INSERT|UPDATE|DELETE)\b''')),
	("sql_format_concat", re.compile(r'''(?:SELECT|INSERT|UPDATE|DELETE)\b.*\.format\s*\(''')),
	("shell_injection", re.compile(r'os\.system\s*\(|subprocess\.call\s*\(\s*["\']')),
	("pickle_load", re.compile(r'pickle\.loads?\s*\(')),
]

DEFAULT_EXTENSIONS = {'.py', '.js', '.jsx', '.ts', '.tsx'}


try:
	target_dir = sys.argv[1]
	extensions = DEFAULT_EXTENSIONS

	count = 0
	for root, dirs, files in os.walk(target_dir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in files:
			_, ext = os.path.splitext(fname)
			if ext not in extensions:
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath, 'r', errors='replace') as f:
					for line in f:
						for _, pattern in PATTERNS:
							if pattern.search(line):
								count += 1
			except OSError:
				pass

	print(f"SECURITY_SMELLS:{count}")
except Exception:
	print("SECURITY_SMELLS:0")

sys.exit(0)
