export interface User {
    _id: string; // clerk user id
    email: string;
    displayName?: string;
    createdAt: Date;
    updatedAt: Date;
    lastLoginAt: Date;
    totalXP: number;
    lastLevelSlug?: string;
    deactivatedAt?: Date;
    // settings: UserSettings; TODO: Implement this later
}

// TODO: Implement this later
// export interface UserSettings {
//     theme: "light" | "dark";
//     notifications: boolean;
//     sound: boolean;
// }