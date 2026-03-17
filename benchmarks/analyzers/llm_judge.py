#!/usr/bin/env python3
"""LLM-as-judge code quality evaluation via claude -p (subscription).

Usage: python3 llm_judge.py <dir> <task_name>
Output: JUDGE_SCORE:<0-100>
        JUDGE_READABILITY:<1-10>
        JUDGE_NAMING:<1-10>
        JUDGE_ERROR_HANDLING:<1-10>
        JUDGE_IDIOMATIC:<1-10>
        JUDGE_ABSTRACTION:<1-10>

Uses claude -p (subscription, not API) for the evaluation.
Always exits 0.
"""
import json
import os
import subprocess
import sys


RUBRIC = """Rate this code on 5 dimensions, each scored 1-10.
Use the anchored examples to calibrate your scores.

1. READABILITY: Is the code easy to understand?
   3 = Dense logic, unclear variable flow, no whitespace grouping
   5 = Functional but takes effort to follow
   7 = Clear flow, good whitespace, could improve naming in spots
   9 = Immediately understandable, self-documenting structure

2. NAMING: Are names descriptive and consistent?
   3 = Generic names (data, result, temp), inconsistent conventions
   5 = Adequate names, mostly consistent
   7 = Descriptive names, consistent conventions, minor abbreviations
   9 = Every name reveals intent, perfect convention adherence

3. ERROR_HANDLING: Does the code handle edge cases and errors?
   3 = No edge case handling, bare except blocks, silent failures
   5 = Some handling, but gaps in coverage
   7 = Key edge cases handled, specific exceptions, some gaps
   9 = All edge cases handled, custom exceptions where appropriate

4. IDIOMATIC: Does the code follow language idioms and best practices?
   3 = Transliterated from another language, ignores standard library
   5 = Basic usage, misses some language features
   7 = Uses language features correctly, follows most conventions
   9 = Expert-level idioms, leverages stdlib perfectly, zero anti-patterns

5. ABSTRACTION: Is the level of abstraction appropriate for the problem?
   3 = God function or premature abstraction, wrong level of granularity
   5 = Works but decomposition could be better
   7 = Reasonable decomposition, could be slightly better
   9 = Perfect granularity for the problem, each unit has one clear purpose

Respond ONLY with a JSON object, no other text:
{"readability": N, "naming": N, "error_handling": N, "idiomatic": N, "abstraction": N}
"""


def collect_code(workdir):
	"""Collect all generated code files into a single string."""
	code_parts = []
	for root, dirs, files in os.walk(workdir):
		dirs[:] = [d for d in dirs if not d.startswith(('.', '_'))]
		for fname in sorted(files):
			if fname.startswith(('.', '_')):
				continue
			_, ext = os.path.splitext(fname)
			if ext not in ('.py', '.js', '.jsx', '.ts', '.tsx', '.md'):
				continue
			filepath = os.path.join(root, fname)
			try:
				with open(filepath) as f:
					content = f.read()
				if content.strip():
					rel_path = os.path.relpath(filepath, workdir)
					code_parts.append(f"--- {rel_path} ---\n{content}")
			except OSError:
				pass
	return "\n\n".join(code_parts)


try:
	workdir = sys.argv[1]
	task_name = sys.argv[2] if len(sys.argv) > 2 else "unknown"
	task_dir = sys.argv[3] if len(sys.argv) > 3 else None

	# Read task prompt for context
	task_context = ""
	if task_dir:
		prompt_path = os.path.join(task_dir, "prompt.md")
		if os.path.exists(prompt_path):
			with open(prompt_path) as f:
				task_context = f"Task: {task_name}\nPrompt: {f.read().strip()}\n\n"

	code = collect_code(workdir)
	if not code.strip():
		print("JUDGE_SCORE:50")
		print("JUDGE_READABILITY:5")
		print("JUDGE_NAMING:5")
		print("JUDGE_ERROR_HANDLING:5")
		print("JUDGE_IDIOMATIC:5")
		print("JUDGE_ABSTRACTION:5")
		sys.exit(0)

	prompt = task_context + RUBRIC + code

	result = subprocess.run(
		['claude', '-p', '--dangerously-skip-permissions', '--output-format', 'json', prompt],
		capture_output=True, text=True, timeout=60,
	)

	if result.returncode != 0:
		raise RuntimeError(f"claude exited {result.returncode}")

	# Parse claude JSON output to get the result text
	claude_output = json.loads(result.stdout)
	response_text = claude_output.get('result', '')

	# Extract the JSON scores from the response
	# Find the first { ... } in the response
	start = response_text.find('{')
	end = response_text.rfind('}')
	if start == -1 or end == -1:
		raise ValueError("No JSON found in judge response")

	scores = json.loads(response_text[start:end + 1])

	readability = max(1, min(10, int(scores.get('readability', 5))))
	naming = max(1, min(10, int(scores.get('naming', 5))))
	error_handling = max(1, min(10, int(scores.get('error_handling', 5))))
	idiomatic = max(1, min(10, int(scores.get('idiomatic', 5))))
	abstraction = max(1, min(10, int(scores.get('abstraction', 5))))

	# Composite score: average of all dimensions, scaled to 0-100
	composite = round((readability + naming + error_handling + idiomatic + abstraction) * 100 / 50)

	print(f"JUDGE_SCORE:{composite}")
	print(f"JUDGE_READABILITY:{readability}")
	print(f"JUDGE_NAMING:{naming}")
	print(f"JUDGE_ERROR_HANDLING:{error_handling}")
	print(f"JUDGE_IDIOMATIC:{idiomatic}")
	print(f"JUDGE_ABSTRACTION:{abstraction}")

except Exception:
	print("JUDGE_SCORE:0")
	print("JUDGE_READABILITY:0")
	print("JUDGE_NAMING:0")
	print("JUDGE_ERROR_HANDLING:0")
	print("JUDGE_IDIOMATIC:0")
	print("JUDGE_ABSTRACTION:0")

sys.exit(0)
