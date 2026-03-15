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

Dimensions:
1. READABILITY: Is the code easy to understand? Good formatting, logical flow, appropriate comments?
2. NAMING: Are variable/function/class names descriptive and consistent? Follow language conventions?
3. ERROR_HANDLING: Does the code handle edge cases, invalid inputs, and errors appropriately?
4. IDIOMATIC: Does the code follow language idioms and best practices? Uses standard patterns?
5. ABSTRACTION: Is the level of abstraction appropriate? Not over-engineered, not under-abstracted?

Respond ONLY with a JSON object, no other text:
{"readability": N, "naming": N, "error_handling": N, "idiomatic": N, "abstraction": N}

Here is the code to evaluate:
"""


def collect_code(workdir):
	"""Collect all generated code files into a single string."""
	code_parts = []
	for fname in sorted(os.listdir(workdir)):
		if fname.startswith(('.', '_')):
			continue
		filepath = os.path.join(workdir, fname)
		if not os.path.isfile(filepath):
			continue
		_, ext = os.path.splitext(fname)
		if ext not in ('.py', '.js', '.jsx', '.ts', '.tsx', '.md'):
			continue
		try:
			with open(filepath) as f:
				content = f.read()
			if content.strip():
				code_parts.append(f"--- {fname} ---\n{content}")
		except OSError:
			pass
	return "\n\n".join(code_parts)


try:
	workdir = sys.argv[1]
	task_name = sys.argv[2] if len(sys.argv) > 2 else "unknown"

	code = collect_code(workdir)
	if not code.strip():
		print("JUDGE_SCORE:50")
		print("JUDGE_READABILITY:5")
		print("JUDGE_NAMING:5")
		print("JUDGE_ERROR_HANDLING:5")
		print("JUDGE_IDIOMATIC:5")
		print("JUDGE_ABSTRACTION:5")
		sys.exit(0)

	prompt = RUBRIC + code

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
