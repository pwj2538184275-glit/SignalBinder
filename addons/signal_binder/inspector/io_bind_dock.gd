@tool
extends MarginContainer

const IO_SHOW = preload("io_show.tscn") 
@onready var io_shows: VBoxContainer = %IoShows
@onready var updata: Button = %updata
@onready var fold_button: Button = %fold
var is_fold:bool = true

func _ready() -> void:
	updata.button_down.connect(refresh)
	fold_button.button_down.connect(fold)

func fold():
	if is_fold:
		fold_button.text = "Expand"
	
	else:
		fold_button.text = "Collapse"
	for io_show in io_shows.get_children():
		io_show.switch(is_fold)
	is_fold = !is_fold

func refresh() -> void:
	for child in io_shows.get_children():
		child.queue_free()
	if not is_inside_tree():
		return
	var root_node := EditorInterface.get_edited_scene_root()
	var recursion := ProjectSettings.get_setting("SignalBinder/params/recursion", false)
	if not root_node:
		return
	var c_iobinder := root_node.find_children("*","IoBinder",recursion)
	for io:IoBinder in c_iobinder:
		var io_show = IO_SHOW.instantiate()
		io_shows.add_child(io_show)
		io_show.refresh_iobinder(io)
	var c_iobindmulti := root_node.find_children("*","IoBindMulti",recursion)
	for iom:IoBindMulti in c_iobindmulti:
		var io_show = IO_SHOW.instantiate()
		io_shows.add_child(io_show)
		io_show.refresh_iobindmulti(iom)
