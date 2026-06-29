@tool
@icon("../icons/IoBindMulti.svg")
class_name IoBindMulti
extends Node

@export var ios:Array[IoBindMultiConfig]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for io in ios:
		io.execute(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	for io in ios:
		io.exit_tree()
