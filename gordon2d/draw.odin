package gordon

import "core:math"
import "core:math/linalg"

Camera :: struct {
	offset:           Vec2,
	target:           Vec2,
	rotation_radians: f32,
	zoom:             f32,
	near:             f32,
	far:              f32,
}
Camera_Default :: Camera{
	zoom = 1,
	near = -1024,
	far  = +1024,
}

WHITE :: Colour{255, 255, 255, 255}


Vertex :: struct {
	pos: Vec2,
	col: Colour,
	uv:  Vec2,
}

Draw_Call :: struct {
	shader:     Shader,
	texture:    Texture,
	layer:      f32,
	depth_test: bool,

	offset:     int,
	length:     int,
}

@(require_results)
default_draw_call :: proc(ctx: ^Context) -> Draw_Call {
	dc := Draw_Call{}
	dc.shader = ctx.default_shader
	dc.texture = ctx.default_texture
	return dc
}

set_shader :: proc(ctx: ^Context, shader: Shader) {
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		if last.shader == shader {
			return
		}
		dc = last^
	}
	dc.shader = shader
	append(&ctx.draw_calls, dc)
}

set_texture :: proc(ctx: ^Context, t: Texture) {
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		if last.texture == t {
			return
		}
		dc = last^
	}
	dc.texture = t
	append(&ctx.draw_calls, dc)
}

set_depth_test :: proc(ctx: ^Context, test: bool) {
	dc := default_draw_call(ctx)
	if len(ctx.draw_calls) != 0 {
		last := &ctx.draw_calls[len(ctx.draw_calls)-1]
		if last.depth_test == test {
			return
		}
		dc = last^
	}
	dc.depth_test = test
	append(&ctx.draw_calls, dc)
}



check_draw_call :: proc(ctx: ^Context) {
	if len(ctx.draw_calls) == 0 {
		dc := Draw_Call{}
		dc.shader = ctx.default_shader
		append(&ctx.draw_calls, dc)
	}
}


draw_rect :: proc(ctx: ^Context, pos: Vec2, size: Vec2, col: Colour) {
	check_draw_call(ctx)

	a := pos
	b := pos + {size.x, 0}
	c := pos + {size.x, size.y}
	d := pos + {0, size.y}

	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
	append(&ctx.vertices, Vertex{pos = b, col = col, uv = {1, 0}})
	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})

	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})
	append(&ctx.vertices, Vertex{pos = d, col = col, uv = {0, 1}})
	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
}


draw_rect_textured :: proc(ctx: ^Context, pos: Vec2, size: Vec2, tex: Texture, col := WHITE) {
	check_draw_call(ctx)
	set_texture(ctx, tex)

	a := pos
	b := pos + {size.x, 0}
	c := pos + {size.x, size.y}
	d := pos + {0, size.y}

	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
	append(&ctx.vertices, Vertex{pos = b, col = col, uv = {1, 0}})
	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})

	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})
	append(&ctx.vertices, Vertex{pos = d, col = col, uv = {0, 1}})
	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
}


draw_rect_outlines :: proc(ctx: ^Context, pos: Vec2, size: Vec2, thickness: f32, col: Colour) {
	draw_rect(ctx, pos + {0, -thickness}, {size.x+thickness, thickness}, col)
	draw_rect(ctx, pos + {size.x, 0}, {thickness, size.y+thickness}, col)

	draw_rect(ctx, pos + {-thickness, size.y}, {size.x+thickness, thickness}, col)
	draw_rect(ctx, pos + {-thickness, -thickness}, {thickness, size.y+thickness}, col)
}

@(private)
rotate_vector :: proc(v: Vec2, c, s: f32) -> (r: Vec2) {
	return {c*v.x - s*v.y, s*v.x + c*v.y}
}

draw_rect_rotated :: proc(ctx: ^Context, pos: Vec2, size: Vec2, origin: Vec2, rotation_radians: f32, col: Colour) {
	offset := len(ctx.vertices)

	s, c := math.sincos(rotation_radians)

	draw_rect(ctx, pos, size, col)
	for &v in ctx.vertices[offset:] {
		p := v.pos
		p = rotate_vector(p - pos - origin, c, s)
		p += pos
		v.pos = p
	}
}

