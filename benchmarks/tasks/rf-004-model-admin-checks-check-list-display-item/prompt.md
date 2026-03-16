# Refactor ModelAdminChecks._check_list_display_item

Refactor the `_check_list_display_item` method in the `ModelAdminChecks` class to be a stand alone, top level function.
Name the new function `_check_list_display_item`, exactly the same name as the existing method.
Update any existing `self._check_list_display_item` calls to work with the new `_check_list_display_item` function.

Edit `checks.py` in place.

## Requirements

- The `_check_list_display_item` method must be removed from `ModelAdminChecks` and exist as a top-level function
- All calls to `self._check_list_display_item(...)` must be updated to call the top-level `_check_list_display_item(...)` instead
- The file must remain valid Python (no syntax errors)
- Do not add, remove, or simplify any logic — this is a pure structural refactor
