extends Node

var _actions = []

func add(action):
	_actions.append(action)

func clear():
	_actions = []

func has_pending():
	return not _actions.is_empty()

func step_once():
	if _actions.is_empty():
		return false
	var stepped = false
	var index = 0
	while index < _actions.size():
		var action = _actions[index]
		action.update()
		stepped = true
		if index >= _actions.size() or _actions[index] != action:
			continue
		if action.is_complete():
			_actions.remove_at(index)
		else:
			index += 1
	return stepped
