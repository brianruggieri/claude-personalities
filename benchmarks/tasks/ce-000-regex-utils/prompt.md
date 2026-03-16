Implement the `RegexUtils` class in `solution.py`.

The class provides to match, find all occurrences, split, and substitute text using regular expressions. It also includes predefined patterns, validating phone numbers and extracting email addresses.

## Methods to implement

- `match`: def match(self, pattern, text):
- `findall`: def findall(self, pattern, text):
- `split`: def split(self, pattern, text):
- `sub`: def sub(self, pattern, replacement, text):
- `generate_email_pattern`: def generate_email_pattern(self):
- `generate_phone_number_pattern`: def generate_phone_number_pattern(self):
- `generate_split_sentences_pattern`: def generate_split_sentences_pattern(self):
- `split_sentences`: def split_sentences(self, text):
- `validate_phone_number`: def validate_phone_number(self, phone_number):
- `extract_email`: def extract_email(self, text):

Tests are in `test_solution.py`.
Run with: `python3 -m pytest test_solution.py -v`

Do not modify test_solution.py.
