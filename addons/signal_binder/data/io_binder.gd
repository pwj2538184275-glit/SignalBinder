@tool
@icon("../icons/IoBinder.svg")
extends Node
class_name IoBinder

# TODO 校验所有 IO 连接（编辑器下点击触发）
#@export_tool_button("Validate Connections") var validate := _validate_all
## 信号所有者（监听此节点上的信号并触发 IO）
@export var signal_owner: Node
## IO 配置列表
@export var iosets: Array[IoBindBase]

var _executor: IoBindExecutor


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not signal_owner:
		signal_owner = get_parent()
	_executor = IoBindExecutor.new(signal_owner, self)
	_executor.connect_all(iosets)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _executor:
		_executor.disconnect_all()


# ===== 编辑器校验 =====

#region 检验

func _validate_all() -> void:
	print("\n=== IoBinder Validation ===")
	var owner_name := signal_owner.name if signal_owner else "<null>"
	print(" signal_owner: %s" % owner_name)
	print(" in_tree:      %s" % is_inside_tree())
	print(" iosets:       %d" % iosets.size())
	print("")
	if not signal_owner:
		printerr(" ✗ signal_owner 未赋值!")
		print("========================\n")
		return
	if not is_instance_valid(signal_owner):
		printerr(" ✗ signal_owner 已失效（节点可能已被删除）!")
		print("========================\n")
		return
	var error_count := 0
	for i in iosets.size():
		var io := iosets[i]
		var type_name := io.get_class() if io else "null"
		print("--- [%d] %s ---" % [i, type_name])
		if not io:
			printerr("  ✗ iosets[%d] 为空!" % i)
			error_count += 1
			continue
		# 检查信号名
		if io.signal_name.is_empty():
			printerr("  ✗ signal_name 为空")
			error_count += 1
		elif not signal_owner.has_signal(io.signal_name):
			printerr("  ✗ 信号 '%s' 在 '%s' 上不存在" % [io.signal_name, signal_owner.name])
			error_count += 1
		else:
			var arg_count := _get_signal_arg_count(io.signal_name)
			print("  ✓ 信号 '%s' 存在（%d 个参数）" % [io.signal_name, arg_count])
		# 检查方法名
		if io.method_name.is_empty():
			printerr("  ✗ method_name 为空")
			error_count += 1
		# 类型专有检查
		if io is IoBindGroup:
			error_count += _validate_group(io)
		elif io is IoBindPath:
			error_count += _validate_path(io)
		elif io is IoBindSingleton:
			error_count += _validate_singleton(io)
		elif io is IoBindSelf:
			error_count += _validate_ower(io)
		else:
			push_warning("  ? 未知 IoBindBase 子类型: %s" % type_name)
	if error_count > 0:
		printerr("\n ✗ 共 %d 个错误" % error_count)
	else:
		print("\n ✓ 全部通过")
	print("========================\n")


func _get_signal_arg_count(signal_name: StringName) -> int:
	for signal_dict in signal_owner.get_signal_list():
		if signal_dict.name == signal_name:
			return signal_dict.args.size()
	return 0


func _validate_group(io: IoBindGroup) -> int:
	var errors := 0
	if io.group_name.is_empty():
		printerr("  ✗ group_name 为空")
		return 1
	if not is_inside_tree():
		print("  ? 不在场景树中，跳过运行时组检查")
		return 0
	var nodes := get_tree().get_nodes_in_group(io.group_name)
	if nodes.is_empty():
		push_warning("  ? 组 '%s' 中没有节点" % io.group_name)
	else:
		var method_found := false
		for node in nodes:
			if node.has_method(io.method_name):
				method_found = true
				break
		if method_found:
			print("  ✓ 组 '%s' → %d 个节点，方法 '%s' 存在" % [io.group_name, nodes.size(), io.method_name])
		else:
			push_warning("  ? 组 '%s' 有 %d 个节点，但均无方法 '%s'" % [io.group_name, nodes.size(), io.method_name])
	return errors


func _validate_ower(io: IoBindSelf) -> int:
	var errors := 0
	if not is_inside_tree():
		print("  ? 不在场景树中，跳过运行时组检查")
		return 0
	if signal_owner.has_method(io.method_name):
		print("  ✓ 节点 '%s'，方法 '%s' 存在" % [signal_owner.name, io.method_name])
	else:
		push_warning("  ? 节点 '%s'，无方法 '%s'" % [signal_owner.name, io.method_name])
		errors = 1
	return errors


func _validate_path(io: IoBindPath) -> int:
	var errors := 0
	var path_str := str(io.node_path)
	if not io.node_path or io.node_path.is_empty():
		printerr("  ✗ node_path 为空")
		return 1

	if not is_inside_tree():
		print("  ? 不在场景树中，跳过 node_path 解析")
		return 0

	if has_node(io.node_path):
		var node := get_node(io.node_path)
		if node.has_method(io.method_name):
			print("  ✓ node_path '%s' → '%s'，方法存在" % [path_str, node.name])
		else:
			printerr("  ✗ 节点 '%s' 没有方法 '%s'" % [node.name, io.method_name])
			errors += 1
	else:
		push_warning("  ? node_path '%s' 无法解析（运行时有效？）" % path_str)

	return errors


func _validate_singleton(io: IoBindSingleton) -> int:
	var errors := 0
	if not io.target_script:
		printerr("  ✗ IoBindSingleton: target_script 为空")
		return 1
	if io.method_name.is_empty():
		return errors
	if io.target_script.has_method(io.method_name):
		print("  ✓ 脚本 '%s' 上有方法 '%s'" % [io.target_script.resource_path, io.method_name])
	else:
		printerr("  ✗ 脚本 '%s' 上没有方法 '%s'" % [io.target_script.resource_path, io.method_name])
		errors += 1
	return errors
#endregion
