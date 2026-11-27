import { MusicPlayer, type MusicStorage } from './music.ts';
import { SoundEffects } from './sfx.ts';

let player: MusicPlayer | undefined;
let effects: SoundEffects | undefined;

// localStorage itself can throw when site data is blocked
function browserStorage(): MusicStorage | undefined {
	try {
		return localStorage;
	} catch {
		return undefined;
	}
}

/** the one music player for the whole site; browser only, so call it from onMount or an event */
export function getMusicPlayer(): MusicPlayer {
	player ??= new MusicPlayer({
		createAudio: (src) => {
			const audio = new Audio(src);
			audio.preload = 'auto';
			return audio;
		},
		storage: browserStorage(),
		gestures: window
	});
	return player;
}

/** the site's interface sounds (#21); browser only, like the music player */
export function getSoundEffects(): SoundEffects {
	effects ??= new SoundEffects({
		createAudio: (src) => {
			const audio = new Audio(src);
			audio.preload = 'auto';
			return audio;
		},
		storage: browserStorage()
	});
	return effects;
}

/**
 * plays an interface sound, and does nothing during server rendering. safe to call from any
 * event handler
 */
export function playSound(name: Parameters<SoundEffects['play']>[0]) {
	if (typeof window === 'undefined') return;
	getSoundEffects().play(name);
}
