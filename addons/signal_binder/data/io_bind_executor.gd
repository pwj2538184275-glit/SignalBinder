class_name IoBindExecutor
extends RefCounted

## 默认信号所有者（当 IoBindBase 未指定 signal_source 时的回退）
var signal_owner: Node
## 用于解析 NodePath 的上下文节点
var _path_context: Node
## 已建立的信号连接列表
var _connections: Array[Dictionary] = []


func _init(p_signal_owner: Node, p_path_context: Node = p_signal_owner) -> void:
	signal_owner = p_signal_owner
	_path_context = p_path_context


## 连接所有 IO 配置
func connect_all(iosets: Array[IoBindBase]) -> void:
	for io in iosets:
		if not io:
			continue
		var source := _resolve_source(io)
		if not source:
			push_warning("IoBindExecutor: 信号源不可用，跳过 %s" % io.signal_name)
			continue
		if not source.has_signal(io.signal_name):
			push_warning("IoBindExecutor: 信号 '%s' 不在 '%s' 上" % [io.signal_name, _source_name(source)])
			continue
		_connect_io(io, source)


## 断开所有连接
func disconnect_all() -> void:
	for conn in _connections:
		var source: Object = conn.get("source")
		if source and is_instance_valid(source) and source.is_connected(conn.signal_name, conn.callable):
			source.disconnect(conn.signal_name, conn.callable)
	_connections.clear()


## 解析单个 IO 绑定的信号源
func _resolve_source(io: IoBindBase) -> Node:
	# 如果 IoBindBase 有自己的 signal_source 配置，优先使用
	if io.signal_source:
		match io.signal_source.source_type:
			IoSignalSource.Type.NODE_PATH:
				if io.signal_source.node_path:
					return _path_context.get_node(io.signal_source.node_path)
				return null
			IoSignalSource.Type.AUTOLOAD:
				return signal_owner.get_node("/root/" + io.target_autoload)
			_:
				return signal_owner
	# 回退：使用 executor 的默认 signal_owner
	return signal_owner


func _source_name(source: Node) -> String:
	return source.name if source else "null"


func _connect_io(io: IoBindBase, source: Node) -> void:
	var arg_count := _get_node_signal_arg_count(source, io.signal_name)
	var handler := _build_handler(io, arg_count, source)
	source.connect(io.signal_name, handler)
	_connections.append({ "signal_name": io.signal_name, "callable": handler, "io": io, "source": source })


func _get_node_signal_arg_count(node: Node, signal_name: StringName) -> int:
	for signal_dict in node.get_signal_list():
		if signal_dict.name == signal_name:
			return signal_dict.args.size()
	return 0


## 构建闭包处理器
func _build_handler(io: IoBindBase, arg_count: int, source: Node) -> Callable:
	if arg_count > 5:
		push_warning("IoBindExecutor: 信号 '%s' 有 %d 个参数，超过最大支持数 5" % [io.signal_name, arg_count])
	return func(_a = null, _b = null, _c = null, _d = null, _e = null):
		var signal_args: Array = []
		var collected := [_a, _b, _c, _d, _e]
		for i in range(min(arg_count, 5)):
			signal_args.append(collected[i])
		_execute(io, signal_args, source)


func _execute(io: IoBindBase, signal_args: Array, source: Node) -> void:
	if not is_instance_valid(source):
		return
	# 调试日志
	if io.debug:
		var args_str := ", ".join(signal_args.map(func(v): return str(v)))
		prints("[IoBind]", _source_name(source), io.signal_name, "(%s)" % args_str, "→", io.method_name)
	# 延迟执行
	if io.delay > 0.0:
		await source.get_tree().create_timer(io.delay).timeout
		if not is_instance_valid(source):
			return
	# fire_once
	if io.fire_once:
		_disconnect_io(io)
	# 合成参数
	var args := compose_args(io, signal_args)
	# 分发
	_dispatch(io, args, source)


