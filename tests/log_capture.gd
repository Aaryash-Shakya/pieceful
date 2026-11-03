extends Logger
## Collects push_warning and push_error messages so a test can assert that nothing was logged.
## Never print from here: printing inside a logger re-enters it.

var warnings := PackedStringArray()
var errors := PackedStringArray()

# Loggers can be called from any thread.
var _mutex := Mutex.new()


func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	# A push_warning message arrives in `code`, with no rationale.
	var message := rationale if rationale != "" else code
	_mutex.lock()
	if error_type == Logger.ERROR_TYPE_WARNING:
		warnings.append(message)
	else:
		errors.append(message)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
