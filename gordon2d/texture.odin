package gordon

import "core:c"
import "core:slice"

import stbi "vendor:stb/image"
_ :: stbi

Image :: struct {
	pixels: [][4]u8,
	width:  i32,
	height: i32,
}


image_load_from_memory :: proc(data: []byte) -> (img: Image, ok: bool) {
	x, y, channels_in_file: c.int
	res := stbi.load_from_memory(raw_data(data), c.int(len(data)), &x, &y, &channels_in_file, 4)
	if res == nil {
		return
	}
	img.pixels = slice.reinterpret([][4]u8, res[:x*y*channels_in_file])
	img.width  = x
	img.height = y
	if channels_in_file != 4 {
		image_unload(img)
	} else {
		ok = true
	}
	return
}

image_unload :: proc(img: Image) {
	stbi.image_free(raw_data(img.pixels))
}


texture_load_default_white :: proc() -> (texture: Texture, ok: bool) {
	white_pixel := [4][4]u8{0..<4 = {255, 255, 255, 255}}
	img: Image
	img.pixels = white_pixel[:]
	img.width  = 2
	img.height = 2
	return texture_load_from_image(img)
}


texture_load_from_memory :: proc(data: []byte) -> (texture: Texture, ok: bool) {
	img := image_load_from_memory(data) or_return
	defer image_unload(img)

	return texture_load_from_image(img)
}

texture_load_from_image :: proc(img: Image) -> (texture: Texture, ok: bool) {
	return platform_texture_load_from_img(img)
}

texture_unload :: proc(tex: Texture) {
	platform_texture_unload(tex)
}