## 断开指定的 IO 连接
func _disconnect_io(io: IoBindBase) -> void:
	for i in range(_connections.size() - 1, -1, -1):
		var conn := _connections[i] as Dictionary
		if conn.io == io:
			var source: Object = conn.get("source")
			if source and is_instance_valid(source) and source.is_connected(conn.signal_name, conn.callable):
				source.disconnect(conn.signal_name, conn.callable)
			_connections.remove_at(i)
			return


## 按 ParamMode 合成最终调用参数
static func compose_args(io: IoBindBase, signal_args: Array) -> Array:
	match io.param_mode:
		IoBindBase.ParamMode.STATIC_ONLY:
			return io.parameters.duplicate()
		IoBindBase.ParamMode.SIGNAL_ONLY:
			return signal_args.duplicate()
		IoBindBase.ParamMode.APPEND_SIGNAL:
			return io.parameters + signal_args
		IoBindBase.ParamMode.PREPEND_SIGNAL:
			return signal_args + io.parameters
		_:
			return io.parameters.duplicate()


func _dispatch(io: IoBindBase, args: Array, source: Node) -> void:
	if io is IoBindGroup:
		_invoke_group(io, args)
	elif io is IoBindPath:
		_invoke_path(io, args)
	elif io is IoBindSingleton:
		_invoke_singleton(io, args)
	elif io is IoBindSelf:
		if not _condition(io,source):
			return
		_invoke_self(source, io.method_name, args)
	elif io is IoBindGlobal:
		_invoke_global(io, args)


func _invoke_self(source: Node, method: StringName, args: Array) -> void:
	
	if source.has_method(method):
		source.callv(method, args)


func _invoke_group(io: IoBindGroup, args: Array) -> void:
	var tree := _resolve_tree()
	if not tree:
		return
	var nodes := tree.get_nodes_in_group(io.group_name)
	for node: Node in nodes:
		if not _condition(io,node):
			continue
		if node.has_method(io.method_name):
			node.callv(io.method_name, args)


func _invoke_path(io: IoBindPath, args: Array) -> void:
	var node: Node
	if io.node_path:
		node = _path_context.get_node(io.node_path)
	if not _condition(io,node):
		return
	if node and node.has_method(io.method_name):
		node.callv(io.method_name, args)


func _invoke_singleton(io: IoBindSingleton, args: Array) -> void:
	if not io.target_script:
		push_warning("IoBindSingleton: target_script 为空")
		return
	if not io.target_script.has_method(io.method_name):
		push_warning("IoBindSingleton: %s 上无方法 %s" % [io.target_script.resource_path, io.method_name])
		return
	if not _condition(io,io.target_script):
		return
	io.target_script.callv(io.method_name, args)


func _invoke_global(io: IoBindGlobal, args: Array) -> void:
	var target := signal_owner.get_node("/root/" + io.target_autoload)
	if not target:
		push_warning("IoBindExecutor: 自动加载脚本 '%s' 不存在" % io.target_autoload)
		return
	if not target.has_method(io.method_name):
		push_warning("IoBindExecutor: 自动加载脚本 '%s' 上无方法 %s" % [io.target_autoload, io.method_name])
		return
	if not _condition(io,target):
		return
	target.callv(io.method_name, args)


func _resolve_tree() -> SceneTree:
	if _path_context and is_instance_valid(_path_context):
		return _path_context.get_tree()
	if signal_owner and is_instance_valid(signal_owner):
		return signal_owner.get_tree()
	return null

func _condition(io:IoBindBase,target)->bool:
	if io.condition_end and io.condition_method:
		if not target.has_method(io.condition_method):
			if target is Node:
				push_warning("IoBindExecutor: condition_method '%s' 不在 '%s' 上" % [io.condition_method, _source_name(target)])
			elif target is Script:
				push_warning("IoBindExecutor: condition_method '%s' 不在 '%s' 上" % [io.condition_method,target.resource_path])
			return false
		if target.call(io.condition_method) != io.condition:
			return false
	return true
