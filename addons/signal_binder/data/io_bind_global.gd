## signal_owner 上的信号触发时，调用自动加载脚本（Singleton）上的实例方法
class_name IoBindGlobal
extends IoBindBase

## 目标自动加载脚本名（例如 "ScoreManager"、"GameState"）
## signal_owner 上的 signal_name 信号触发时，调用此自动加载脚本的 method_name 方法
@export var target_autoload: StringName
