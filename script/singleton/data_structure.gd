extends Node

func choose(items, amount = 1):
	if items.size() == 0:
		return null
	if amount == 1:
		return items[randi() % items.size()]
	var pick_lookup = {}
	var picks = []
	while pick_lookup.size() < amount and pick_lookup.size() < items.size():
		var pick_index = randi() % items.size()
		if not pick_lookup.has(pick_index):
			pick_lookup[pick_index] = true
			picks.append(items[pick_index])
	return picks

func merge(dictionary_first, dictionary_second):
	var result = dictionary_first.duplicate(true)
	var copy_second = dictionary_second.duplicate(true)
	for key in copy_second.keys():
		if result.has(key):
			if typeof(result[key]) != TYPE_ARRAY:
				var existing_value = result[key]
				result[key] = [existing_value]
			else:
				result[key] = result[key].duplicate()
			if typeof(copy_second[key]) == TYPE_ARRAY:
				result[key] += copy_second[key]
			else:
				result[key].append(copy_second[key])
		else:
			result[key] = copy_second[key]
	return result

func arrayify(input_value):
	if typeof(input_value) != TYPE_ARRAY:
		return [input_value]
	return input_value

class QueueItem:
	var data = null
	var next = null
	var previous = null

class Queue:
	var _head = null
	var _tail = null
	var _size = 0

	func push(item):
		var link = QueueItem.new()
		link.data = item
		if _size == 0:
			_head = link
			_tail = link
		else:
			_tail.next = link
			link.previous = _tail
			_tail = link
		_size += 1

	func last():
		if _tail == null:
			return null
		return _tail.data

	func pop():
		if _size == 0:
			return null
		var result = _tail
		_tail = _tail.previous
		if _tail != null:
			_tail.next = null
		else:
			_head = null
		_size -= 1
		return result.data

	func tree():
		if _size == 0:
			return []
		var result = []
		var current = _head
		while current != null:
			result.append(current.data)
			current = current.next
		return result

	func size():
		return _size

func new_queue():
	return Queue.new()
