import assert from 'node:assert/strict';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { test } from 'node:test';
import { backgroundMusic, soundEffects } from '../../../src/lib/audio/assets.ts';

const files = [...Object.values(soundEffects), ...Object.values(backgroundMusic)];
const credits = readFileSync('static/audio/CREDITS.md', 'utf8');

test('every audio file the app uses exists in static/', () => {
	for (const path of files) {
		const file = `static${path}`;
		assert.ok(existsSync(file), `${file} is missing`);
		assert.ok(statSync(file).size > 0, `${file} is empty`);
	}
});

test('every audio file is credited with its license in static/audio/CREDITS.md', () => {
	for (const path of files) {
		const name = path.replace('/audio/', '');
		assert.ok(credits.includes(`\`${name}\``), `${name} has no row in CREDITS.md`);
	}
	assert.match(credits, /CC0 1\.0/);
});
