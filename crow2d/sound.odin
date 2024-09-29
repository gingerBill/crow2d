package crowd2d

Audio_Source :: struct {
	next:     ^Audio_Source,
	sound:    ^Sound,
	rate:     f32,
	position: int,
}

Sound_Flag :: enum u32 {
	Loop,
	Fade_Out,
	Fade_In,
}

Sound_Flags :: distinct bit_set[Sound_Flag; u32]

Sound :: struct {
	name:                string,
	flags:               Sound_Flags,
	volume:              f32,
	rate:                i32,
	channels:            i32,
	samples:             []f32,
	samples_per_channel: i32,
	sources_count:       i32,
}


Sound_Error :: enum u32 {
	None,
	Too_Many_Sources,
	No_Source,
}

sound_play :: proc(ctx: ^Context, sound: ^Sound) -> Sound_Error {
	if sound.sources_count > 3 {
		return .Too_Many_Sources
	}

	source: ^Audio_Source
	if ctx.audio_source_pool == nil {
		source = new(Audio_Source)
	} else {
		source = ctx.audio_source_pool
		ctx.audio_source_pool = source.next
	}

	if source == nil {
		return .No_Source
	}
	sound.sources_count += 1
	source^ = {}
	source.sound = sound
	source.rate = f32(sound.rate) / f32(ctx.sound_sample_rate)
	source.next = ctx.audio_source_pool
	ctx.audio_source_playback = source
	return nil
}

sound_stop :: proc(ctx: ^Context, sound: ^Sound) -> Sound_Error {
	if sound.sources_count == 0 {
		return .No_Source
	}

	it := &ctx.audio_source_playback
	for it^ != nil {
		if it^.sound == sound {
			next := it^.next
			it^.next = ctx.audio_source_pool
			ctx.audio_source_pool = it^
			sound.sources_count -= 1
			it^ = next
		} else {
			it = &it^.next
		}
	}

	assert(sound.sources_count == 0)
	return nil
}


