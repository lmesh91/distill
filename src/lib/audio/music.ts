import { backgroundMusic, type MusicTrack } from './assets.ts';

export interface MusicSettings {
	muted: boolean;
	/** 0 to 1 */
	volume: number;
}

/** what a new visitor gets: music on, quiet enough to sit under the sound effects (#21) */
export const defaultMusicSettings: MusicSettings = { muted: false, volume: 0.3 };

export const musicStorageKey = 'distill-music';

/** reads saved settings, falling back to the defaults for anything missing or malformed */
export function parseMusicSettings(raw: string | null): MusicSettings {
	if (!raw) return { ...defaultMusicSettings };
	try {
		const saved: unknown = JSON.parse(raw);
		if (typeof saved !== 'object' || saved === null) return { ...defaultMusicSettings };
		const { muted, volume } = saved as Partial<Record<keyof MusicSettings, unknown>>;
		return {
			muted: typeof muted === 'boolean' ? muted : defaultMusicSettings.muted,
			volume:
				typeof volume === 'number' && Number.isFinite(volume)
					? clampVolume(volume)
					: defaultMusicSettings.volume
		};
	} catch {
		return { ...defaultMusicSettings };
	}
}

export function clampVolume(volume: number): number {
	return Math.min(1, Math.max(0, volume));
}

/** the parts of an <audio> element the player uses, so tests can pass a fake */
export interface MusicAudio {
	loop: boolean;
	volume: number;
	readonly paused: boolean;
	play(): Promise<void>;
	pause(): void;
}

/** where settings are saved; `localStorage` in the browser */
export type MusicStorage = Pick<Storage, 'getItem' | 'setItem'>;

/** what the player listens on for the user's first interaction; `window` in the browser */
export type GestureTarget = Pick<EventTarget, 'addEventListener' | 'removeEventListener'>;

export interface MusicState extends MusicSettings {
	/** whether the music is audible right now */
	playing: boolean;
	/** the browser blocked autoplay; playback starts on the next click or key press */
	waitingForGesture: boolean;
}

export interface MusicPlayerOptions {
	createAudio: (src: string) => MusicAudio;
	storage?: MusicStorage;
	gestures?: GestureTarget;
	track?: MusicTrack;
}

// the events browsers count as a user activation that allows audio to start
const gestureEvents = ['pointerdown', 'keydown'] as const;

/**
 * background music for the game (#175). it plays while a game page is open (`enter`/`leave`),
 * follows the user's mute and volume, and remembers both between visits
 *
 * browsers block audio until the user interacts with the page, so if `play()` is refused the
 * player waits for the first click or key press and tries again
 */
export class MusicPlayer {
	#options: MusicPlayerOptions;
	#audio: MusicAudio | null = null;
	#settings: MusicSettings;
	#active = false;
	#playing = false;
	#waiting = false;
	/** a play() call is in flight, so don't start another */
	#starting = false;
	#listeners = new Set<(state: MusicState) => void>();

	constructor(options: MusicPlayerOptions) {
		this.#options = options;
		let saved: string | null = null;
		try {
			saved = options.storage?.getItem(musicStorageKey) ?? null;
		} catch {
			// storage can be blocked; the defaults apply for this visit
		}
		this.#settings = parseMusicSettings(saved);
	}

	get state(): MusicState {
		return { ...this.#settings, playing: this.#playing, waitingForGesture: this.#waiting };
	}

	/** calls `listener` now and after every change; returns a function that stops it */
	subscribe(listener: (state: MusicState) => void): () => void {
		this.#listeners.add(listener);
		listener(this.state);
		return () => this.#listeners.delete(listener);
	}

	/** a game page opened: start the music unless the user muted it */
	enter() {
		this.#active = true;
		this.#sync();
	}

	/** the user left the game pages: stop the music but keep its place */
	leave() {
		this.#active = false;
		this.#sync();
	}

	setMuted(muted: boolean) {
		this.#update({ muted });
	}

	toggleMuted() {
		this.setMuted(!this.#settings.muted);
	}

	/** turning the volume up from silence also unmutes, like most players */
	setVolume(volume: number) {
		const clamped = clampVolume(volume);
		this.#update(clamped > 0 ? { volume: clamped, muted: false } : { volume: clamped });
	}

	#update(change: Partial<MusicSettings>) {
		this.#settings = { ...this.#settings, ...change };
		try {
			this.#options.storage?.setItem(musicStorageKey, JSON.stringify(this.#settings));
		} catch {
			// storage can be blocked or full; the change still applies until the page reloads
		}
		this.#sync();
	}

	get #shouldPlay() {
		return this.#active && !this.#settings.muted && this.#settings.volume > 0;
	}

	#sync() {
		if (this.#shouldPlay) {
			const audio = this.#ensureAudio();
			audio.volume = this.#settings.volume;
			if (audio.paused && !this.#starting) this.#tryPlay(audio);
		} else {
			this.#audio?.pause();
			this.#playing = false;
			this.#stopWaiting();
		}
		this.#emit();
	}

	#ensureAudio(): MusicAudio {
		if (!this.#audio) {
			// created on first use so pages where the music stays off never download it
			this.#audio = this.#options.createAudio(
				backgroundMusic[this.#options.track ?? 'concentration']
			);
			this.#audio.loop = true;
		}
		return this.#audio;
	}

	#tryPlay(audio: MusicAudio) {
		this.#starting = true;
		audio.play().then(
			() => {
				this.#starting = false;
				// the user may have muted or left while play() was pending
				if (!this.#shouldPlay) {
					audio.pause();
					return;
				}
				this.#playing = true;
				this.#stopWaiting();
				this.#emit();
			},
			() => {
				this.#starting = false;
				// refused, almost always the autoplay policy: try again on the next interaction
				this.#playing = false;
				this.#waitForGesture();
				this.#emit();
			}
		);
	}

	#onGesture = () => {
		this.#stopWaiting();
		this.#sync();
	};

	#waitForGesture() {
		if (this.#waiting || !this.#options.gestures) return;
		this.#waiting = true;
		for (const event of gestureEvents) {
			this.#options.gestures.addEventListener(event, this.#onGesture, { capture: true });
		}
	}

	#stopWaiting() {
		if (!this.#waiting) return;
		this.#waiting = false;
		for (const event of gestureEvents) {
			this.#options.gestures?.removeEventListener(event, this.#onGesture, { capture: true });
		}
	}

	#emit() {
		const state = this.state;
		for (const listener of this.#listeners) listener(state);
	}
}
