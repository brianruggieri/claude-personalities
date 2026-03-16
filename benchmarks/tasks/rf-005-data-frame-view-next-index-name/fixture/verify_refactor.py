"""AST-based refactoring verification.

Checks that DataFrameView.next_index_name was correctly extracted
to a top-level function.
"""
import ast
import sys

FNAME = "dataframeeditor.py"
METHOD = "next_index_name"
METHOD_CHILDREN = 626
CLASS_NAME = "DataFrameView"
CLASS_CHILDREN = 4394
TOLERANCE = 0.20


def main():
    with open(FNAME) as f:
        source = f.read()

    # 1. Must parse as valid Python
    try:
        tree = ast.parse(source)
    except SyntaxError as e:
        print(f"VERIFY_FAIL: syntax error: {e}")
        sys.exit(1)

    # 2. Method must exist as top-level function
    top_funcs = [
        n for n in ast.iter_child_nodes(tree)
        if isinstance(n, ast.FunctionDef) and n.name == METHOD
    ]
    if not top_funcs:
        print(f"VERIFY_FAIL: {METHOD} not found as top-level function")
        sys.exit(1)

    # 3. Top-level function has approximately the right AST node count
    func_nodes = sum(1 for _ in ast.walk(top_funcs[0]))
    low = METHOD_CHILDREN * (1 - TOLERANCE)
    high = METHOD_CHILDREN * (1 + TOLERANCE)
    if not (low <= func_nodes <= high):
        print(
            f"VERIFY_FAIL: top-level {METHOD} has {func_nodes} AST nodes, "
            f"expected ~{METHOD_CHILDREN} (range {low:.0f}-{high:.0f})"
        )
        sys.exit(1)

    # 4. Class still exists and is smaller
    classes = [
        n for n in ast.iter_child_nodes(tree)
        if isinstance(n, ast.ClassDef) and n.name == CLASS_NAME
    ]
    if not classes:
        print(f"VERIFY_FAIL: class {CLASS_NAME} not found")
        sys.exit(1)

    cls_nodes = sum(1 for _ in ast.walk(classes[0]))
    expected_cls = CLASS_CHILDREN - METHOD_CHILDREN
    cls_low = expected_cls * (1 - TOLERANCE)
    cls_high = expected_cls * (1 + TOLERANCE)
    if not (cls_low <= cls_nodes <= cls_high):
        print(
            f"VERIFY_FAIL: class {CLASS_NAME} has {cls_nodes} AST nodes, "
            f"expected ~{expected_cls} (range {cls_low:.0f}-{cls_high:.0f})"
        )
        sys.exit(1)

    # 5. Method should NOT still be in the class
    for node in ast.walk(classes[0]):
        if isinstance(node, ast.FunctionDef) and node.name == METHOD:
            print(
                f"VERIFY_FAIL: {METHOD} still exists as method in {CLASS_NAME}"
            )
            sys.exit(1)

    print("ALL_TESTS_PASSED")


if __name__ == "__main__":
    main()
