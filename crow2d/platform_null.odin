#+build !js
#+build !windows
#+private
package crowd2d

Platform_Data :: struct {
}

@(require_results)
platform_init :: proc(ctx: ^Context) -> bool {
	return false
}

platform_fini :: proc(ctx: ^Context) {

}

@(require_results)
platform_update :: proc(ctx: ^Context) -> bool {
	return false
}

@(require_results)
platform_draw :: proc(ctx: ^Context) -> bool {
	return false
}

@(require_results)
platform_texture_load_from_img :: proc(ctx: ^Context, img: Image, opts: Texture_Options) -> (tex: Texture, ok: bool) {
	return
}

platform_texture_unload :: proc(ctx: ^Context, tex: Texture) {

}