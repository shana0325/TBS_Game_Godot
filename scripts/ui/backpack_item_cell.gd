## 背包道具格子：显示道具名称/数量，提供悬停提示和技能书拖拽数据。
class_name BackpackItemCell
extends Button

var item_kind: String = ""
var item_id: String = ""
var item_title: String = ""
var item_count: int = 0
var item_description: String = ""

func setup(p_kind: String, p_id: String, p_title: String, p_count: int, p_description: String) -> void:
	item_kind = p_kind
	item_id = p_id
	item_title = p_title
	item_count = p_count
	item_description = p_description
	text = "%s\n×%d" % [item_title, item_count]
	tooltip_text = item_description
	custom_minimum_size = Vector2(130, 94)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_font_size_override("font_size", 16)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_kind != "skill_book":
		return null
	# 关闭背包遮罩后，拖拽过程才能把部署界面作为真正的放置目标。
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is BackpackPanel:
			(ancestor as BackpackPanel).close()
			break
		ancestor = ancestor.get_parent()
	var preview := Label.new()
	preview.text = "%s\n×%d" % [item_title, item_count]
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_theme_color_override("font_color", Color("#f2d08b"))
	preview.add_theme_font_size_override("font_size", 16)
	preview.custom_minimum_size = Vector2(130, 70)
	set_drag_preview(preview)
	return {"kind": "skill_book", "skill_id": item_id}
