# Refactor MetricsContainer._get_metric_object

Refactor the `_get_metric_object` method in the `MetricsContainer` class to be a stand alone, top level function.
Name the new function `_get_metric_object`, exactly the same name as the existing method.
Update any existing `self._get_metric_object` calls to work with the new `_get_metric_object` function.

Edit `compile_utils.py` in place.

## Requirements

- The `_get_metric_object` method must be removed from `MetricsContainer` and exist as a top-level function
- All calls to `self._get_metric_object(...)` must be updated to call the top-level `_get_metric_object(...)` instead
- The file must remain valid Python (no syntax errors)
- Do not add, remove, or simplify any logic — this is a pure structural refactor
