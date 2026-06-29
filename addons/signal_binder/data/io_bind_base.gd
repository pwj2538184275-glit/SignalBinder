@abstract
@icon("../icons/IoBindBase.svg")
class_name IoBindBase
extends Resource

## 参数传递模式
enum ParamMode {
	## 只用 parameters（默认，向后兼容）
	STATIC_ONLY,
	## parameters + 信号参数（信号参数拼在后面）
	APPEND_SIGNAL,
	## 信号参数 + parameters（信号参数拼在前面）
	PREPEND_SIGNAL,
	## 只用信号参数，忽略 parameters
	SIGNAL_ONLY,
}

@export_category("信号源")
## 信号源定义（空 = 使用 IoBinder 的 signal_owner）
@export var signal_source: IoSignalSource
## 监听的信号名
@export var signal_name: StringName
## 目标方法名
@export var method_name: StringName

@export_category("参数")
## 静态参数（编辑器中配置）
@export var parameters: Array
## 参数传递模式
@export var param_mode: ParamMode = ParamMode.STATIC_ONLY

@export_group("执行控制")
## 延迟执行（秒，0 = 立即）
@export var delay: float = 0.0
## 仅触发一次后自动断开连接
@export var fire_once: bool = false
## 调试模式：触发时在控制台打印信号→方法调用日志
@export var debug: bool = false

@export_group("条件判断")
@export_custom(PROPERTY_HINT_GROUP_ENABLE,"条件判断") var condition_end:bool=false
## 条件方法名（可选）：执行前调用 signal_owner 上此方法检查条件
@export var condition_method: StringName
## 判断和condition相同就触发
@export var condition:bool = true
