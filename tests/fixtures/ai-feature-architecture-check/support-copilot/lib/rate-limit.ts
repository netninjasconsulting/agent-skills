// Test fixture.
import { db } from "./db";

// Ten AI requests a minute for each user.
export async function rateLimit(userId: string): Promise<boolean> {
  const { rows } = await db.query(
    `insert into rate_events (user_id) values ($1)
     returning (select count(*)::int from rate_events where user_id = $1 and at > now() - interval '1 minute') as recent`,
    [userId],
  );
  return rows[0].recent < 10;
}
