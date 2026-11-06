/**
 * paths to Distill's audio files in static/audio (#176). the background music player (#175) and
 * interface sounds (#21) should use these instead of hard-coding paths
 * credits and licenses for every file are in static/audio/CREDITS.md
 */
export const soundEffects = {
	/** buttons and selections */
	click: '/audio/sfx/click.mp3',
	/** an accepted proof or a completed level */
	success: '/audio/sfx/success.mp3',
	/** a rejected proof or a failed action */
	error: '/audio/sfx/error.mp3'
} as const;

export type SoundEffect = keyof typeof soundEffects;

export const backgroundMusic = {
	/** 8-bit loop for while the user works on a level */
	concentration: '/audio/music/concentration-loop.mp3'
} as const;

export type MusicTrack = keyof typeof backgroundMusic;