draw_rect_rotated_outlines :: proc(ctx: ^Context, pos: Vec2, size: Vec2, origin: Vec2, rotation_radians: f32, thickness: f32, col: Colour) {
	offset := len(ctx.vertices)

	s, c := math.sincos(rotation_radians)

	draw_rect_outlines(ctx, pos, size, thickness, col)
	for &v in ctx.vertices[offset:] {
		p := v.pos
		p = rotate_vector(p - pos - origin, c, s)
		p += pos
		v.pos = p
	}
}



draw_quad :: proc(ctx: ^Context, verts: [4]Vec2, col: Colour) {
	check_draw_call(ctx)

	a := Vertex{pos = verts[0], col = col}
	b := Vertex{pos = verts[1], col = col}
	c := Vertex{pos = verts[2], col = col}
	d := Vertex{pos = verts[3], col = col}

	append(&ctx.vertices, a, b, c)
	append(&ctx.vertices, c, d, a)
}

draw_line :: proc(ctx: ^Context, start, end: Vec2, thickness: f32, col: Colour) {
	check_draw_call(ctx)


	dx := end-start
	dy := linalg.normalize0(Vec2{-dx.y, +dx.x})

	t := dy*thickness*0.5
	a := start + t
	b := end   + t
	c := end   - t
	d := start - t

	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
	append(&ctx.vertices, Vertex{pos = b, col = col, uv = {1, 0}})
	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})

	append(&ctx.vertices, Vertex{pos = c, col = col, uv = {1, 1}})
	append(&ctx.vertices, Vertex{pos = d, col = col, uv = {0, 1}})
	append(&ctx.vertices, Vertex{pos = a, col = col, uv = {0, 0}})
}

draw_circle :: proc(ctx: ^Context, centre: Vec2, radius: f32, col: Colour, segments: int = 32) {
	draw_ellipse(ctx, centre, {radius, radius}, col, segments)
}


draw_ellipse :: proc(ctx: ^Context, centre: Vec2, #no_broadcast radii: Vec2, col: Colour, segments: int = 32) {
	check_draw_call(ctx)


	c := Vertex{pos = centre, col = col}

	for i in 0..<segments {
		t0 := f32(i+0)/f32(segments) * math.TAU
		t1 := f32(i+1)/f32(segments) * math.TAU

		a := c
		b := c

		a.pos.x += radii.x * math.cos(t0)
		a.pos.y += radii.y * math.sin(t0)

		b.pos.x += radii.x * math.cos(t1)
		b.pos.y += radii.y * math.sin(t1)

		append(&ctx.vertices, c, a, b)
	}
}


draw_ring :: proc(ctx: ^Context, centre: Vec2, inner_radius, outer_radius: f32, angle_start, angle_end: f32, col: Colour, segments: int = 32) {
	check_draw_call(ctx)

	p := Vertex{pos = centre, col = col}

	for i in 0..<segments {
		t0 := math.lerp(angle_start, angle_end, f32(i+0)/f32(segments))
		t1 := math.lerp(angle_start, angle_end, f32(i+1)/f32(segments))

		a := p
		b := p
		c := p
		d := p

		a.pos.x += outer_radius * math.cos(t0)
		a.pos.y += outer_radius * math.sin(t0)

		b.pos.x += outer_radius * math.cos(t1)
		b.pos.y += outer_radius * math.sin(t1)


		c.pos.x += inner_radius * math.cos(t1)
		c.pos.y += inner_radius * math.sin(t1)

		d.pos.x += inner_radius * math.cos(t0)
		d.pos.y += inner_radius * math.sin(t0)

		append(&ctx.vertices, a, b, c)
		append(&ctx.vertices, c, d, a)
	}
}

draw_sector :: proc(ctx: ^Context, centre: Vec2, radius: f32, angle_start, angle_end: f32, col: Colour, segments: int = 32) {
	draw_ring(ctx, centre, 0, radius, angle_start, angle_end, col, segments)
}

draw_sector_outline :: proc(ctx: ^Context, centre: Vec2, radius: f32, thickness: f32, angle_start, angle_end: f32, col: Colour, segments: int = 32) {
	draw_ring(ctx, centre, radius, radius+thickness, angle_start, angle_end, col, segments)
}

