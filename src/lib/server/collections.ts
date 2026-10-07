import type { Collection } from "mongodb";
import { getDatabase } from "./db";
import type { Level } from "$lib/types/level";
import type { User } from "$lib/types/user";
import type { UserLevelProgress } from "$lib/types/progress";

export function getLevels(): Collection<Level> {
	return getDatabase().collection<Level>("levels");
}

export function getUsers(): Collection<User> {
	return getDatabase().collection<User>("users");
}

export function getUserLevelProgresses(): Collection<UserLevelProgress> {
	return getDatabase().collection<UserLevelProgress>("userLevelProgress");
}