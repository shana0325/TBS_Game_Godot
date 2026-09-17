# 界面主操作按钮的统一外观，供各页面复用。
class_name MenuStyle
extends RefCounted

# 为推进流程的按钮设置金色强调及悬停、按下状态。
static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#775b31"), Color("#e9c47a")))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#9b7440"), Color("#fff0bc")))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#594424"), Color("#dcb46b")))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("#775b31"), Color("#fff0bc")))
	button.add_theme_color_override("font_color", Color("#fff6dc"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 19)

# 创建与全局紫色面板协调的圆角按钮样式。
static func _make_button_style(fill: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0.01, 0.01, 0.03, 0.4)
	style.shadow_size = 5
	return style
