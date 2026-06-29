@tool
@icon("../icons/IoSignalSource.svg")
## 信号源定义：替代 IoBinder 上固定的 signal_owner，
## 每个 IO 绑定可独立指定信号来源
class_name IoSignalSource
extends Resource

enum Type {
	## 使用 IoBinder 的父节点（默认，兼容旧版）
	PARENT,
	## 指定节点路径（相对于 IoBinder）
	NODE_PATH,
	## 自动加载脚本（Singleton）
	AUTOLOAD,
}

## 信号源类型
@export var source_type: Type = Type.PARENT

## 当 source_type == NODE_PATH 时的节点路径
@export var node_path: NodePath

## 当 source_type == AUTOLOAD 时的自动加载脚本名
@export var autoload_name: StringName


func get_signal_source():
	match source_type:
		Type.NODE_PATH:
			if node_path:
				return node_path
		Type.AUTOLOAD:
			if autoload_name:
				return autoload_name
	return null
