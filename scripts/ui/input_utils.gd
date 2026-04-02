extends Node
class_name InputUtils

static func get_action_key(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)

	for event in events:
		if event is InputEventKey:
			return event.as_text()

	return "[UNBOUND]"
