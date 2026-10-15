import { error, json } from '@sveltejs/kit';
import { verifyWebhook, type WebhookEvent } from '@clerk/backend/webhooks';
import { env } from '$env/dynamic/private';
import { getUsers } from '$lib/server/collections';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	if (!env.CLERK_WEBHOOK_SIGNING_SECRET) {
		throw new Error('CLERK_WEBHOOK_SIGNING_SECRET is not set');
	}

	let event: WebhookEvent;
	try {
		event = await verifyWebhook(request, { signingSecret: env.CLERK_WEBHOOK_SIGNING_SECRET });
	} catch {
		error(400, 'Invalid webhook signature');
	}

	const users = getUsers();
	const now = new Date();

	switch (event.type) {
		case 'user.created':
		case 'user.updated': {
			const user = event.data;
			const email =
				user.email_addresses.find((address) => address.id === user.primary_email_address_id)
					?.email_address ?? '';
			const displayName =
				[user.first_name, user.last_name].filter(Boolean).join(' ') || user.username || undefined;

			// Upsert so Clerk's retries and out-of-order deliveries are safe.
			await users.updateOne(
				{ _id: user.id },
				{
					$set: { email, displayName, updatedAt: now },
					$setOnInsert: { createdAt: now, lastLoginAt: now, totalXP: 0 },
					$unset: { deactivatedAt: '' }
				},
				{ upsert: true }
			);
			break;
		}
		case 'user.deleted': {
			if (event.data.id) {
				await users.updateOne(
					{ _id: event.data.id },
					{ $set: { deactivatedAt: now, updatedAt: now } }
				);
			}
			break;
		}
	}

	return json({ received: true });
};
