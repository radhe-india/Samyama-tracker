// Samyama Sadhana · sends reminders and timer bells as push notifications.
// Runs every 5 minutes (scheduled in migrate_v1.sql). Needs these secrets set in Supabase:
//   VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT (e.g. mailto:you@example.com)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
webpush.setVapidDetails(Deno.env.get("VAPID_SUBJECT")!, Deno.env.get("VAPID_PUBLIC")!, Deno.env.get("VAPID_PRIVATE")!);
const STEP = 5; // minutes between runs

type Msg = { title: string; body: string; tag: string };

async function sendTo(userId: string, msg: Msg) {
  const { data: subs } = await sb.from("push_subs").select("endpoint,sub").eq("user_id", userId);
  for (const s of subs ?? []) {
    try { await webpush.sendNotification(s.sub, JSON.stringify(msg), { TTL: 600 }); }
    catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) await sb.from("push_subs").delete().eq("endpoint", s.endpoint);
      else console.error("push failed", code, (e as Error).message);
    }
  }
}

// minutes since midnight in the person's own time zone
function localMinutes(tz: string): number {
  const p = new Intl.DateTimeFormat("en-GB", { timeZone: tz || "Asia/Kolkata", hour: "2-digit", minute: "2-digit", hour12: false }).formatToParts(new Date());
  const h = +(p.find((x) => x.type === "hour")?.value ?? 0) % 24, m = +(p.find((x) => x.type === "minute")?.value ?? 0);
  return h * 60 + m;
}
const dueNow = (now: number, at: number) => now >= at && now < at + STEP;

Deno.serve(async () => {
  let sent = 0;
  // 1. timer bells that are due
  const { data: jobs } = await sb.from("push_jobs").select("id,user_id,title,body,tag").lte("at", new Date().toISOString());
  for (const j of jobs ?? []) {
    await sendTo(j.user_id, { title: j.title, body: j.body, tag: j.tag });
    await sb.from("push_jobs").delete().eq("id", j.id);
    sent++;
  }
  // 2. recurring reminders, for people with at least one phone subscribed
  const { data: subUsers } = await sb.from("push_subs").select("user_id");
  const ids = [...new Set((subUsers ?? []).map((r) => r.user_id))];
  if (ids.length) {
    const { data: people } = await sb.from("profiles").select("id,sadhana").in("id", ids);
    for (const p of people ?? []) {
      const rem = p.sadhana?.rem;
      if (!rem) continue;
      const now = localMinutes(rem.tz);
      const a = rem.ardha;
      if (a?.on && now >= a.from && now <= a.to + STEP - 1) {
        const since = now - a.from;
        if (since % a.every < STEP) { await sendTo(p.id, { title: "Ardha Siddhasana", body: "Time to sit in Ardha Siddhasana.", tag: "ardha" }); sent++; }
      }
      const sc = rem.screen;
      if (sc?.on && p.sadhana?.add?.screen && dueNow(now, sc.at)) {
        await sendTo(p.id, { title: "Screen time", body: "Copy today's screen time into the app.", tag: "screen" }); sent++;
      }
    }
  }
  return new Response(JSON.stringify({ sent }), { headers: { "content-type": "application/json" } });
});
