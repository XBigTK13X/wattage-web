extends Node

var _fixed_succeed = null

func fixed_chances(succeed):
	_fixed_succeed = succeed

func chance(percent_value):
	if _fixed_succeed != null:
		return _fixed_succeed
	if percent_value == null:
		return true
	var ratio = float(percent_value) / 100.0
	return randf() <= ratio
