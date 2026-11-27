import assert from 'node:assert/strict';
import { test } from 'node:test';
import { SoundEffects, sfxStorageKey, sfxVolume } from '../../../src/lib/audio/sfx.ts';
import { soundEffects } from '../../../src/lib/audio/assets.ts';

class FakeAudio {
	volume = 1;
	currentTime = 0;
	plays = 0;
	refuse = false;
	readonly src: string;
	constructor(src: string) {
		this.src = src;
	}
	play() {
		this.plays++;
		return this.refuse ? Promise.reject(new Error('NotAllowedError')) : Promise.resolve();
	}
	pause() {}
}

function setup(saved?: string) {
	const audios: FakeAudio[] = [];
	const values = new Map<string, string>();
	if (saved !== undefined) values.set(sfxStorageKey, saved);
	const storage = {
		getItem: (key: string) => values.get(key) ?? null,
		setItem: (key: string, value: string) => void values.set(key, value)
	};
	const effects = new SoundEffects({
		createAudio: (src) => {
			const audio = new FakeAudio(src);
			audios.push(audio);
			return audio;
		},
		storage
	});
	return { effects, audios, values };
}

test('each sound plays its own file at the effects volume', () => {
	const { effects, audios } = setup();
	effects.play('success');
	assert.equal(audios.length, 1);
	assert.equal(audios[0].src, soundEffects.success);
	assert.equal(audios[0].volume, sfxVolume);
	assert.equal(audios[0].plays, 1);
});

test('playing a sound again restarts it instead of loading it again', () => {
	const { effects, audios } = setup();
	effects.play('click');
	audios[0].currentTime = 0.2;
	effects.play('click');
	assert.equal(audios.length, 1);
	assert.equal(audios[0].currentTime, 0);
	assert.equal(audios[0].plays, 2);
});

test('switching effects off silences them and is remembered', () => {
	const { effects, audios, values } = setup();
	effects.setEnabled(false);
	effects.play('error');
	assert.equal(audios.length, 0);
	assert.deepEqual(JSON.parse(values.get(sfxStorageKey)!), { enabled: false });
	assert.equal(setup(values.get(sfxStorageKey)).effects.enabled, false);
});

test('effects are on by default, and a malformed saved value keeps the default', () => {
	assert.equal(setup().effects.enabled, true);
	assert.equal(setup('not json').effects.enabled, true);
});

test('a refused play is ignored instead of throwing', async () => {
	const { effects, audios } = setup();
	effects.preload();
	assert.equal(audios.length, Object.keys(soundEffects).length);
	for (const audio of audios) audio.refuse = true;
	assert.doesNotThrow(() => effects.play('click'));
	await new Promise((resolve) => setTimeout(resolve, 0));
});

test('subscribers hear the current setting and every change', () => {
	const { effects } = setup();
	const seen: boolean[] = [];
	const stop = effects.subscribe((enabled) => seen.push(enabled));
	effects.setEnabled(false);
	stop();
	effects.setEnabled(true);
	assert.deepEqual(seen, [true, false]);
});
