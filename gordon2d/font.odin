package gordon

import stbtt "vendor:stb/truetype"

_ :: stbtt

Font :: struct {
	info: stbtt.fontinfo,

	atlas: Texture,
	atlas_width: i32,
	atlas_height: i32,

	size: i32,
	ascent: i32,
	descent: i32,
	line_gap: i32,
	baseline: i32,

	backed_chars: [96]stbtt.bakedchar,
}

FONT_ATLAS_SIZE :: 1024

@(private="file")
temp_font_atlas_data: [FONT_ATLAS_SIZE*FONT_ATLAS_SIZE]u8

@(private="file")
temp_font_atlas_pixels: [FONT_ATLAS_SIZE*FONT_ATLAS_SIZE][4]u8


font_load_from_memory :: proc(data: []byte, size: i32) -> (f: Font, ok: bool) {
	size := size
	size = max(size, 1)
	stbtt.InitFont(&f.info, raw_data(data), 0) or_return
	f.size = size

	scale := stbtt.ScaleForPixelHeight(&f.info, f32(f.size))
	stbtt.GetFontVMetrics(&f.info, &f.ascent, &f.descent, &f.line_gap)
	f.baseline = i32(f32(f.ascent)*scale)


	f.atlas_width = FONT_ATLAS_SIZE
	f.atlas_height = FONT_ATLAS_SIZE
	stbtt.BakeFontBitmap(raw_data(data), 0, f32(size), raw_data(temp_font_atlas_data[:]), FONT_ATLAS_SIZE, FONT_ATLAS_SIZE, 32, len(f.backed_chars), raw_data(f.backed_chars[:]))
	for b, i in temp_font_atlas_data {
		temp_font_atlas_pixels[i] = {255, 255, 255, b}
	}

	img := Image{
		pixels = temp_font_atlas_pixels[:],
		width  = FONT_ATLAS_SIZE,
		height = FONT_ATLAS_SIZE,
	}
	f.atlas = texture_load_from_image(img) or_return

	return
}

font_unload :: proc(f: Font) {
	texture_unload(f.atlas)
}


draw_text :: proc(ctx: ^Context, f: ^Font, text: string, pos: Vec2, color: Color) {
	set_texture(ctx, f.atlas)

	next := pos
	for c in text {
		c := c
		switch c {
		case '\n':
			next.x = pos.x
			next.y += f32(f.size)
		case '\r', '\t':
			c = ' '
		}
		if 32 <= c && c < 128 {
			q: stbtt.aligned_quad
			stbtt.GetBakedQuad(&f.backed_chars[0], f.atlas_width, f.atlas_height, i32(c)-32, &next.x, &next.y, &q, true)


			a := Vertex{pos = {q.x0, q.y0}, uv = {q.s0, q.t0}, col = color}
			b := Vertex{pos = {q.x1, q.y0}, uv = {q.s1, q.t0}, col = color}
			c := Vertex{pos = {q.x1, q.y1}, uv = {q.s1, q.t1}, col = color}
			d := Vertex{pos = {q.x0, q.y1}, uv = {q.s0, q.t1}, col = color}

			append(&ctx.vertices, a, b, c)
			append(&ctx.vertices, c, d, a)
		}
	}
}
