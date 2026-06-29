@tool
extends EditorInspectorPlugin

## 自动读取 signal_owner 上的信号列表和脚本方法列表，
## 在 Inspector 中以下拉菜单形式展示，替代手动输入


func _can_handle(object: Object) -> bool:
	return object is IoBindBase or object is IoSignalSource


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage: int, wide: bool) -> bool:
	# IoSignalSource 的 autoload_name 下拉
	if object is IoSignalSource and name == "autoload_name":
		var options := _get_autoload_options()
		if options.is_empty():
			return false
		_add_option_picker(object as Resource, "autoload_name", options)
		return true
	var io := object as IoBindBase
	if not io:
		return false
	match name:
		"autoload_name":
			var options := _get_autoload_options()
			if options.is_empty():
				return false
			if io.get(name) == null or (io.get(name) as String).is_empty():
				io.set(name, options[0].name)
			_add_option_picker(io, "autoload_name", options)
			return true
		"target_autoload":
			var options := _get_autoload_options()
			if options.is_empty():
				return false
			if io.get(name) == null or (io.get(name) as String).is_empty():
				io.set(name, options[0].name)
			_add_option_picker(io, "target_autoload", options)
			return true
		"signal_name":
			var options := _get_signal_options(io)
			if options.is_empty():
				return false
			# 当前值为空时自动选中第一项
			if io.get(name) == null or (io.get(name) as String).is_empty():
				io.set(name, options[0].name)
			_add_option_picker(io, "signal_name", options)
			_watch_signal_source(io)
			return true
		"method_name":
			var options := _get_method_options(io)
			if options.is_empty():
				return false
			# 当前值为空时自动选中第一项
			if io.get(name) == null or (io.get(name) as String).is_empty():
				io.set(name, options[0].name)
			_add_option_picker(io, "method_name", options)
			_watch_signal_source(io)
			return true
	return false


## options: Array[{name: String, display: String}]
func _add_option_picker(io: Resource, prop: String, options: Array) -> void:
	var current := io.get(prop) as String
	var btn := OptionButton.new()
	btn.flat = false
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in options.size():
		var opt := options[i] as Dictionary
		btn.add_item(opt.display)
		btn.set_item_metadata(i, opt.name)
	# 选中当前值
	var idx := -1
	for i in options.size():
		if options[i].name == current:
			idx = i
			break
	if idx >= 0:
		btn.select(idx)
	elif not current.is_empty():
		btn.add_item(current)
		btn.set_item_metadata(btn.item_count - 1, current)
		btn.select(btn.item_count - 1)
	btn.item_selected.connect(func(index: int):
		io.set(prop, btn.get_item_metadata(index))
	)
	add_property_editor(prop, btn)


# ===== 显示字符串工具 =====


## 345275223 signal_source 350265204346272220345217221347224237345217230345214226346227266357274214345210267346226260 IoBindBase 347232204345261236346200247345210227350241250357274214344275277 signal_name/method_name 344270213346213211350207252345212250346233264346226260
func _watch_signal_source(io: IoBindBase) -> void:
	var ss := io.signal_source
	if ss and not ss.is_connected(&"changed", _on_ss_changed):
		ss.changed.connect(_on_ss_changed.bind(io))


func _on_ss_changed(io: IoBindBase) -> void:
	io.notify_property_list_changed()

## 如果项目设置 SignalBinder/params/show_full_params = true 则显示全部参数，否则只显示前 2 个
static func _build_display(name: String, arg_names: Array) -> String:
	var show_full := ProjectSettings.get_setting("SignalBinder/params/show_full_params", false)
	if show_full:
		return name + "(" + ", ".join(arg_names) + ")"
	var max_args := 2
	var parts := arg_names.slice(0, max_args)
	var display := name + "(" + ", ".join(parts)
	if arg_names.size() > max_args:
		display += ", ...)"
	else:
		display += ")"
	return display


# ===== 查找上下文（兼容 IoBinder 和 IoBindMulti） =====

## 返回 {signal_owner: Node, path_context: Node}，找不到返回 {}
static func _find_context(io: IoBindBase) -> Dictionary:
	var scene := EditorInterface.get_edited_scene_root()
	if not scene:
		return {}

	# 查找 IoBinder 节点
	for node in scene.find_children("*", "IoBinder", true, false):
		var binder := node as IoBinder
		if binder and binder.iosets.has(io):
			var owner := binder.signal_owner if binder.signal_owner else binder.get_parent()
			return {"signal_owner": owner, "path_context": binder}

	# 查找 IoBindMulti → IoBindMultiConfig
	for node in scene.find_children("*", "IoBindMulti", true, false):
		var multi := node as IoBindMulti
		if not multi:
			continue
		for config in multi.ios:
			if config and config.iosets.has(io):
				var owner := multi.get_node(config.signal_path) if config.signal_path else null
				if owner:
					return {"signal_owner": owner, "path_context": multi}

	return {}


# ===== 自动加载脚本工具 =====

## 在编辑器中通过 ProjectSettings 解析自动加载路径，加载脚本读取信号
static func _get_autoload_signals(name: StringName) -> Array:
	var autoload_path := _get_autoload_script_path(name)
	if autoload_path.is_empty():
		return []
	var script := load(autoload_path) as Script
	if not script or not script.has_method("get_signal_list"):
		return []
	return script.get_script_signal_list()


