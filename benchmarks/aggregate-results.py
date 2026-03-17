#!/usr/bin/env python3
"""Aggregate multiple benchmark runs per (profile, task) into summary statistics.

Usage: python3 aggregate-results.py <metrics_dir>
Reads: <metrics_dir>/benchmarks/<profile>/<task>/*.json
Outputs: JSON with median, IQR, and count per metric per (profile, task).
"""
import json
import os
import statistics
import sys


def aggregate(metrics_dir):
	benchmarks_dir = os.path.join(metrics_dir, 'benchmarks')
	if not os.path.isdir(benchmarks_dir):
		print(f"Error: {benchmarks_dir} not found", file=sys.stderr)
		sys.exit(1)

	# Field names match the JSON result files (not the dashboard's JS data objects,
	# which use shorter names like 'output_tokens' and 'lines').
	KEY_METRICS = [
		'cost_usd', 'duration_seconds', 'cognitive_complexity_max',
		'max_function_length', 'complexity_max', 'maintainability_index',
		'personality_compliance', 'lines_generated', 'total_output_tokens'
	]

	results = {}

	for profile in sorted(os.listdir(benchmarks_dir)):
		profile_dir = os.path.join(benchmarks_dir, profile)
		if not os.path.isdir(profile_dir):
			continue

		results[profile] = {}

		for task in sorted(os.listdir(profile_dir)):
			task_dir = os.path.join(profile_dir, task)
			if not os.path.isdir(task_dir):
				continue

			# Collect all JSON result files for this (profile, task)
			runs = []
			for fname in sorted(os.listdir(task_dir)):
				if fname.endswith('.json'):
					try:
						with open(os.path.join(task_dir, fname)) as f:
							runs.append(json.load(f))
					except (json.JSONDecodeError, IOError) as e:
						print(f"Warning: Skipping {fname}: {e}", file=sys.stderr)

			if not runs:
				continue

			summary = {'n': len(runs), 'metrics': {}}

			for metric in KEY_METRICS:
				values = [r.get(metric) for r in runs if r.get(metric) is not None]
				if not values:
					continue

				if len(values) == 1:
					summary['metrics'][metric] = {
						'median': values[0],
						'iqr_low': values[0],
						'iqr_high': values[0],
						'n': 1
					}
				else:
					values.sort()
					med = statistics.median(values)
					q1 = statistics.median(values[:len(values)//2])
					q3 = statistics.median(values[len(values)//2 + (len(values) % 2):])
					summary['metrics'][metric] = {
						'median': round(med, 4),
						'iqr_low': round(q1, 4),
						'iqr_high': round(q3, 4),
						'n': len(values)
					}

			results[profile][task] = summary

	print(json.dumps(results, indent=2))


if __name__ == '__main__':
	if len(sys.argv) < 2:
		print("Usage: python3 aggregate-results.py <metrics_dir>")
		sys.exit(1)
	aggregate(sys.argv[1])
