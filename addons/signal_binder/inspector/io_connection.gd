@tool
extends HBoxContainer
@onready var _signal_source: Button = %signal_source
@onready var _signal_name: Label = %signal_name
@onready var _connection: Button = %connection
@onready var _connection_method: Label = %connection_method
@onready var edit: Button = %edit
@onready var updata: Button = %updata

var _iobindbase:IoBindBase
var _signal_node:Node
var _ionode:Node

func _ready() -> void:
	updata.button_down.connect(_show_iobindbase)

func set_io_connection(iobindbase:IoBindBase,iobinder:IoBinder):
	_ionode = iobinder
	_signal_node = _ionode.signal_owner
	edit.button_down.connect(func():
		EditorInterface.edit_resource(iobindbase)
		)
	_iobindbase = iobindbase
	_show_iobindbase()


func set_io_multi_connection(iobindbase:IoBindBase,iobindmulticonfig:IoBindMultiConfig,iobindmulti:IoBindMulti):
	_ionode = iobindmulti
	_iobindbase = iobindbase
	_signal_node = iobindmulti.get_node(iobindmulticonfig.signal_path)
	edit.button_down.connect(func():
		EditorInterface.edit_resource(iobindmulticonfig)
		)
	_show_iobindbase()

func _show_iobindbase():
	if not _iobindbase:
		return
	_signal_source.disabled = false
	if _iobindbase.signal_source:
		var o = _iobindbase.signal_source.get_signal_source()
		if o is NodePath:
			_signal_node = _ionode.get_node(o)
		elif o is StringName:
			_signal_source.text = o
			_signal_source.disabled = true
			_signal_node = null
	if _signal_node:
		if _signal_source.button_down.is_connected(_on_signal_source_pressed):
			_signal_source.button_down.disconnect(_on_signal_source_pressed)
		_signal_source.button_down.connect(_on_signal_source_pressed.bind(_signal_node))
		_signal_source.text = _signal_node.name
	_connection_method.text = _iobindbase.method_name
	_connection_method.text = _iobindbase.method_name
	_signal_name.text = _iobindbase.signal_name
	if _iobindbase is IoBindGroup:
		_connection.text = tr("Group:") + " " + _iobindbase.group_name
	elif _iobindbase is IoBindSelf:
		_connection.text = _signal_node.name
	elif _iobindbase is IoBindPath:
		var node:Node= _ionode.get_node(_iobindbase.node_path)
		_connection.text = node.name
		_connection.disabled = false
		if _connection.button_down.is_connected(_on_signal_source_pressed):
			_connection.button_down.disconnect(_on_signal_source_pressed)
		_connection.button_down.connect(_on_signal_source_pressed.bind(node))
	elif _iobindbase is IoBindSingleton:
		_connection.text = tr("Script:") + " " + _iobindbase.target_script.get_global_name()
	elif _iobindbase is IoBindGlobal:
		_connection.text = tr("Autoload:") + " " + _iobindbase.target_autoload
# 按钮点击回调
func _on_signal_source_pressed(node:Node):
	if not node:
		print("没有设置 signal_node")
		return
	# 检查节点是否还在场景树中
	if not node.is_inside_tree():
		print("节点不在当前场景树中")
		return
	## 1. 判断节点类型并切换到对应的标签页
	## Node3D 及其子类
	#if node.is_class("Node3D"):
		#EditorInterface.set_main_screen_editor("3D")
	## CanvasItem 包含了 Node2D 和 Control 等所有 2D 节点
	#elif node.is_class("CanvasItem"):
		#EditorInterface.set_main_screen_editor("2D")
	# 2. 在场景树中选中该节点
	# 在 Godot 4 中，edit_node 会自动让 2D/3D 视口聚焦到该节点
	EditorInterface.edit_node(node)
