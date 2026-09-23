from collections import deque


class InputCell:
    def __init__(self, initial_value):
        self._value = initial_value
        self._dependents = []

    @property
    def value(self):
        return self._value

    @value.setter
    def value(self, new_value):
        self._value = new_value
        _propagate_changes(self._dependents)

    def _add_dependent(self, cell):
        self._dependents.append(cell)


class ComputeCell:
    def __init__(self, inputs, compute_function):
        self._inputs = inputs
        self._compute = compute_function
        self._dependents = []
        self._callbacks = []
        self._value = self._calculate()
        for cell in inputs:
            cell._add_dependent(self)

    @property
    def value(self):
        return self._value

    def add_callback(self, callback):
        self._callbacks.append(callback)

    def remove_callback(self, callback):
        if callback in self._callbacks:
            self._callbacks.remove(callback)

    def _add_dependent(self, cell):
        self._dependents.append(cell)

    def _calculate(self):
        input_values = [cell.value for cell in self._inputs]
        return self._compute(input_values)

    def _update(self):
        new_value = self._calculate()
        old_value = self._value
        self._value = new_value
        return new_value != old_value

    def _fire_callbacks(self):
        for callback in self._callbacks:
            callback(self._value)


def _collect_with_depth(initial_dependents):
    depths = {}
    queue = deque()
    for cell in initial_dependents:
        depths[id(cell)] = 0
        queue.append((cell, 0))
    while queue:
        cell, depth = queue.popleft()
        if depths.get(id(cell), -1) > depth:
            continue
        depths[id(cell)] = max(depths.get(id(cell), 0), depth)
        for dep in cell._dependents:
            new_depth = depth + 1
            if new_depth > depths.get(id(dep), -1):
                depths[id(dep)] = new_depth
                queue.append((dep, new_depth))
    return depths


def _propagate_changes(dependents):
    depths = _collect_with_depth(dependents)
    cells_by_id = {}
    _collect_cells(dependents, cells_by_id)
    ordered = sorted(
        cells_by_id.values(),
        key=lambda c: depths[id(c)],
    )
    changed = set()
    for cell in ordered:
        if cell._update():
            changed.add(id(cell))
    for cell in ordered:
        if id(cell) in changed:
            cell._fire_callbacks()


def _collect_cells(dependents, cells_by_id):
    for cell in dependents:
        if id(cell) not in cells_by_id:
            cells_by_id[id(cell)] = cell
            _collect_cells(cell._dependents, cells_by_id)
