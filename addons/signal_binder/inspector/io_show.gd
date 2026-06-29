@tool
extends VBoxContainer

const IO_CONNECTION = preload("io_connection.tscn")
@onready var v_box: VBoxContainer = $VBoxContainer
@onready var button: Button = $HBoxContainer/Button
@onready var node_name: Button = $HBoxContainer/NodeName
@onready var updata: Button = $HBoxContainer/updata

var ionode:Node

func _ready() -> void:
	button.button_down.connect(switch)
	updata.button_down.connect(_updata)

func switch(b:bool = !v_box.visible):
	v_box.visible = b
	if v_box.visible:
		button.text = "v"
	else:
		button.text = ">"

func _updata():
	if ionode:
		print("io节点更新")
		if ionode is IoBinder:
			refresh_iobinder(ionode)
		elif ionode is IoBindMulti:
			refresh_iobindmulti(ionode)

func refresh_iobinder(iobinder:IoBinder) -> void:
	ionode = iobinder
	if not node_name.button_down.is_connected(_on_node_pressed):
		node_name.button_down.connect(_on_node_pressed.bind(iobinder))
	node_name.text = iobinder.name
	for c in v_box.get_children():
		c.queue_free()
	for iobindbase in iobinder.iosets:
		var io_connection = IO_CONNECTION.instantiate()
		v_box.add_child(io_connection)
		io_connection.set_io_connection(iobindbase,iobinder)

func refresh_iobindmulti(iobindmulti:IoBindMulti) -> void:
	ionode = iobindmulti
	if not node_name.button_down.is_connected(_on_node_pressed):
		node_name.button_down.connect(_on_node_pressed.bind(iobindmulti))
	node_name.text = iobindmulti.name
	for c in v_box.get_children():
		c.queue_free()
	for iomc:IoBindMultiConfig in iobindmulti.ios:
		if iomc:
			for iobindbase in iomc.iosets:
				if iobindbase:
					var io_connection = IO_CONNECTION.instantiate()
					v_box.add_child(io_connection)
					io_connection.set_io_multi_connection(iobindbase,iomc,iobindmulti)



func _on_node_pressed(io:Node):EditorInterface.edit_node(io)
