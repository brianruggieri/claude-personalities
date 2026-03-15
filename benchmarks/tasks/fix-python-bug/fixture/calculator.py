def add(a, b):
    return a + b


def divide(a, b):
    return a / b


def average(numbers):
    total = 0
    for n in numbers:
        total += n
    # Bug: off-by-one — divides by len+1 instead of len
    return divide(total, len(numbers) + 1)
