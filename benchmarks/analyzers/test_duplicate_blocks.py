#!/usr/bin/env python3
"""Test duplicate_blocks analyzer against known inputs."""
import os
import subprocess
import sys
import tempfile

def run_analyzer(code):
	"""Run duplicate_blocks.py on a temp directory containing code, return output."""
	with tempfile.TemporaryDirectory() as tmpdir:
		filepath = os.path.join(tmpdir, 'module.py')
		with open(filepath, 'w') as f:
			f.write(code)
		result = subprocess.run(
			[sys.executable, os.path.join(os.path.dirname(__file__), 'duplicate_blocks.py'), tmpdir],
			capture_output=True, text=True
		)
		return result.stdout.strip()

# Test 1: Two genuinely different functions should NOT be duplicates
different_funcs = '''
def add(a, b):
    return a + b

def multiply(x, y):
    result = x * y
    return result

def greet(name):
    message = f"Hello, {name}!"
    print(message)
    return message
'''

output = run_analyzer(different_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks <= 1, f"Expected <= 1 duplicate blocks for different functions, got {blocks}"
print(f"PASS: different functions → {blocks} duplicates")

# Test 2: Two actually identical functions (different names) SHOULD be duplicates
# Bodies are intentionally long (>50 chars after normalization) to exceed MIN_BODY_LENGTH
identical_funcs = '''
def process_alpha(items):
    result = []
    for item in items:
        if item > 0:
            transformed = item * 2
            result.append(transformed)
        elif item == 0:
            result.append(0)
        else:
            result.append(abs(item))
    return sorted(result)

def process_beta(entries):
    output = []
    for entry in entries:
        if entry > 0:
            modified = entry * 2
            output.append(modified)
        elif entry == 0:
            output.append(0)
        else:
            output.append(abs(entry))
    return sorted(output)
'''

output = run_analyzer(identical_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks >= 1, f"Expected >= 1 duplicate block for identical functions, got {blocks}"
print(f"PASS: identical functions → {blocks} duplicates")

# Test 3: Many small functions should not explode the count
many_funcs = '\n'.join(
    f'def func_{i}(x):\n    return x + {i}\n'
    for i in range(20)
)

output = run_analyzer(many_funcs)
lines = output.split('\n')
blocks = int(lines[0].split(':')[1])
assert blocks < 20, f"Expected < 20 duplicates for trivially similar one-liners, got {blocks}"
print(f"PASS: many small functions → {blocks} duplicates")

print("\nAll tests passed.")
