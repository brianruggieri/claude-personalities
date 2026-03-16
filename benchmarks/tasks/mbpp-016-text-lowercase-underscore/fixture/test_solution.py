from solution import *


assert text_lowercase_underscore("aab_cbbbc")==('Found a match!')
assert text_lowercase_underscore("aab_Abbbc")==('Not matched!')
assert text_lowercase_underscore("Aaab_abbbc")==('Not matched!')

print("ALL_TESTS_PASSED")
