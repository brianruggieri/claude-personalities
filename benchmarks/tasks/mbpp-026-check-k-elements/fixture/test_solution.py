from solution import *


assert check_k_elements([(4, 4), (4, 4, 4), (4, 4), (4, 4, 4, 4), (4, )], 4) == True
assert check_k_elements([(7, 7, 7), (7, 7)], 7) == True
assert check_k_elements([(9, 9), (9, 9, 9, 9)], 7) == False

print("ALL_TESTS_PASSED")
