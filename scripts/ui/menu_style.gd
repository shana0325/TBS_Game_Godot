# 为各界面提供简洁的深色面板、标题栏和有明确底色的按钮样式。
class_name MenuStyle
extends RefCounted

# 推进流程按钮与普通按钮共用底色，避免出现额外的强调色。
static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _flat(Color(0.21, 0.21, 0.34), 12))
	button.add_theme_stylebox_override("hover", _flat(Color(0.29, 0.29, 0.45), 12))
	button.add_theme_stylebox_override("pressed", _flat(Color(0.36, 0.34, 0.53), 12))
	button.add_theme_stylebox_override("focus", _flat(Color.TRANSPARENT, 0))
	button.add_theme_color_override("font_color", Color(0.91, 0.89, 0.83))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.71))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.82))

# 用底色和文字亮度表示当前目录项。
static func apply_navigation(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _flat(Color("#363557") if selected else Color.TRANSPARENT, 10))
	button.add_theme_stylebox_override("hover", _flat(Color("#444465"), 10))
	button.add_theme_stylebox_override("pressed", _flat(Color("#55547d"), 10))
	button.add_theme_stylebox_override("focus", _flat(Color.TRANSPARENT, 0))
	button.add_theme_color_override("font_color", Color("#f2e7ff") if selected else Color("#aaa9bf"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

# 创建全屏资料页的纯色底面。
static func frame_panel_style() -> StyleBoxFlat:
	return _flat(Color("#17192b"), 14)

# 创建内容区的轻微色差底面。
static func section_panel_style() -> StyleBoxFlat:
	return _flat(Color("#202139"), 14)

# 创建无装饰的章节标题栏。
static func header_style() -> StyleBoxFlat:
	return _flat(Color("#242540"), 14)

# 创建不带描边的纯色样式，保留内容与边缘的必要间距。
static func _flat(color: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(padding)
	return style