static func _get_autoload_script_path(name: StringName) -> String:
	var key := "autoload/" + name
	if not ProjectSettings.has_setting(key):
		return ""
	var value := ProjectSettings.get_setting(key) as String
	# Godot 中 autoload 路径格式：有 * 包裹的是启用了的单例
	return value.strip_edges().trim_prefix("*").trim_suffix("*")


static func _get_autoload_options() -> Array:
	var result: Array = []
	var autoload_prefix := "autoload/"
	for key in ProjectSettings.get_property_list():
		var name: String = key["name"]
		if name.begins_with(autoload_prefix):
			var autoload_name := name.trim_prefix(autoload_prefix)
			result.append({"name": autoload_name, "display": autoload_name})
	result.sort_custom(func(a, b): return a.name < b.name)
	return result

# ===== 信号列表 =====

func _get_signal_options(io: IoBindBase) -> Array:
	var signal_node: Node = null
	# 优先使用 IoBindBase 自带的 signal_source
	if io.signal_source:
		match io.signal_source.source_type:
			IoSignalSource.Type.AUTOLOAD:
				var signals := _get_autoload_signals(io.signal_source.autoload_name)
				if signals.is_empty():
					return []
				return signals.map(func(s):
					return {"name": s["name"], "display": _build_display(s["name"], _get_arg_names(s))}
				)
			IoSignalSource.Type.NODE_PATH:
				var ctx := _find_context(io)
				if not ctx.is_empty():
					var pc := ctx.get("path_context") as Node
					if pc and pc.has_node(io.signal_source.node_path):
						signal_node = pc.get_node(io.signal_source.node_path)
			# PARENT → fallback 到 binder context
	if not signal_node:
		var ctx := _find_context(io)
		if ctx.is_empty():
			return []
		signal_node = ctx.signal_owner as Node
	if not is_instance_valid(signal_node):
		return []
	var signals := signal_node.get_signal_list()
	return signals.map(func(s):
		return {"name": s["name"], "display": _build_display(s["name"], _get_arg_names(s))}
	)


static func _get_arg_names(signal_dict: Dictionary) -> Array[String]:
	var args: Array = signal_dict.get("args", [])
	var names: Array[String] = []
	for a in args:
		names.append(a["name"] as String)
	return names

# ===== 方法列表 =====

func _get_method_options(io: IoBindBase) -> Array:
	var ctx := _find_context(io)
	if ctx.is_empty():
		return []

	var target: Object = _resolve_target(ctx, io)
	if not target:
		return []

	var raw_methods: Array = []

	# 单例脚本：直接获取脚本定义的方法
	if target is Script:
		var script := target as Script
		if script and script.has_method("get_script_method_list"):
			raw_methods = script.get_script_method_list()
	elif target.has_method("get_script"):
		# Node / Object：优先获取其脚本上定义的方法（不含继承的内置方法）
		var script: Script = target.get_script()
		if script and script.has_method("get_script_method_list"):
			raw_methods = script.get_script_method_list()

	# 回退：全部方法列表
	if raw_methods.is_empty():
		raw_methods = target.get_method_list()

	var result := _build_method_options(raw_methods)
	result = _clean_method_options(result)
	return result


func _build_method_options(methods: Array) -> Array:
	return methods.map(func(m):
		var name := m["name"] as String
		var args: Array = m.get("args", [])
		var arg_names: Array[String] = []
		for a in args:
			arg_names.append(a["name"] as String)
		return {"name": name, "display": _build_display(name, arg_names)}
	)


func _clean_method_options(options: Array) -> Array:
	# 去掉私有方法
	options = options.filter(func(o): return not o.name.begins_with("_"))
	# 按 name 去重（同名方法只保留第一个）
	var seen := {}
	var deduped: Array = []
	for opt in options:
		if not seen.has(opt.name):
			seen[opt.name] = true
			deduped.append(opt)
	# 按 name 排序
	deduped.sort_custom(func(a, b): return a.name < b.name)
	return deduped


func _resolve_target(ctx: Dictionary, io: IoBindBase) -> Object:
	var signal_owner := ctx.signal_owner as Node
	var path_context := ctx.path_context as Node
	if io is IoBindSelf:
		# 如果 Self 绑定了自动加载信号源，方法来自自动加载脚本
		if io.signal_source and io.signal_source.source_type == IoSignalSource.Type.AUTOLOAD:
			var _p := _get_autoload_script_path(io.signal_source.autoload_name)
			if not _p.is_empty():
				return load(_p)
		return signal_owner
	elif io is IoBindGroup:
		if io.group_name.is_empty():
			return null
		var tree := signal_owner.get_tree() if signal_owner else null
		if not tree:
			return null
		var nodes := tree.get_nodes_in_group(io.group_name)
		return nodes[0] if nodes.size() > 0 else null
	elif io is IoBindPath:
		if not io.node_path or not path_context:
			return null
		if path_context.has_node(io.node_path):
			return path_context.get_node(io.node_path)
		return null
	elif io is IoBindSingleton:
		return io.target_script
	elif io is IoBindGlobal:
		var _path := _get_autoload_script_path(io.target_autoload)
		if _path.is_empty():
			return null
		return load(_path)
	return null
