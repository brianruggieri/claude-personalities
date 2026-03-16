# Refactor DataFrameView.next_index_name

Refactor the `next_index_name` method in the `DataFrameView` class to be a stand alone, top level function.
Name the new function `next_index_name`, exactly the same name as the existing method.
Update any existing `self.next_index_name` calls to work with the new `next_index_name` function.

Edit `dataframeeditor.py` in place.

## Requirements

- The `next_index_name` method must be removed from `DataFrameView` and exist as a top-level function
- All calls to `self.next_index_name(...)` must be updated to call the top-level `next_index_name(...)` instead
- The file must remain valid Python (no syntax errors)
- Do not add, remove, or simplify any logic — this is a pure structural refactor
