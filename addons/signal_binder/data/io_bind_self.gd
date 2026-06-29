## 调用 signal_owner 自身的方法
class_name IoBindSelf
extends IoBindBase

@export_category("目标 — 自身")
## 此 IO 会调用 signal_owner（监听信号的那个节点）自身的方法
## 无需额外配置，method_name 即 signal_owner 上的方法
