# Refactor GradientChecker._assertInferTensorChecks

Refactor the `_assertInferTensorChecks` method in the `GradientChecker` class to be a stand alone, top level function.
Name the new function `_assertInferTensorChecks`, exactly the same name as the existing method.
Update any existing `self._assertInferTensorChecks` calls to work with the new `_assertInferTensorChecks` function.

Edit `gradient_checker.py` in place.

## Requirements

- The `_assertInferTensorChecks` method must be removed from `GradientChecker` and exist as a top-level function
- All calls to `self._assertInferTensorChecks(...)` must be updated to call the top-level `_assertInferTensorChecks(...)` instead
- The file must remain valid Python (no syntax errors)
- Do not add, remove, or simplify any logic — this is a pure structural refactor
