# 临时脚本：为示例 mod 生成立绘与 idle 战斗小人（基于内置 hero 像素小人放大）。
extends SceneTree

func _init() -> void:
	var src: Texture2D = load("res://assets/units/hero.png")
	var img: Image = src.get_image()
	# 立绘 256x256（放大 8 倍，保持像素感）
	var portrait := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	portrait.fill(Color(0, 0, 0, 0))
	for y in range(32):
		for x in range(32):
			var c := img.get_pixel(x, y)
			for dy in range(8):
				for dx in range(8):
					portrait.set_pixel(x * 8 + dx, y * 8 + dy, c)
	portrait.save_png("res://mods/example_mod/art/units/SampleHero/portrait.png")
	# idle 战斗小人 64x64（放大 2 倍）
	var idle := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	idle.fill(Color(0, 0, 0, 0))
	for y in range(32):
		for x in range(32):
			var c := img.get_pixel(x, y)
			idle.set_pixel(x * 2, y * 2, c)
			idle.set_pixel(x * 2 + 1, y * 2, c)
			idle.set_pixel(x * 2, y * 2 + 1, c)
			idle.set_pixel(x * 2 + 1, y * 2 + 1, c)
	idle.save_png("res://mods/example_mod/art/units/SampleHero/idle.png")
	print("sample mod art generated")
	quit(0)
