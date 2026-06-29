@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin
var _main_panel: Control
const GI_LABEL_3D = preload("inspector/gi_label_3d.tscn")


func _enter_tree() -> void:
	# Inspector 插件（信号/方法下拉菜单）
	_inspector_plugin = preload("inspector/io_bind_inspector.gd").new()
	add_inspector_plugin(_inspector_plugin)
	# 延迟创建主屏幕面板，确保编辑器完全就绪
	call_deferred("_setup_main_screen")
	# 注册项目设置
	if not ProjectSettings.has_setting("SignalBinder/params/show_full_params"):
		ProjectSettings.set_setting("SignalBinder/params/show_full_params", false)
	ProjectSettings.add_property_info({
		"name": "SignalBinder/params/show_full_params",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
	})
	if not ProjectSettings.has_setting("SignalBinder/params/recursion"):
		ProjectSettings.set_setting("SignalBinder/params/recursion", false)
	ProjectSettings.add_property_info({
		"name": "SignalBinder/params/recursion",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
	})
	if not ProjectSettings.has_setting("SignalBinder/params/3d_offset"):
		ProjectSettings.set_setting("SignalBinder/params/3d_offset", Vector3(0,0.5,0))
	ProjectSettings.add_property_info({
		"name": "SignalBinder/params/3d_offset",
		"type": TYPE_VECTOR3,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
	})
	 # 1. 在 3D 视口顶部工具栏创建一个开关按钮
	toggle_btn = Button.new()
	toggle_btn.text = "Show 3D Names"
	toggle_btn.toggle_mode = true
	toggle_btn.toggled.connect(_on_toggle_pressed)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toggle_btn)
	toggle_refresh_btn = Button.new()
	toggle_refresh_btn.text = "Refresh 3D Names"
	toggle_refresh_btn.toggle_mode = true
	toggle_refresh_btn.button_down.connect(_refresh_labels)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toggle_refresh_btn)

func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)
	if _main_panel:
		EditorInterface.get_editor_main_screen().remove_child(_main_panel)
		scene_changed.disconnect(refresh)
		_main_panel.queue_free()
		_main_panel = null
	clear_all_labels()
	if toggle_btn:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toggle_btn)
		toggle_btn.queue_free()
	if toggle_refresh_btn:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toggle_refresh_btn)
		toggle_refresh_btn.queue_free()

func _make_visible(visible: bool) -> void:
	if _main_panel:
		_main_panel.visible = visible

#region IO
func _setup_main_screen() -> void:
	if _main_panel:
		return
	_main_panel = preload("inspector/io_bind_dock.tscn").instantiate()
	_main_panel.name = "IO Binding Table"
	EditorInterface.get_editor_main_screen().add_child(_main_panel)
	_make_visible(false)
	refresh()
	scene_changed.connect(refresh)

func refresh(scene_root: Node=null):
	if _main_panel and _main_panel.has_method("refresh"):
		_main_panel.refresh()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "IO Binding Table"

#endregion

#region 3d视口工具

var toggle_btn: Button
var toggle_refresh_btn:Button
var is_active: bool = false
var labels: Array = []
var scan_timer: float = 0.0

func _on_toggle_pressed(pressed: bool):
	is_active = pressed
	if is_active:
		generate_labels()
	else:
		clear_all_labels()

func _refresh_labels():
	if not is_active:
		return
	# 清理已经被删除的标签
	labels = labels.filter(func(l): return is_instance_valid(l) and l.get_parent() != null)
	var root = get_tree().get_edited_scene_root()
	if not root: return
	var current_3d_nodes = []
	_collect_3d_nodes(root, current_3d_nodes)
	# 为新节点添加标签，并更新已存在节点的名字（防改名）
	for node in current_3d_nodes:
		var has_label = false
		for l in labels:
			if l.get_parent() == node:
				has_label = true
				l.text = node.name # 实时同步名字
				break
		if not has_label:
			_create_label_for(node)

func _collect_3d_nodes(node: Node, arr: Array):
	var root = get_tree().get_edited_scene_root()
	if node is Node3D and node.visible:
		if node.owner == root:
			arr.append(node)
	for child in node.get_children():
		if child.owner == root:
			_collect_3d_nodes(child, arr)

func generate_labels():
	clear_all_labels()
	var root = get_tree().get_edited_scene_root()
	if root:
		var nodes = []
		_collect_3d_nodes(root, nodes)
		for node in nodes:
			_create_label_for(node)

func _create_label_for(node: Node3D):
	var label = GI_LABEL_3D.instantiate()
	label.text = node.name
	var _offset:Vector3 = ProjectSettings.get_setting("SignalBinder/params/3d_offset")
	label.position = _offset
	# ★ 核心魔法：INTERNAL_MODE_BACK
	# 这样添加的节点不会出现在左侧的场景树面板里，也不会被保存到场景文件中
	node.add_child(label, false, Node.INTERNAL_MODE_BACK)
	labels.append(label)

func clear_all_labels():
	for label in labels:
		if is_instance_valid(label):
			label.queue_free()
	labels.clear()

func hide_all_labels():
	for label in labels:
		if is_instance_valid(label):
			label.hide()
#endregion
