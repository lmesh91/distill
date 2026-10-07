# Admin status storage (#36)

Javier Coll-Roman

## What I decided

Admin status is stored in Clerk, not MongoDB. If a user is an admin, their Clerk user has this in their public metadata:

```json
{ "role": "admin" }
```

Normal users just don't have a `role` at all.

We also copy the metadata into the session token, so our server code (pages and API routes) can check if someone is an admin by reading the token instead of calling Clerk or the database every time.

## Why I went with this

I looked at a few options. The main reasons I picked public metadata:

- Users can't edit it. Public metadata can only be changed from the Clerk dashboard or from our backend with the secret key. Clerk also has "unsafe metadata", but users can change that themselves, so it would let anyone make themselves an admin.
- Clerk already handles all of our user identity stuff, so it made sense to keep the role there too. If we also stored an `isAdmin` flag in MongoDB, we'd have to keep the two in sync, and it's easy for them to end up disagreeing.
- Checking the role is basically free since it's already in the session token.
- I used `role` instead of a true/false `isAdmin` so we can add other roles later (like a moderator for custom levels) without changing anything.

One downside: Clerk caches the session token for about a minute, so if you make someone an admin (or remove it), it won't kick in until their token refreshes. Signing out and back in fixes it right away. Since only a few of us will ever be admins, this shouldn't matter.

## Setting it up in Clerk

This only has to be done once, by someone with access to the Clerk dashboard.

1. Go to Sessions, then Customize session token, and add:

   ```json
   {
     "metadata": "{{user.public_metadata}}"
   }
   ```

2. To make someone an admin, go to Users, pick the user, open Metadata, and under Public put `{ "role": "admin" }`. They need to sign out and sign back in after.

## Using it in code

I added an `isAdmin()` helper in `src/lib/server/roles.ts`. It works the same way in page loads and in our API routes (`src/routes/api/...`):

```ts
import { isAdmin } from '$lib/server/roles';

const { sessionClaims } = locals.auth();
if (!isAdmin(sessionClaims)) error(403, 'Forbidden');
```

The type for the custom claim is in `src/app.d.ts`.

Important: always do the admin check on the server. Hiding the admin link in the navbar is just for looks and doesn't actually stop anyone. Actually locking down the admin pages and API routes is #37.
