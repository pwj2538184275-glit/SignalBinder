class_name IoBindMultiConfig
extends Resource

## 监听节点
@export_node_path("Node") var signal_path: NodePath
## IO 配置列表
@export var iosets: Array[IoBindBase]
var node: Node
var _executor: IoBindExecutor


func execute(_node: Node) -> void:
	if Engine.is_editor_hint():
		return
	node = _node
	var owner := node.get_node(signal_path)
	if not owner:
		return
	_executor = IoBindExecutor.new(owner, node)
	_executor.connect_all(iosets)


func exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _executor:
		_executor.disconnect_all()
