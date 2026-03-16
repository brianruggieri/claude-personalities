# Refactor Command.output_hash

Refactor the `output_hash` method in the `Command` class to be a stand alone, top level function.
Name the new function `output_hash`, exactly the same name as the existing method.
Update any existing `self.output_hash` calls to work with the new `output_hash` function.

Edit `diffsettings.py` in place.

## Requirements

- The `output_hash` method must be removed from `Command` and exist as a top-level function
- All calls to `self.output_hash(...)` must be updated to call the top-level `output_hash(...)` instead
- The file must remain valid Python (no syntax errors)
- Do not add, remove, or simplify any logic — this is a pure structural refactor
