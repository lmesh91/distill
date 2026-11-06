import type { ObjectId } from 'mongodb';

export type LevelType = 'guided' | 'hints' | 'from-scratch';
import type { VerificationTarget } from './submission';

export interface Level {
    _id?: ObjectId; // TODO: Potentially create NewLevel interface instead, and require this id
    parentId?: ObjectId; // for tree structure -> if not present, it is a root level
    order: number; // for siblings
    slug: string; // for stable url
    title: string;
    description: string;
    type: LevelType;
    statement: string;
    starterCode: string;
    expectedGoal?: string;
    verification?: VerificationTarget;
    hints?: string[];
    published: boolean;
    createdAt: Date;
    updatedAt: Date;
}
