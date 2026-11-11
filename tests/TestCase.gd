class_name TestCase
extends RefCounted
## Мини-фреймворк проверок для tests/. Владелец: A.

var passed := 0
var failed := 0
var _group := ""


func group(title: String) -> void:
	_group = title
	print("\n== %s" % title)


func check(condition: bool, what: String) -> void:
	if condition:
		passed += 1
		print("  ok    %s" % what)
	else:
		failed += 1
		print("  FAIL  %s" % what)


func equal(actual, expected, what: String) -> void:
	check(actual == expected, "%s (ожидалось %s, получено %s)" % [what, expected, actual])


## Число в пределах допуска: для проверок баланса.
func near(actual: float, expected: float, tolerance: float, what: String) -> void:
	check(absf(actual - expected) <= tolerance,
		"%s (ожидалось %s ± %s, получено %s)" % [what, expected, tolerance, actual])


func summary() -> int:
	print("\nИтог: %d ок, %d провалено" % [passed, failed])
	return 0 if failed == 0 else 1