draw_ellipse_ring :: proc(ctx: ^Context, centre: Vec2, #no_broadcast inner_radii, outer_radii: Vec2, angle_start, angle_end: f32, col: Colour, segments: int = 32) {
	check_draw_call(ctx)

	p := Vertex{pos = centre, col = col}

	for i in 0..<segments {
		t0 := math.lerp(angle_start, angle_end, f32(i+0)/f32(segments))
		t1 := math.lerp(angle_start, angle_end, f32(i+1)/f32(segments))

		a := p
		b := p
		c := p
		d := p

		a.pos.x += outer_radii.x * math.cos(t0)
		a.pos.y += outer_radii.y * math.sin(t0)

		b.pos.x += outer_radii.x * math.cos(t1)
		b.pos.y += outer_radii.y * math.sin(t1)


		c.pos.x += inner_radii.x * math.cos(t1)
		c.pos.y += inner_radii.y * math.sin(t1)

		d.pos.x += inner_radii.x * math.cos(t0)
		d.pos.y += inner_radii.y * math.sin(t0)

		append(&ctx.vertices, a, b, c)
		append(&ctx.vertices, c, d, a)
	}
}

draw_ellipse_arc :: proc(ctx: ^Context, centre: Vec2, radii: Vec2, thickness: f32, angle_start, angle_end: f32, col: Colour, segments: int = 32) {
	draw_ellipse_ring(ctx, centre, radii, radii+thickness, angle_start, angle_end, col, segments)
}


draw_triangle :: proc(ctx: ^Context, v0, v1, v2: Vec2, col: Colour) {
	check_draw_call(ctx)


	a := Vertex{pos = v0, col = col}
	b := Vertex{pos = v1, col = col}
	c := Vertex{pos = v2, col = col}

	append(&ctx.vertices, a, b, c)
}


draw_triangle_lines :: proc(ctx: ^Context, v0, v1, v2: Vec2, thickness: f32, col: Colour) {
	draw_line(ctx, v0, v1, thickness, col)
	draw_line(ctx, v1, v2, thickness, col)
	draw_line(ctx, v2, v0, thickness, col)
}


draw_triangle_strip :: proc(ctx: ^Context, points: []Vec2, col: Colour) {
	if len(points) < 3 {
		return
	}

	check_draw_call(ctx)

	for i in 2..<len(points) {
		a, b, c: Vertex
		a.col = col
		b.col = col
		c.col = col

		if i&1 == 0 {
			a.pos = points[i]
			b.pos = points[i-2]
			c.pos = points[i-1]
		} else {
			a.pos = points[i]
			b.pos = points[i-1]
			c.pos = points[i-2]
		}
		append(&ctx.vertices, a, b, c)
	}
}


draw_line_strip :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Colour) {
	if len(points) < 2 {
		return
	}

	check_draw_call(ctx)

	for i in 0..<len(points)-1 {
		draw_line(ctx, points[i], points[i+1], thickness, col)
	}
}


draw_spline_linear :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Colour) {
	if len(points) < 2 {
		return
	}

	prev_normal := Vec2{-points[1].y + points[0].y, points[1].x - points[0].x}
	prev_normal = linalg.normalize0(prev_normal)

	prev_radius := 0.5*thickness*prev_normal

	for i in 0..<len(points)-1 {
		normal: Vec2
		if i < len(points)-2 {
			normal = Vec2{-points[i+2].y + points[i+1].y, points[i+2].x - points[i+1].x}
			normal = linalg.normalize0(normal)
		} else {
			normal = prev_normal
		}

		radius := linalg.normalize(prev_normal + normal)

		cos_theta := linalg.dot(radius, normal)
		if cos_theta != 0 {
			radius *= 0.5*thickness/cos_theta
		} else {
			radius = {0, 0}
		}

		strip := [4]Vec2{
			{points[i].x - prev_radius.x, points[i].y - prev_radius.y},
			{points[i].x + prev_radius.x, points[i].y + prev_radius.y},
			{points[i+1].x - radius.x,    points[i+1].y - radius.y},
			{points[i+1].x + radius.x,    points[i+1].y + radius.y},
		}

		draw_triangle_strip(ctx, strip[:], col)

		prev_radius = radius
		prev_normal = normal
	}
}


SPLINE_SEGMENT_DIVISIONS :: 24

