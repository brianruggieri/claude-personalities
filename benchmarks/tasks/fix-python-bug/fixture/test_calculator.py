from calculator import add, divide, average


def test_add():
    assert add(2, 3) == 5


def test_divide():
    assert divide(10, 2) == 5.0


def test_divide_by_zero():
    try:
        divide(1, 0)
        assert False, "Should have raised ZeroDivisionError"
    except ZeroDivisionError:
        pass


def test_average():
    assert average([10, 20, 30]) == 20.0


def test_average_single():
    assert average([42]) == 42.0
