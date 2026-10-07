import type { ObjectId } from "mongodb";

export type ProgressStatus = "not_started" | "in_progress" | "completed";

export interface UserLevelProgress {
    _id?: ObjectId;
    userId: string;
    levelId: ObjectId;
    status: ProgressStatus;
    currentCode: string;
    currentError?: string;
    numberShownHints?: number;
    attemptCount: number;
    lastAttemptedAt?: Date;
    startedAt?: Date;
    completedAt?: Date;
}