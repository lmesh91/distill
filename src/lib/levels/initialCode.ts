import type { Level } from '$lib/types/level';
import type { UserLevelProgress } from '$lib/types/progress';

/**
 * picks the Lean code to show in the editor when a user opens a level.
 *
 * a level counts as untouched if the user has no progress record for it yet or the
 * record still says `not_started`. Untouched levels start with the level's starter code
 * otherwise we show the user's saved code even if it is empty
 */
export function getInitialCode(
	level: Pick<Level, 'starterCode'>,
	progress?: Pick<UserLevelProgress, 'status' | 'currentCode'> | null
): string {
	if (!progress || progress.status === 'not_started') {
		return level.starterCode;
	}

	return progress.currentCode;
}
