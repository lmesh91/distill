import type { Collection } from "mongodb";
import { getDatabase } from "./db";
import type { Level } from "$lib/types/level";

export function getLevels(): Collection<Level> {
	return getDatabase().collection<Level>("levels");
}