draw_spline_basis :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Colour) {
	if len(points) < 4 {
		return
	}

	a, b: [4]f32
	dy := f32(0)
	dx := f32(0)
	size := f32(0)

	curr_point: Vec2
	next_point: Vec2
	vertices: [2*SPLINE_SEGMENT_DIVISIONS + 2]Vec2

	for i in 0..<len(points)-3 {
		p0 := points[i+0]
		p1 := points[i+1]
		p2 := points[i+2]
		p3 := points[i+3]

		a[0] = (-p0.x + 3*p1.x - 3*p2.x + p3.x)/6
		a[1] = (3*p0.x - 6*p1.x + 3*p2.x)/6
		a[2] = (-3*p0.x + 3*p2.x)/6
		a[3] = (p0.x + 4*p1.x + p2.x)/6

		b[0] = (-p0.y + 3*p1.y - 3*p2.y + p3.y)/6
		b[1] = (3*p0.y - 6*p1.y + 3*p2.y)/6
		b[2] = (-3*p0.y + 3*p2.y)/6
		b[3] = (p0.y + 4*p1.y + p2.y)/6

		curr_point.x = a[3]
		curr_point.y = b[3]

		if i == 0 {
			draw_circle(ctx, curr_point, thickness*0.5, col)
		}

		if i > 0 {
			vertices[0].x = curr_point.x + dy*size
			vertices[0].y = curr_point.y - dx*size
			vertices[1].x = curr_point.x - dy*size
			vertices[1].y = curr_point.y + dx*size
		}

		for j in 1..=SPLINE_SEGMENT_DIVISIONS {
			t := f32(j)/f32(SPLINE_SEGMENT_DIVISIONS)

			next_point.x = a[3] + t*(a[2] + t*(a[1] + t*a[0]))
			next_point.y = b[3] + t*(b[2] + t*(b[1] + t*b[0]))

			dy = next_point.y - curr_point.y
			dx = next_point.x - curr_point.x
			size = 0.5*thickness/math.sqrt(dx*dx+dy*dy)

			if (i == 0) && (j == 1) {
				vertices[0].x = curr_point.x + dy*size
				vertices[0].y = curr_point.y - dx*size
				vertices[1].x = curr_point.x - dy*size
				vertices[1].y = curr_point.y + dx*size
			}

			vertices[2*j + 1].x = next_point.x - dy*size
			vertices[2*j + 1].y = next_point.y + dx*size
			vertices[2*j].x = next_point.x + dy*size
			vertices[2*j].y = next_point.y - dx*size

			curr_point = next_point
		}

	        draw_triangle_strip(ctx, vertices[:], col)
	}

	draw_circle(ctx, curr_point, thickness*0.5, col)
}

draw_spline_catmull_rom :: proc(ctx: ^Context, points: []Vec2, thickness: f32, col: Colour) {
	if len(points) < 4 {
		return
	}

	dy := f32(0)
	dx := f32(0)
	size := f32(0)

	curr_point := points[1]
	next_point: Vec2
	vertices: [2*SPLINE_SEGMENT_DIVISIONS + 2]Vec2

	draw_circle(ctx, curr_point, thickness*0.5, col)

	for i in 0..<len(points)-3 {
		p0 := points[i+0]
		p1 := points[i+1]
		p2 := points[i+2]
		p3 := points[i+3]

		if i > 0 {
			vertices[0].x = curr_point.x + dy*size
			vertices[0].y = curr_point.y - dx*size
			vertices[1].x = curr_point.x - dy*size
			vertices[1].y = curr_point.y + dx*size
		}

		for j in 1..=SPLINE_SEGMENT_DIVISIONS {
			t := f32(j)/f32(SPLINE_SEGMENT_DIVISIONS)

			q0 := (-1.0*t*t*t) + (2.0*t*t) + (-1.0*t)
			q1 := (3.0*t*t*t) + (-5.0*t*t) + 2.0
			q2 := (-3.0*t*t*t) + (4.0*t*t) + t
			q3 := t*t*t - t*t

			next_point.x = 0.5*((p0.x*q0) + (p1.x*q1) + (p2.x*q2) + (p3.x*q3))
			next_point.y = 0.5*((p0.y*q0) + (p1.y*q1) + (p2.y*q2) + (p3.y*q3))

			dy = next_point.y - curr_point.y
			dx = next_point.x - curr_point.x
			size = (0.5*thickness)/math.sqrt(dx*dx + dy*dy)

			if (i == 0) && (j == 1) {
				vertices[0].x = curr_point.x + dy*size
				vertices[0].y = curr_point.y - dx*size
				vertices[1].x = curr_point.x - dy*size
				vertices[1].y = curr_point.y + dx*size
			}

			vertices[2*j + 1].x = next_point.x - dy*size
			vertices[2*j + 1].y = next_point.y + dx*size
			vertices[2*j].x = next_point.x + dy*size
			vertices[2*j].y = next_point.y - dx*size

			curr_point = next_point
		}

	        draw_triangle_strip(ctx, vertices[:], col)
	}

	draw_circle(ctx, curr_point, thickness*0.5, col)
}