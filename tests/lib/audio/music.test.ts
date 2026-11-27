import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
	MusicPlayer,
	defaultMusicSettings,
	musicStorageKey,
	parseMusicSettings,
	type MusicAudio,
	type MusicState
} from '../../../src/lib/audio/music.ts';
import { backgroundMusic } from '../../../src/lib/audio/assets.ts';

/** an <audio> stand-in whose play() is refused until `allow` is set, like a browser's autoplay */
class FakeAudio implements MusicAudio {
	loop = false;
	volume = 1;
	paused = true;
	playCalls = 0;
	allow = true;
	readonly src: string;
	constructor(src: string) {
		this.src = src;
	}
	play() {
		this.playCalls++;
		if (!this.allow) return Promise.reject(new DOMException('blocked', 'NotAllowedError'));
		this.paused = false;
		return Promise.resolve();
	}
	pause() {
		this.paused = true;
	}
}

class FakeStorage {
	values = new Map<string, string>();
	getItem(key: string) {
		return this.values.get(key) ?? null;
	}
	setItem(key: string, value: string) {
		this.values.set(key, value);
	}
}

/** an event target that records the gesture listeners and can fire them */
class FakeWindow extends EventTarget {
	click() {
		this.dispatchEvent(new Event('pointerdown'));
	}
	tap() {
		this.dispatchEvent(new Event('touchend'));
	}
}

// lets pending play() promises settle
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

function setup({ allow = true, saved }: { allow?: boolean; saved?: string } = {}) {
	const audios: FakeAudio[] = [];
	const storage = new FakeStorage();
	if (saved !== undefined) storage.setItem(musicStorageKey, saved);
	const gestures = new FakeWindow();
	const player = new MusicPlayer({
		createAudio: (src) => {
			const audio = new FakeAudio(src);
			audio.allow = allow;
			audios.push(audio);
			return audio;
		},
		storage,
		gestures
	});
	let state: MusicState = player.state;
	player.subscribe((next) => (state = next));
	return { player, audios, storage, gestures, state: () => state };
}

test('saved settings are read back, and anything malformed falls back to the defaults', () => {
	assert.deepEqual(parseMusicSettings('{"muted":true,"volume":0.8}'), { muted: true, volume: 0.8 });
	assert.deepEqual(parseMusicSettings(null), defaultMusicSettings);
	assert.deepEqual(parseMusicSettings('not json'), defaultMusicSettings);
	assert.deepEqual(parseMusicSettings('"a string"'), defaultMusicSettings);
	assert.deepEqual(parseMusicSettings('{"muted":"yes","volume":7}'), {
		muted: defaultMusicSettings.muted,
		volume: 1
	});
});

test('nothing is downloaded or played until a game page opens', () => {
	const { audios } = setup();
	assert.equal(audios.length, 0);
});

test('opening a game page plays the looping track at the saved volume', async () => {
	const { player, audios, state } = setup({ saved: '{"muted":false,"volume":0.5}' });
	player.enter();
	await settle();
	assert.equal(audios.length, 1);
	assert.equal(audios[0].src, backgroundMusic.concentration);
	assert.equal(audios[0].loop, true);
	assert.equal(audios[0].volume, 0.5);
	assert.equal(state().playing, true);
});

test('each page plays its own track, and going back resumes the old one', async () => {
	const { player, audios } = setup();
	player.enter('calm');
	await settle();
	assert.equal(audios[0].src, backgroundMusic.calm);

	player.enter('concentration');
	await settle();
	assert.equal(audios[0].paused, true, 'the home track stops when a game page opens');
	assert.equal(audios[1].src, backgroundMusic.concentration);
	assert.equal(audios[1].paused, false);

	player.enter('calm');
	await settle();
	assert.equal(audios.length, 2, 'the home track resumes instead of a new one starting');
	assert.equal(audios[0].paused, false);
	assert.equal(audios[1].paused, true);
});

test('when the next page enters before the old one leaves, the new track keeps playing', async () => {
	const { player, audios, state } = setup();
	player.enter('calm');
	await settle();
	player.enter('concentration');
	player.leave('calm');
	await settle();
	assert.equal(audios[1].paused, false);
	assert.equal(state().playing, true);
});

test('a saved mute is respected: the music never starts', async () => {
	const { player, audios, state } = setup({ saved: '{"muted":true,"volume":0.5}' });
	player.enter();
	await settle();
	assert.equal(audios.length, 0);
	assert.equal(state().playing, false);
});

test('when autoplay is blocked, the music starts on the first click or key press', async () => {
	const { player, audios, gestures, state } = setup({ allow: false });
	player.enter();
	await settle();
	assert.equal(state().playing, false);
	assert.equal(state().waitingForGesture, true);

	audios[0].allow = true;
	gestures.click();
	await settle();
	assert.equal(state().playing, true);
	assert.equal(state().waitingForGesture, false);

	// the gesture listener is gone once the music started
	const calls = audios[0].playCalls;
	gestures.click();
	await settle();
	assert.equal(audios[0].playCalls, calls);
});

test('on touch screens the music starts when the first tap lifts', async () => {
	const { player, audios, gestures, state } = setup({ allow: false });
	player.enter();
	await settle();
	audios[0].allow = true;
	gestures.tap();
	await settle();
	assert.equal(state().playing, true);
});

test('muting pauses the music and is remembered; unmuting resumes it', async () => {
	const { player, audios, storage, state } = setup();
	player.enter();
	await settle();
	player.toggleMuted();
	assert.equal(audios[0].paused, true);
	assert.equal(state().muted, true);
	assert.deepEqual(JSON.parse(storage.getItem(musicStorageKey)!), {
		muted: true,
		volume: defaultMusicSettings.volume
	});

	player.toggleMuted();
	await settle();
	assert.equal(audios[0].paused, false);
	assert.equal(audios.length, 1, 'the same track resumes instead of a new one starting');
});

test('volume changes apply right away and are remembered; raising it from silence unmutes', async () => {
	const { player, audios, storage, state } = setup({ saved: '{"muted":true,"volume":0.3}' });
	player.enter();
	player.setVolume(0.7);
	await settle();
	assert.equal(state().muted, false);
	assert.equal(audios[0].volume, 0.7);
	assert.deepEqual(JSON.parse(storage.getItem(musicStorageKey)!), { muted: false, volume: 0.7 });

	player.setVolume(0);
	assert.equal(audios[0].paused, true);
	player.setVolume(-3);
	assert.equal(state().volume, 0);
});

test('leaving the game pages stops the music, and mute while a start is pending wins', async () => {
	const { player, audios, state } = setup();
	player.enter();
	await settle();
	player.leave();
	assert.equal(audios[0].paused, true);
	assert.equal(state().playing, false);

	player.enter();
	player.setMuted(true);
	await settle();
	assert.equal(audios[0].paused, true);
	assert.equal(state().playing, false);
});

test('repeated syncs while play() is pending start playback only once', async () => {
	const { player, audios } = setup();
	player.enter();
	player.setVolume(0.4);
	player.setVolume(0.5);
	await settle();
	assert.equal(audios[0].playCalls, 1);
});

test('blocked storage does not break the player', async () => {
	const throwing = {
		getItem: () => {
			throw new Error('blocked');
		},
		setItem: () => {
			throw new Error('blocked');
		}
	};
	const player = new MusicPlayer({ createAudio: (src) => new FakeAudio(src), storage: throwing });
	assert.deepEqual(
		{ muted: player.state.muted, volume: player.state.volume },
		defaultMusicSettings
	);
	player.setMuted(true);
	assert.equal(player.state.muted, true);
});
