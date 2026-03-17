class Node:
    def __init__(self, value, succeeding=None, previous=None):
        self.value = value
        self.succeeding = succeeding
        self.previous = previous


class LinkedList:
    def __init__(self):
        self.head = self.tail = None
        self.length = 0

    def push(self, value):
        node = Node(value, previous=self.tail)
        if self.tail:
            self.tail.succeeding = node
        else:
            self.head = node
        self.tail = node
        self.length += 1

    def pop(self):
        if not self.length:
            raise IndexError("List is empty")
        value, node = self.tail.value, self.tail
        if node.previous:
            node.previous.succeeding = node.succeeding
        else:
            self.head = node.succeeding
        if node.succeeding:
            node.succeeding.previous = node.previous
        else:
            self.tail = node.previous
        self.length -= 1
        return value

    def shift(self):
        if not self.length:
            raise IndexError("List is empty")
        value, node = self.head.value, self.head
        if node.previous:
            node.previous.succeeding = node.succeeding
        else:
            self.head = node.succeeding
        if node.succeeding:
            node.succeeding.previous = node.previous
        else:
            self.tail = node.previous
        self.length -= 1
        return value

    def unshift(self, value):
        node = Node(value, succeeding=self.head)
        if self.head:
            self.head.previous = node
        else:
            self.tail = node
        self.head = node
        self.length += 1

    def delete(self, value):
        current = self.head
        while current:
            if current.value == value:
                if current.previous:
                    current.previous.succeeding = current.succeeding
                else:
                    self.head = current.succeeding
                if current.succeeding:
                    current.succeeding.previous = current.previous
                else:
                    self.tail = current.previous
                self.length -= 1
                return
            current = current.succeeding
        raise ValueError("Value not found")

    def __len__(self):
        return self.length
