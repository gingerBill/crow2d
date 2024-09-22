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

Texture_Filter :: enum u8 {
	Linear,
	Nearest,
}

Texture_Wrap :: enum u8 {
	Clamp_To_Edge,
	Repeat,
	Mirrored_Repeat,
}

Texture_Options :: struct {
	filter: Texture_Filter,
	wrap:   [2]Texture_Wrap,
}

TEXTURE_OPTIONS_DEFAULT :: Texture_Options{}


texture_load_default_white :: proc() -> (texture: Texture, ok: bool) {
	white_pixel := [1][4]u8{0..<1 = {255, 255, 255, 255}}
	img: Image
	img.pixels = white_pixel[:]
	img.width  = 1
	img.height = 1
	return texture_load_from_image(img, TEXTURE_OPTIONS_DEFAULT)
}


texture_load_from_memory :: proc(data: []byte, opts := TEXTURE_OPTIONS_DEFAULT) -> (texture: Texture, ok: bool) {
	img := image_load_from_memory(data) or_return
	defer image_unload(img)

	return texture_load_from_image(img, opts)
}

texture_load_from_image :: proc(img: Image, opts := TEXTURE_OPTIONS_DEFAULT) -> (texture: Texture, ok: bool) {
	return platform_texture_load_from_img(img, opts)
}

texture_unload :: proc(tex: Texture) {
	platform_texture_unload(tex)
}
