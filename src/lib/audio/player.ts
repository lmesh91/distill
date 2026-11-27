import { MusicPlayer, type MusicStorage } from './music.ts';

let player: MusicPlayer | undefined;

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
