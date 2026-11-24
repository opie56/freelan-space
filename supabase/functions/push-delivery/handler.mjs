const messages = {
  app_update: ['App update available', 'Open Freelan Space to download and install the latest version.'],
  approved: ['Submission approved', 'Open Freelan Space to see your update.'],
  rejected: ['Submission reviewed', 'Open Freelan Space to see your update.'],
  coins_received: ['Coins received', 'Open Freelan Space to see your update.'],
  saved_task_unavailable: ['Saved task unavailable', 'Open Freelan Space to find another task.'],
  login_alert: ['New sign-in', 'A new sign-in to your Freelan Space account was recorded.'],
  preferred_task: ['New preferred task', 'Open Freelan Space to see a task in your selected category.'],
  saved_task_reminder: ['Saved task reminder', 'Open Freelan Space to see your saved task.'],
  campaign_progress_50: ['Campaign halfway', 'Your campaign reached 50%.'],
  campaign_progress_100: ['Campaign completed', 'Your campaign reached 100%.'],
  low_balance: ['Low coin balance', 'Open Freelan Space to check your wallet.'],
  review_reminder: ['Submissions await review', 'Open Freelan Space to review your pending submissions.'],
  support_reply: ['Support replied', 'Open Freelan Space to see your update.'],
};
function equalSecret(a, b) {
  const x = new TextEncoder().encode(a), y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
export function createHandler({secret, workerSecret, claim, send, finish, continueDelivery}) {
  return async request => {
    if (request.method !== 'POST') return new Response('Method not allowed', {status: 405});
    const auth = request.headers.get('authorization') ?? '';
    const workerAuth = request.headers.get('x-push-worker-secret') ?? '';
    const validServiceKey = secret && equalSecret(auth, `Bearer ${secret}`);
    const validWorkerKey = workerSecret && equalSecret(workerAuth, workerSecret);
    if (!validServiceKey && !validWorkerKey) return new Response('Unauthorized', {status: 401});
    try {
      const jobs = await claim();
      const results = await Promise.all(jobs.map(async job => {
        let outcome = {success: false, permanent: false};
        try {
          const [title, body] = job.kind === 'admin_message' && typeof job.title === 'string' && typeof job.body === 'string'
            ? [job.title, job.body]
            : job.kind === 'coins_received' && Number.isInteger(job.amount) && job.amount > 0
              ? ['Coins received', `${job.amount} coins credited to your Freelan Space wallet${({referral: ' as a referral bonus', welcome: ' as a welcome bonus', transfer_received: ' from a wallet transfer', admin_adjustment: ' by an administrator', purchase: ' from your purchase', refund: ' as a refund', task: ' for your task', daily_bonus: ' as a daily check-in bonus', badge_bonus: ' for a milestone', weekly_challenge: ' for a weekly challenge'})[job.source] ?? ''}.`]
              : messages[job.kind] ?? ['Freelan Space', 'Open Freelan Space to see your update.'];
          outcome = await send(job.token, title, body, job.kind);
        } catch (_) { /* Leased jobs are retried on transient errors. */ }
        try { await finish(job.job_id, job.lease_id, outcome.success, outcome.permanent); return outcome.success ? 'sent' : 'retry'; }
        catch (_) { return 'unconfirmed'; }
      }));
      if (jobs.length >= 100 && continueDelivery) {
        try { continueDelivery(); } catch (_) { /* Cron remains a fallback. */ }
      }
      return Response.json({processed: results.length, sent: results.filter(x => x === 'sent').length, unconfirmed: results.filter(x => x === 'unconfirmed').length});
    } catch (_) { return new Response('Push worker unavailable', {status: 503}); }
  };
}
