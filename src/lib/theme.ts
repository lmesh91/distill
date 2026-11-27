export type Theme = 'light' | 'dark';

const storageKey = 'distill-theme';

// the theme on screen right now: the saved choice, or the system setting
export function currentTheme(): Theme {
	const chosen = document.documentElement.dataset.theme;
	if (chosen === 'light' || chosen === 'dark') return chosen;
	return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

// shows the theme and remembers it for next time (src/app.html applies it on load)
export function setTheme(theme: Theme) {
	document.documentElement.dataset.theme = theme;
	try {
		localStorage.setItem(storageKey, theme);
	} catch {
		// storage can be blocked; the theme still applies until the page reloads
	}
}
