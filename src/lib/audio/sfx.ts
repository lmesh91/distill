import { soundEffects, type SoundEffect } from './assets.ts';
import type { MusicAudio, MusicStorage } from './music.ts';

export const sfxStorageKey = 'distill-sfx';

/** noticeable without being louder than the music */
export const sfxVolume = 0.5;

/** the parts of an <audio> element sound effects use, so tests can pass a fake */
export type EffectAudio = Pick<MusicAudio, 'volume' | 'play' | 'pause'> & { currentTime: number };

export interface SoundEffectsOptions {
	createAudio: (src: string) => EffectAudio;
	storage?: MusicStorage;
}

/**
 * short interface sounds (#21): a click for actions, success for an accepted proof, error for a
 * rejected one. they're on by default, can be switched off next to the music controls (#175),
 * and the choice is remembered between visits. they're independent of the music, so muting the
 * music doesn't silence them
 */
export class SoundEffects {
	#options: SoundEffectsOptions;
	#enabled = true;
	#audios = new Map<SoundEffect, EffectAudio>();
	#listeners = new Set<(enabled: boolean) => void>();

	constructor(options: SoundEffectsOptions) {
		this.#options = options;
		try {
			const saved = options.storage?.getItem(sfxStorageKey);
			if (saved) this.#enabled = JSON.parse(saved).enabled !== false;
		} catch {
			// blocked storage or a malformed value: keep the default
		}
	}

	get enabled() {
		return this.#enabled;
	}

	setEnabled(enabled: boolean) {
		this.#enabled = enabled;
		try {
			this.#options.storage?.setItem(sfxStorageKey, JSON.stringify({ enabled }));
		} catch {
			// the change still applies until the page reloads
		}
		for (const listener of this.#listeners) listener(enabled);
	}

	/** calls `listener` now and after every change; returns a function that stops it */
	subscribe(listener: (enabled: boolean) => void): () => void {
		this.#listeners.add(listener);
		listener(this.#enabled);
		return () => this.#listeners.delete(listener);
	}

	/** loads the sounds ahead of time so the first one plays without a delay */
	preload() {
		for (const name of Object.keys(soundEffects) as SoundEffect[]) this.#audio(name);
	}

	play(name: SoundEffect) {
		if (!this.#enabled) return;
		const audio = this.#audio(name);
		// restart it if the same sound is still playing, e.g. two quick clicks
		audio.pause();
		audio.currentTime = 0;
		// a refusal (autoplay before any interaction) just means no sound this time
		audio.play().catch(() => {});
	}

	#audio(name: SoundEffect): EffectAudio {
		let audio = this.#audios.get(name);
		if (!audio) {
			audio = this.#options.createAudio(soundEffects[name]);
			audio.volume = sfxVolume;
			this.#audios.set(name, audio);
		}
		return audio;
	}
}
