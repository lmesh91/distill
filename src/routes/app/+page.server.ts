import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = ({ locals, url }) => {
  const { userId } = locals.auth();

  if (!userId) {
    // Clerk reads `redirect_url` and sends the user back here after they sign in.
    redirect(307, `/sign-in?redirect_url=${encodeURIComponent(url.href)}`);
  }

  return {
    userId
  };
};