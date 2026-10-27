/** what the save indicator shows
 * `at` is a millisecond timestamp */
export type SaveState =
	| { kind: 'idle' }
	| { kind: 'saving' }
	| { kind: 'saved'; at: number }
	| { kind: 'error'; message: string; retrying: boolean };

/** thrown by a save function
 * `retryable` errors are retried automatically */
export class SaveError extends Error {
	readonly retryable: boolean;

	constructor(message: string, retryable: boolean) {
		super(message);
		this.retryable = retryable;
	}
}

export interface AutosaverOptions {
	/** saves `code` for one level. Resolves when saved
	 * rejects (ideally with a SaveError) on failure */
	save: (code: string, savedAt: number, options: { keepalive: boolean }) => Promise<void>;
	onstate: (state: SaveState) => void;
	// wait this long after the last edit before saving
	delay?: number;
	// wait this long before retrying a failed save
	retryDelay?: number;
	now?: () => number;
}

/**
 * debounced autosave for one level's code
 *
 * create one per level: the `save` function decides where the code goes, so code is never
 * written to a different level. Call `flush()` when leaving the level so the last edit
 * isn't lost or saved late
 */
export function createAutosaver({
	save,
	onstate,
	delay = 500,
	retryDelay = 5000,
	now = Date.now
}: AutosaverOptions) {
	let pending: string | null = null;
	let timer: ReturnType<typeof setTimeout> | undefined;
	let running: Promise<void> = Promise.resolve();
	let disposed = false;

	function startTimer(ms: number) {
		clearTimeout(timer);
		timer = setTimeout(() => {
			timer = undefined;
			void run(false);
		}, ms);
	}

	// saves run one at a time, so an older save can never finish after a newer one starts
	function run(keepalive: boolean): Promise<void> {
		running = running.then(async () => {
			if (pending === null) return;
			const code = pending;
			pending = null;
			const savedAt = now();
			onstate({ kind: 'saving' });
			try {
				await save(code, savedAt, { keepalive });
				// newer edits may have arrived while saving
				// their own timer will save them
				if (pending === null) onstate({ kind: 'saved', at: savedAt });
			} catch (error) {
				const retryable = !(error instanceof SaveError) || error.retryable;
				const message = error instanceof SaveError ? error.message : 'Could not save.';
				// keep the failed code unless the user has typed something newer since
				pending ??= code;
				onstate({ kind: 'error', message, retrying: retryable && !disposed });
				if (retryable && !disposed) startTimer(retryDelay);
			}
		});
		return running;
	}

	return {
		// call on every edit. Saves `delay` ms after the edits stop
		schedule(code: string) {
			if (disposed) return;
			pending = code;
			startTimer(delay);
		},
		// saves any waiting edit right away. Use `keepalive` when the page is closing
		flush({ keepalive = false } = {}): Promise<void> {
			clearTimeout(timer);
			timer = undefined;
			return run(keepalive);
		},
		// saves any waiting edit, then stops: later edits and retries are ignored
		dispose(): Promise<void> {
			const done = this.flush();
			disposed = true;
			return done;
		},
		// true while an edit is waiting to be saved
		get hasPending() {
			return pending !== null;
		}
	};
}

export type Autosaver = ReturnType<typeof createAutosaver>;

export type SaveIcon = 'not-saved' | 'saving' | 'saved' | 'error';

export interface SaveIndicator {
	icon: SaveIcon;
	// full sentence for the tooltip and screen readers
	label: string;
	// small text next to the icon, e.g. "just now" or "5 min ago"
	time: string;
}

// how long ago a save was, short enough for the editor's title bar
export function timeSince(at: number, now: number): string {
	const seconds = Math.max(0, Math.floor((now - at) / 1000));
	if (seconds < 60) return 'just now';
	const minutes = Math.floor(seconds / 60);
	if (minutes < 60) return `${minutes} min ago`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours} hr ago`;
	const days = Math.floor(hours / 24);
	return `${days} day${days === 1 ? '' : 's'} ago`;
}

/**
 * what the save indicator shows
 * `lastSavedAt` is the last successful save, so saving and errors can still show it.
 * `loading` is true while the page loads another level's saved code
 */
export function describeSaveState(
	state: SaveState,
	lastSavedAt: number | null,
	now: number,
	loading = false
): SaveIndicator {
	const last = lastSavedAt === null ? '' : timeSince(lastSavedAt, now);
	if (loading) return { icon: 'saving', label: 'Loading your saved code…', time: '' };
	switch (state.kind) {
		case 'idle':
			return { icon: 'not-saved', label: 'Not saved yet', time: '' };
		case 'saving':
			return { icon: 'saving', label: 'Saving…', time: last };
		case 'saved': {
			const time = timeSince(state.at, now);
			return { icon: 'saved', label: `Saved ${time}`, time };
		}
		case 'error':
			return {
				icon: 'error',
				label: state.retrying ? `${state.message} Retrying…` : state.message,
				time: last ? `last saved ${last}` : 'not saved'
			};
	}
}

// saves a level's code with the progress API (PUT /api/levels/:levelId/progress)
export async function saveLevelCode(
	levelId: string,
	code: string,
	savedAt: number,
	{ keepalive = false } = {},
	fetchFn: typeof fetch = fetch
): Promise<void> {
	let response: Response;
	try {
		response = await fetchFn(`/api/levels/${encodeURIComponent(levelId)}/progress`, {
			method: 'PUT',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify({ code, savedAt }),
			// lets the request finish after the tab closes
			// browsers cap keepalive bodies at 64 KiB
			keepalive: keepalive && code.length < 60_000
		});
	} catch {
		throw new SaveError('Could not reach the server.', true);
	}

	// 409: a newer save already exists, so this code is already superseded
	if (response.ok || response.status === 409) return;
	if (response.status === 401) throw new SaveError('Sign in again to save your work.', false);
	if (response.status === 404) throw new SaveError('This level no longer exists.', false);
	if (response.status === 413) throw new SaveError('Your code is too long to save.', false);
	if (response.status === 400) throw new SaveError('Could not save this code.', false);
	throw new SaveError('Could not save.', true);
}
