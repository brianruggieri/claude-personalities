Implement the `CamelCaseMap` class in `solution.py`.

This is a custom class that allows keys to be in camel case style by converting them from underscore style, which provides dictionary-like functionality.

## Methods to implement

- `__getitem__`: def __getitem__(self, key):
- `__setitem__`: def __setitem__(self, key, value):
- `__delitem__`: def __delitem__(self, key):
- `__iter__`: def __iter__(self):
- `__len__`: def __len__(self):
- `_convert_key`: def _convert_key(self, key):
- `_to_camel_case`: @staticmethod

Tests are in `test_solution.py`.
Run with: `python3 -m pytest test_solution.py -v`

Do not modify test_solution.py.
