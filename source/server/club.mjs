// worker/club.ts
import { scrypt, timingSafeEqual } from "node:crypto";
import { Buffer } from "node:buffer";

// worker/email.ts
function emailReady(env) {
  return !!env.BREVO_API_KEY && !!env.EMAIL_FROM;
}
async function sendAccountEmail(env, to, link, purpose) {
  if (!emailReady(env)) throw new Error("Email is not configured");
  const subject = purpose === "verify" ? "\u041F\u043E\u0434\u0442\u0432\u0435\u0440\u0434\u0438\u0442\u0435 \u043F\u043E\u0447\u0442\u0443 \u2014 \u041A\u043B\u0443\u0431 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0435\u043D\u043D\u0438\u043A\u043E\u0432" : "\u0412\u043E\u0441\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0438\u0435 \u043F\u0430\u0440\u043E\u043B\u044F \u2014 \u041A\u043B\u0443\u0431 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0435\u043D\u043D\u0438\u043A\u043E\u0432";
  const textContent = purpose === "verify" ? `\u0412\u044B \u043F\u0440\u0438\u0432\u044F\u0437\u044B\u0432\u0430\u0435\u0442\u0435 \u044D\u0442\u0443 \u043F\u043E\u0447\u0442\u0443 \u043A \u0441\u0432\u043E\u0435\u043C\u0443 \u043F\u0440\u043E\u0444\u0438\u043B\u044E \u0432 \u041A\u043B\u0443\u0431\u0435 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0435\u043D\u043D\u0438\u043A\u043E\u0432.

\u041F\u043E\u0434\u0442\u0432\u0435\u0440\u0434\u0438\u0442\u0435 \u0430\u0434\u0440\u0435\u0441: ${link}

\u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u0435\u0439\u0441\u0442\u0432\u0443\u0435\u0442 30 \u043C\u0438\u043D\u0443\u0442 \u0438 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u0443\u0435\u0442\u0441\u044F \u043E\u0434\u0438\u043D \u0440\u0430\u0437. \u0415\u0441\u043B\u0438 \u0432\u044B \u043D\u0435 \u0437\u0430\u043F\u0440\u0430\u0448\u0438\u0432\u0430\u043B\u0438 \u043F\u0440\u0438\u0432\u044F\u0437\u043A\u0443, \u043D\u0438\u0447\u0435\u0433\u043E \u043D\u0435 \u043D\u0430\u0436\u0438\u043C\u0430\u0439\u0442\u0435.` : `\u0427\u0442\u043E\u0431\u044B \u0437\u0430\u0434\u0430\u0442\u044C \u043D\u043E\u0432\u044B\u0439 \u043F\u0430\u0440\u043E\u043B\u044C \u041A\u043B\u0443\u0431\u0430 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0435\u043D\u043D\u0438\u043A\u043E\u0432, \u043E\u0442\u043A\u0440\u043E\u0439\u0442\u0435 \u0441\u0441\u044B\u043B\u043A\u0443:

${link}

\u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u0435\u0439\u0441\u0442\u0432\u0443\u0435\u0442 30 \u043C\u0438\u043D\u0443\u0442 \u0438 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u0443\u0435\u0442\u0441\u044F \u043E\u0434\u0438\u043D \u0440\u0430\u0437. \u0415\u0441\u043B\u0438 \u0432\u044B \u043D\u0435 \u0437\u0430\u043F\u0440\u0430\u0448\u0438\u0432\u0430\u043B\u0438 \u0441\u0431\u0440\u043E\u0441 \u043F\u0430\u0440\u043E\u043B\u044F, \u043F\u0440\u043E\u0438\u0433\u043D\u043E\u0440\u0438\u0440\u0443\u0439\u0442\u0435 \u043F\u0438\u0441\u044C\u043C\u043E \u2014 \u043F\u0430\u0440\u043E\u043B\u044C \u043E\u0441\u0442\u0430\u043D\u0435\u0442\u0441\u044F \u043F\u0440\u0435\u0436\u043D\u0438\u043C.`;
  const response = await fetch("https://api.brevo.com/v3/smtp/email", { method: "POST", headers: { "api-key": env.BREVO_API_KEY, "Content-Type": "application/json" }, body: JSON.stringify({ sender: { name: "\u041A\u043B\u0443\u0431 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0435\u043D\u043D\u0438\u043A\u043E\u0432", email: env.EMAIL_FROM }, to: [{ email: to }], subject, textContent }), signal: AbortSignal.timeout(15e3) });
  if (!response.ok) throw new Error("Email provider rejected the request");
}

// worker/club.ts
var now = () => Math.floor(Date.now() / 1e3);
var token = () => crypto.randomUUID().replaceAll("-", "") + crypto.randomUUID().replaceAll("-", "");
var hash = async (s) => Buffer.from(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))).toString("hex");
function fail(status, message) {
  throw new Response(JSON.stringify({ error: message }), { status, headers: { "Content-Type": "application/json" } });
}
function json(data2, status = 200, headers = {}) {
  return new Response(JSON.stringify(data2), { status, headers: { "Content-Type": "application/json", ...headers } });
}
function derive(password, salt) {
  return new Promise((resolve, reject) => scrypt(password, salt, 32, { N: 16384, r: 8, p: 5, maxmem: 64 * 1024 * 1024 }, (e, key) => e ? reject(e) : resolve(key)));
}
async function makePassword(password) {
  const salt = token();
  return `scrypt$16384$8$5$${salt}$${(await derive(password, salt)).toString("hex")}`;
}
async function verify(password, stored) {
  const parts = stored.split("$");
  const actual = await derive(password, parts[4]);
  return timingSafeEqual(actual, Buffer.from(parts[5], "hex"));
}
var cookie = (value, age = 2592e3) => `__Host-club=${value}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${age}`;
async function rate(env, key, limit, seconds) {
  const bucket = Math.floor(now() / seconds);
  const k = await hash(key + ":" + bucket);
  const r = await env.DB.prepare("INSERT INTO rate_limits(key,count,expires) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1 RETURNING count").bind(k, (bucket + 1) * seconds).first();
  if (!r || r.count > limit) fail(429, "\u0421\u043B\u0438\u0448\u043A\u043E\u043C \u043C\u043D\u043E\u0433\u043E \u043F\u043E\u043F\u044B\u0442\u043E\u043A. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u043F\u043E\u0437\u0436\u0435.");
}
async function limitedBody(req, max) {
  const reader = req.body?.getReader();
  if (!reader) return new Uint8Array();
  const parts = [];
  let size = 0;
  for (; ; ) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > max) {
      await reader.cancel();
      fail(413, "\u0421\u043B\u0438\u0448\u043A\u043E\u043C \u0431\u043E\u043B\u044C\u0448\u043E\u0439 \u0437\u0430\u043F\u0440\u043E\u0441.");
    }
    parts.push(value);
  }
  const result = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.length;
  }
  return result;
}
async function data(req) {
  if (!req.headers.get("content-type")?.startsWith("application/json")) fail(415, "\u041D\u0443\u0436\u0435\u043D JSON.");
  const s = new TextDecoder().decode(await limitedBody(req, 16e4));
  if (s.length > 4e4) fail(413, "\u0421\u043B\u0438\u0448\u043A\u043E\u043C \u0431\u043E\u043B\u044C\u0448\u043E\u0439 \u0437\u0430\u043F\u0440\u043E\u0441.");
  try {
    return JSON.parse(s);
  } catch {
    fail(400, "\u041D\u0435\u043A\u043E\u0440\u0440\u0435\u043A\u0442\u043D\u044B\u0439 \u0437\u0430\u043F\u0440\u043E\u0441.");
  }
}
function str(v, max, min = 1) {
  if (typeof v !== "string" || v.trim().length < min || v.length > max) fail(400, "\u041F\u0440\u043E\u0432\u0435\u0440\u044C\u0442\u0435 \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D\u0438\u0435 \u043F\u043E\u043B\u0435\u0439.");
  return v.trim();
}
async function user(req, env) {
  const raw = req.headers.get("cookie")?.match(/(?:^|;\s*)__Host-club=([a-f0-9]{64})(?:;|$)/)?.[1];
  if (!raw) return null;
  return env.DB.prepare("SELECT m.id,m.username,m.name FROM sessions s JOIN members m ON m.id=s.user_id WHERE s.hash=? AND s.expires>? AND m.active=1").bind(await hash(raw), now()).first();
}
async function session(env, id, expectedPassword) {
  const raw = token();
  const result = await env.DB.prepare("INSERT INTO sessions(hash,user_id,expires) SELECT ?,id,? FROM members WHERE id=? AND password=? AND active=1").bind(await hash(raw), now() + 2592e3, id, expectedPassword).run();
  if (!result.meta.changes) fail(401, "\u041F\u0430\u0440\u043E\u043B\u044C \u0438\u0437\u043C\u0435\u043D\u0438\u043B\u0441\u044F. \u0412\u043E\u0439\u0434\u0438\u0442\u0435 \u0441\u043D\u043E\u0432\u0430.");
  return cookie(raw);
}
function emailAddress(v) {
  const email = str(v, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || /[<>\r\n]/.test(email)) fail(400, "\u041F\u0440\u043E\u0432\u0435\u0440\u044C\u0442\u0435 \u0430\u0434\u0440\u0435\u0441 \u044D\u043B\u0435\u043A\u0442\u0440\u043E\u043D\u043D\u043E\u0439 \u043F\u043E\u0447\u0442\u044B.");
  return email;
}
var recoveryMessage = "\u0415\u0441\u043B\u0438 \u044D\u0442\u0430 \u043F\u043E\u0447\u0442\u0430 \u043F\u043E\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043D\u0430 \u0432 \u043A\u043B\u0443\u0431\u0435, \u043D\u0430 \u043D\u0435\u0451 \u043F\u0440\u0438\u0434\u0451\u0442 \u0441\u0441\u044B\u043B\u043A\u0430. \u041F\u0440\u043E\u0432\u0435\u0440\u044C\u0442\u0435 \u0442\u0430\u043A\u0436\u0435 \u043F\u0430\u043F\u043A\u0443 \xAB\u0421\u043F\u0430\u043C\xBB.";
async function accountMail(env, userId, email, purpose, expectedPassword = null) {
  if (!emailReady(env)) fail(503, "\u041E\u0442\u043F\u0440\u0430\u0432\u043A\u0430 \u043F\u0438\u0441\u0435\u043C \u0435\u0449\u0451 \u043D\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0430. \u0412\u0445\u043E\u0434 \u043F\u043E \u043B\u043E\u0433\u0438\u043D\u0443 \u0438 \u043F\u0430\u0440\u043E\u043B\u044E \u0440\u0430\u0431\u043E\u0442\u0430\u0435\u0442.");
  await rate(env, "mail-total", 150, 86400);
  const raw = token(), digest = await hash(raw);
  const inserted = await env.DB.prepare("INSERT INTO email_tokens(hash,user_id,email,purpose,expires) SELECT ?,id,?,?,? FROM members WHERE id=? AND active=1 AND (? IS NULL OR password=?)").bind(digest, email, purpose, now() + 1800, userId, expectedPassword, expectedPassword).run();
  if (!inserted.meta.changes) fail(401, "\u041F\u0430\u0440\u043E\u043B\u044C \u0438\u0437\u043C\u0435\u043D\u0438\u043B\u0441\u044F. \u0412\u043E\u0439\u0434\u0438\u0442\u0435 \u0441\u043D\u043E\u0432\u0430.");
  try {
    await sendAccountEmail(env, email, (env.PUBLIC_ORIGIN || "https://travel-club.baraneo-family-club.workers.dev") + "/#" + (purpose === "verify" ? "verify-email" : "reset-password") + "=" + raw, purpose);
  } catch {
    await env.DB.prepare("DELETE FROM email_tokens WHERE hash=?").bind(digest).run();
    fail(503, "\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043E\u0442\u043F\u0440\u0430\u0432\u0438\u0442\u044C \u043F\u0438\u0441\u044C\u043C\u043E. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u043F\u043E\u0437\u0436\u0435.");
  }
}
async function route(req, env, ctx) {
  const url = new URL(req.url);
  const path = url.pathname;
  const post = req.method === "POST";
  if (!path.startsWith("/api/")) return env.ASSETS.fetch(req);
  if (!["GET", "POST"].includes(req.method)) fail(405, "\u041C\u0435\u0442\u043E\u0434 \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u0435\u043D.");
  if (post && req.headers.get("origin") !== url.origin) fail(403, "\u041E\u0431\u043D\u043E\u0432\u0438\u0442\u0435 \u0441\u0442\u0440\u0430\u043D\u0438\u0446\u0443 \u0438 \u043F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u0441\u043D\u043E\u0432\u0430.");
  const ip = req.headers.get("CF-Connecting-IP") || "local";
  if (path === "/api/recovery/status" && !post) return json({ enabled: emailReady(env) });
  if (path === "/api/password/request" && post) {
    if (!emailReady(env)) fail(503, "\u041E\u0442\u043F\u0440\u0430\u0432\u043A\u0430 \u043F\u0438\u0441\u0435\u043C \u0435\u0449\u0451 \u043D\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0430.");
    await rate(env, "recover-ip:" + ip, 8, 3600);
    const b = await data(req), email = emailAddress(b.email);
    await rate(env, "recover-email:" + email, 3, 3600);
    const owner = await env.DB.prepare("SELECT id FROM members WHERE verified_email=? AND active=1").bind(email).first();
    if (owner) ctx.waitUntil(accountMail(env, owner.id, email, "reset").catch(() => {
    }));
    return json({ message: recoveryMessage });
  }
  if (path === "/api/password/reset" && post) {
    await rate(env, "reset-ip:" + ip, 10, 900);
    const b = await data(req), digest = await hash(str(b.token, 64, 64));
    const password = typeof b.password === "string" ? b.password : "";
    if (password.length < 12 || password.length > 128) fail(400, "\u041F\u0430\u0440\u043E\u043B\u044C: \u043E\u0442 12 \u0434\u043E 128 \u0441\u0438\u043C\u0432\u043E\u043B\u043E\u0432.");
    const valid = await env.DB.prepare("SELECT t.user_id,t.email FROM email_tokens t JOIN members m ON m.id=t.user_id WHERE t.hash=? AND t.purpose='reset' AND t.used_at IS NULL AND t.expires>? AND m.verified_email=t.email AND m.active=1").bind(digest, now()).first();
    if (!valid) fail(400, "\u0421\u0441\u044B\u043B\u043A\u0430 \u043D\u0435\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0442\u0435\u043B\u044C\u043D\u0430 \u0438\u043B\u0438 \u0438\u0441\u0442\u0435\u043A\u043B\u0430. \u0417\u0430\u043F\u0440\u043E\u0441\u0438\u0442\u0435 \u043D\u043E\u0432\u0443\u044E.");
    const passwordHash = await makePassword(password);
    const result = await env.DB.prepare("UPDATE members SET password=? WHERE id=? AND active=1 AND verified_email=? AND EXISTS(SELECT 1 FROM email_tokens WHERE hash=? AND purpose='reset' AND used_at IS NULL AND expires>?)").bind(passwordHash, valid.user_id, valid.email, digest, now()).run();
    if (!result.meta.changes) fail(400, "\u0421\u0441\u044B\u043B\u043A\u0430 \u0443\u0436\u0435 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u043D\u0430 \u0438\u043B\u0438 \u0438\u0441\u0442\u0435\u043A\u043B\u0430.");
    return json({ message: "\u041F\u0430\u0440\u043E\u043B\u044C \u043E\u0431\u043D\u043E\u0432\u043B\u0451\u043D. \u0412\u043E\u0439\u0434\u0438\u0442\u0435 \u0441 \u043D\u043E\u0432\u044B\u043C \u043F\u0430\u0440\u043E\u043B\u0435\u043C." }, 200, { "Set-Cookie": cookie("", 0) });
  }
  if (path === "/api/email/confirm" && post) {
    await rate(env, "confirm-ip:" + ip, 20, 900);
    const b = await data(req), digest = await hash(str(b.token, 64, 64));
    const valid = await env.DB.prepare("SELECT user_id,email FROM email_tokens WHERE hash=? AND purpose='verify' AND used_at IS NULL AND expires>?").bind(digest, now()).first();
    if (!valid) fail(400, "\u0421\u0441\u044B\u043B\u043A\u0430 \u043D\u0435\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0442\u0435\u043B\u044C\u043D\u0430 \u0438\u043B\u0438 \u0438\u0441\u0442\u0435\u043A\u043B\u0430.");
    try {
      const result = await env.DB.prepare("UPDATE members SET verified_email=? WHERE id=? AND active=1 AND EXISTS(SELECT 1 FROM email_tokens WHERE hash=? AND purpose='verify' AND used_at IS NULL AND expires>?)").bind(valid.email, valid.user_id, digest, now()).run();
      if (!result.meta.changes) fail(400, "\u0421\u0441\u044B\u043B\u043A\u0430 \u0443\u0436\u0435 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u043D\u0430 \u0438\u043B\u0438 \u0438\u0441\u0442\u0435\u043A\u043B\u0430.");
    } catch (e) {
      if (e instanceof Response) throw e;
      if (String(e).includes("UNIQUE")) fail(409, "\u042D\u0442\u043E\u0442 email \u0443\u0436\u0435 \u043F\u0440\u0438\u0432\u044F\u0437\u0430\u043D \u043A \u0434\u0440\u0443\u0433\u043E\u043C\u0443 \u0443\u0447\u0430\u0441\u0442\u043D\u0438\u043A\u0443.");
      throw e;
    }
    return json({ message: "\u041F\u043E\u0447\u0442\u0430 \u043F\u043E\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043D\u0430. \u0422\u0435\u043F\u0435\u0440\u044C \u043F\u043E \u043D\u0435\u0439 \u043C\u043E\u0436\u043D\u043E \u0432\u043E\u0441\u0441\u0442\u0430\u043D\u043E\u0432\u0438\u0442\u044C \u043F\u0430\u0440\u043E\u043B\u044C." });
  }
  if (post && (path === "/api/login" || path === "/api/register")) {
    await rate(env, "auth:" + ip, 20, 900);
    const b = await data(req);
    const username = str(b.username, 32, 3).toLowerCase();
    if (!/^[a-z0-9_]{3,32}$/.test(username)) fail(400, "\u041B\u043E\u0433\u0438\u043D: 3\u201332 \u043B\u0430\u0442\u0438\u043D\u0441\u043A\u0438\u0435 \u0431\u0443\u043A\u0432\u044B, \u0446\u0438\u0444\u0440\u044B \u0438\u043B\u0438 \u0437\u043D\u0430\u043A _.");
    const password = typeof b.password === "string" ? b.password : "";
    if (password.length < 12 || password.length > 128) fail(400, "\u041F\u0430\u0440\u043E\u043B\u044C: \u043E\u0442 12 \u0434\u043E 128 \u0441\u0438\u043C\u0432\u043E\u043B\u043E\u0432.");
    await rate(env, "username:" + username, 15, 900);
    if (path === "/api/register") {
      const invite = str(b.invite, 64, 64);
      const ih = await hash(invite);
      const valid = await env.DB.prepare("SELECT hash FROM invitations WHERE hash=? AND used_by IS NULL AND expires>?").bind(ih, now()).first();
      if (!valid) fail(403, "\u041F\u0440\u0438\u0433\u043B\u0430\u0448\u0435\u043D\u0438\u0435 \u0438\u0441\u0442\u0435\u043A\u043B\u043E \u0438\u043B\u0438 \u0443\u0436\u0435 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u043D\u043E.");
      const id = crypto.randomUUID(), name = str(b.name, 80);
      const passwordHash = await makePassword(password);
      try {
        await env.DB.prepare("INSERT INTO members(id,username,name,password,invite_hash,created_at) VALUES(?,?,?,?,?,?)").bind(id, username, name, passwordHash, ih, now()).run();
      } catch (e) {
        if (String(e).includes("members.username")) fail(409, "\u042D\u0442\u043E\u0442 \u043B\u043E\u0433\u0438\u043D \u0443\u0436\u0435 \u0437\u0430\u043D\u044F\u0442.");
        if (/invitation|invite_hash/.test(String(e))) fail(403, "\u041F\u0440\u0438\u0433\u043B\u0430\u0448\u0435\u043D\u0438\u0435 \u0438\u0441\u0442\u0435\u043A\u043B\u043E \u0438\u043B\u0438 \u0443\u0436\u0435 \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u043D\u043E.");
        throw e;
      }
      return json({ user: { id, username, name } }, 201, { "Set-Cookie": await session(env, id, passwordHash) });
    }
    const m2 = await env.DB.prepare("SELECT id,username,name,password FROM members WHERE username=? AND active=1").bind(username).first();
    const fallback = "scrypt$16384$8$5$0000000000000000000000000000000000000000000000000000000000000000$" + "00".repeat(32);
    if (!await verify(password, m2?.password || fallback) || !m2) fail(401, "\u041F\u0440\u043E\u0432\u0435\u0440\u044C\u0442\u0435 \u043B\u043E\u0433\u0438\u043D \u0438 \u043F\u0430\u0440\u043E\u043B\u044C.");
    return json({ user: { id: m2.id, username: m2.username, name: m2.name } }, 200, { "Set-Cookie": await session(env, m2.id, m2.password) });
  }
  const m = await user(req, env);
  if (path === "/api/me" && !post) return json({ user: m });
  if (!m) fail(401, "\u0412\u043E\u0439\u0434\u0438\u0442\u0435 \u0432 \u043A\u043B\u0443\u0431.");
  if (post) await rate(env, "write:" + m.id, 120, 3600);
  if (path === "/api/account/email" && !post) {
    const row = await env.DB.prepare("SELECT verified_email FROM members WHERE id=?").bind(m.id).first();
    return json({ email: row?.verified_email || null, enabled: emailReady(env) });
  }
  if (path === "/api/account/email" && post) {
    if (!emailReady(env)) fail(503, "\u041E\u0442\u043F\u0440\u0430\u0432\u043A\u0430 \u043F\u0438\u0441\u0435\u043C \u0435\u0449\u0451 \u043D\u0435 \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0430.");
    await rate(env, "email-link:" + m.id, 5, 3600);
    const b = await data(req), email = emailAddress(b.email);
    const password = typeof b.password === "string" ? b.password : "";
    if (password.length < 12 || password.length > 128) fail(400, "\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0442\u0435\u043A\u0443\u0449\u0438\u0439 \u043F\u0430\u0440\u043E\u043B\u044C.");
    const row = await env.DB.prepare("SELECT password FROM members WHERE id=? AND active=1").bind(m.id).first();
    if (!row || !await verify(password, row.password)) fail(403, "\u041D\u0435\u0432\u0435\u0440\u043D\u044B\u0439 \u0442\u0435\u043A\u0443\u0449\u0438\u0439 \u043F\u0430\u0440\u043E\u043B\u044C.");
    await accountMail(env, m.id, email, "verify", row.password);
    return json({ message: "\u041F\u0438\u0441\u044C\u043C\u043E \u0434\u043B\u044F \u043F\u043E\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043D\u0438\u044F \u043E\u0442\u043F\u0440\u0430\u0432\u043B\u0435\u043D\u043E. \u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u0435\u0439\u0441\u0442\u0432\u0443\u0435\u0442 30 \u043C\u0438\u043D\u0443\u0442." });
  }
  if (path === "/api/logout" && post) {
    const raw = req.headers.get("cookie")?.match(/__Host-club=([a-f0-9]{64})/)?.[1];
    if (raw) await env.DB.prepare("DELETE FROM sessions WHERE hash=?").bind(await hash(raw)).run();
    return json({ ok: true }, 200, { "Set-Cookie": cookie("", 0) });
  }
  if (path === "/api/invites" && post) {
    await rate(env, "invite:" + m.id, 20, 86400);
    const raw = token();
    await env.DB.prepare("INSERT INTO invitations(hash,creator,expires) VALUES(?,?,?)").bind(await hash(raw), m.id, now() + 604800).run();
    return json({ token: raw }, 201);
  }
  if (path === "/api/trips" && !post) {
    const rows = await env.DB.prepare("SELECT t.*,m.name AS author FROM trips t JOIN members m ON m.id=t.author_id ORDER BY t.created_at DESC LIMIT 200").all();
    const photos = await env.DB.prepare("SELECT id,trip_id,caption FROM photos WHERE ready=1 ORDER BY position").all();
    return json({ trips: rows.results.map((t) => ({ ...t, photos: photos.results.filter((p) => p.trip_id === t.id).map((p) => "/api/photos/" + p.id), captions: Object.fromEntries(photos.results.filter((p) => p.trip_id === t.id).map((p) => ["/api/photos/" + p.id, p.caption])) })) });
  }
  if (path === "/api/trips" && post) {
    const b = await data(req), id = b.id ? str(b.id, 36, 36) : crypto.randomUUID();
    if (!/^[a-f0-9-]{36}$/.test(id)) fail(400, "\u041D\u0435\u043A\u043E\u0440\u0440\u0435\u043A\u0442\u043D\u044B\u0439 ID.");
    const previous = await env.DB.prepare("SELECT author_id FROM trips WHERE id=?").bind(id).first();
    if (previous) {
      if (previous.author_id !== m.id) fail(403, "\u041D\u0435\u0442 \u0434\u043E\u0441\u0442\u0443\u043F\u0430.");
      return json({ id });
    }
    await env.DB.prepare("INSERT INTO trips(id,author_id,title,place,body,created_at) VALUES(?,?,?,?,?,?)").bind(id, m.id, str(b.title, 140), str(b.place || "", 120, 0), str(b.body, 3e4), now()).run();
    return json({ id }, 201);
  }
  const routeDetails = path.match(/^\/api\/trips\/([a-f0-9-]{36})\/route$/);
  if (routeDetails) {
    const tid = routeDetails[1];
    const trip = await env.DB.prepare("SELECT author_id FROM trips WHERE id=?").bind(tid).first();
    if (!trip) fail(404, "\u041F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0438\u0435 \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D\u043E.");
    const current = await env.DB.prepare("SELECT content,version FROM trip_routes WHERE trip_id=?").bind(tid).first();
    if (!post) return json(current ? { ...JSON.parse(current.content), version: current.version } : { stops: [], transport: "", budget: "", packing: "", advice: "", version: 0 });
    if (trip.author_id !== m.id) fail(403, "\u041C\u0430\u0440\u0448\u0440\u0443\u0442 \u043C\u043E\u0436\u0435\u0442 \u0438\u0437\u043C\u0435\u043D\u044F\u0442\u044C \u0442\u043E\u043B\u044C\u043A\u043E \u0430\u0432\u0442\u043E\u0440.");
    const b = await data(req);
    if (!Number.isInteger(b.version) || b.version < 0) fail(400, "\u041E\u0431\u043D\u043E\u0432\u0438\u0442\u0435 \u043C\u0430\u0440\u0448\u0440\u0443\u0442.");
    if (!Array.isArray(b.stops) || b.stops.length > 30) fail(400, "\u0412 \u043C\u0430\u0440\u0448\u0440\u0443\u0442\u0435 \u043C\u043E\u0436\u0435\u0442 \u0431\u044B\u0442\u044C \u0434\u043E 30 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u043E\u043A.");
    const stops = b.stops.map((s) => {
      if (!s || typeof s !== "object") fail(400, "\u041F\u0440\u043E\u0432\u0435\u0440\u044C\u0442\u0435 \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u043A\u0438.");
      const lat = s.lat, lon = s.lon;
      if ((lat !== null || lon !== null) && (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -85 || lat > 85 || lon < -180 || lon > 180)) fail(400, "\u0423\u043A\u0430\u0436\u0438\u0442\u0435 \u043E\u0431\u0435 \u043A\u043E\u043E\u0440\u0434\u0438\u043D\u0430\u0442\u044B: \u0448\u0438\u0440\u043E\u0442\u0443 \u043E\u0442 \u221285 \u0434\u043E 85 \u0438 \u0434\u043E\u043B\u0433\u043E\u0442\u0443 \u043E\u0442 \u2212180 \u0434\u043E 180.");
      return { title: str(s.title, 120), note: str(s.note, 600, 0), lat, lon };
    });
    const content = JSON.stringify({ stops, transport: str(b.transport, 2e3, 0), budget: str(b.budget, 2e3, 0), packing: str(b.packing, 2e3, 0), advice: str(b.advice, 2e3, 0) });
    const changed = await env.DB.prepare("INSERT INTO trip_routes(trip_id,content,version) SELECT ?,?,1 WHERE ?=0 ON CONFLICT(trip_id) DO UPDATE SET content=excluded.content,version=trip_routes.version+1 WHERE trip_routes.version=?").bind(tid, content, b.version, b.version).run();
    if (!changed.meta.changes && b.version > 0) {
      const updated = await env.DB.prepare("UPDATE trip_routes SET content=?,version=version+1 WHERE trip_id=? AND version=?").bind(content, tid, b.version).run();
      if (!updated.meta.changes) fail(409, "\u041C\u0430\u0440\u0448\u0440\u0443\u0442 \u0443\u0436\u0435 \u0438\u0437\u043C\u0435\u043D\u0451\u043D. \u0421\u043A\u043E\u043F\u0438\u0440\u0443\u0439\u0442\u0435 \u0441\u0432\u043E\u0438 \u0434\u043E\u043F\u043E\u043B\u043D\u0435\u043D\u0438\u044F \u0438 \u0437\u0430\u043D\u043E\u0432\u043E \u043E\u0442\u043A\u0440\u043E\u0439\u0442\u0435 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0438\u0435.");
    } else if (!changed.meta.changes) fail(409, "\u041C\u0430\u0440\u0448\u0440\u0443\u0442 \u0443\u0436\u0435 \u0438\u0437\u043C\u0435\u043D\u0451\u043D. \u0417\u0430\u043D\u043E\u0432\u043E \u043E\u0442\u043A\u0440\u043E\u0439\u0442\u0435 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0438\u0435.");
    return json({ ...JSON.parse(content), version: b.version + 1 });
  }
  const edit = path.match(/^\/api\/trips\/([a-f0-9-]{36})\/edit$/);
  if (edit && post) {
    const b = await data(req), id = edit[1];
    const existing = await env.DB.prepare("SELECT author_id,last_edit_id FROM trips WHERE id=?").bind(id).first();
    if (!existing) fail(404, "\u0420\u0430\u0441\u0441\u043A\u0430\u0437 \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D.");
    if (existing.author_id !== m.id) fail(403, "\u0420\u0435\u0434\u0430\u043A\u0442\u0438\u0440\u043E\u0432\u0430\u0442\u044C \u0440\u0430\u0441\u0441\u043A\u0430\u0437 \u043C\u043E\u0436\u0435\u0442 \u0442\u043E\u043B\u044C\u043A\u043E \u0430\u0432\u0442\u043E\u0440.");
    const mutation = str(b.mutation, 36, 36);
    if (existing.last_edit_id === mutation) return json({ id });
    if (!Number.isInteger(b.version)) fail(400, "\u041E\u0431\u043D\u043E\u0432\u0438\u0442\u0435 \u0441\u0442\u0440\u0430\u043D\u0438\u0446\u0443 \u043F\u0435\u0440\u0435\u0434 \u0440\u0435\u0434\u0430\u043A\u0442\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u0435\u043C.");
    const result = await env.DB.prepare("UPDATE trips SET title=?,place=?,body=?,version=version+1,last_edit_id=? WHERE id=? AND author_id=? AND version=?").bind(str(b.title, 140), str(b.place || "", 120, 0), str(b.body, 3e4), mutation, id, m.id, b.version).run();
    if (!result.meta.changes) fail(409, "\u0420\u0430\u0441\u0441\u043A\u0430\u0437 \u0443\u0436\u0435 \u0438\u0437\u043C\u0435\u043D\u0451\u043D \u0432 \u0434\u0440\u0443\u0433\u043E\u0439 \u0432\u043A\u043B\u0430\u0434\u043A\u0435. \u0421\u043A\u043E\u043F\u0438\u0440\u0443\u0439\u0442\u0435 \u0441\u0432\u043E\u0439 \u0442\u0435\u043A\u0441\u0442, \u043E\u0431\u043D\u043E\u0432\u0438\u0442\u0435 \u0441\u0442\u0440\u0430\u043D\u0438\u0446\u0443 \u0438 \u043F\u043E\u0432\u0442\u043E\u0440\u0438\u0442\u0435 \u0438\u0437\u043C\u0435\u043D\u0435\u043D\u0438\u0435.");
    return json({ id });
  }
  const photoDetails = path.match(/^\/api\/photos\/([a-f0-9-]{36})\/(details|caption|comments)$/);
  if (photoDetails) {
    const id = photoDetails[1], action = photoDetails[2];
    const photo2 = await env.DB.prepare("SELECT p.caption,t.author_id FROM photos p JOIN trips t ON t.id=p.trip_id WHERE p.id=? AND p.ready=1").bind(id).first();
    if (!photo2) fail(404, "\u0424\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u044F \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D\u0430.");
    if (action === "details" && !post) return json({ caption: photo2.caption, comments: (await env.DB.prepare("SELECT c.id,c.body,m.name AS author FROM photo_comments c JOIN members m ON m.id=c.author_id WHERE c.photo_id=? ORDER BY c.created_at,c.rowid").bind(id).all()).results });
    if (action === "caption" && post) {
      if (photo2.author_id !== m.id) fail(403, "\u041E\u043F\u0438\u0441\u0430\u043D\u0438\u0435 \u0444\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u0438 \u043C\u043E\u0436\u0435\u0442 \u0438\u0437\u043C\u0435\u043D\u0438\u0442\u044C \u0442\u043E\u043B\u044C\u043A\u043E \u0430\u0432\u0442\u043E\u0440 \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0438\u044F.");
      const b = await data(req), caption = str(b.caption, 2e3, 0);
      await env.DB.prepare("UPDATE photos SET caption=? WHERE id=?").bind(caption, id).run();
      return json({ caption });
    }
    if (action === "comments" && post) {
      const b = await data(req), body = str(b.body, 4e3), cid = crypto.randomUUID();
      await env.DB.prepare("INSERT INTO photo_comments(id,photo_id,author_id,body,created_at) VALUES(?,?,?,?,?)").bind(cid, id, m.id, body, now()).run();
      return json({ id: cid, body, author: m.name }, 201);
    }
    fail(405, "\u041C\u0435\u0442\u043E\u0434 \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u0435\u043D.");
  }
  const comments = path.match(/^\/api\/trips\/([a-f0-9-]{36})\/comments$/);
  if (comments) {
    const tid = comments[1];
    if (!await env.DB.prepare("SELECT id FROM trips WHERE id=?").bind(tid).first()) fail(404, "\u0420\u0430\u0441\u0441\u043A\u0430\u0437 \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D.");
    if (!post) return json({ comments: (await env.DB.prepare("SELECT c.id,c.body,m.name AS author FROM comments c JOIN members m ON m.id=c.author_id WHERE c.trip_id=? ORDER BY c.created_at,c.rowid").bind(tid).all()).results });
    const b = await data(req), body = str(b.body, 4e3), id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO comments(id,trip_id,author_id,body,created_at) VALUES(?,?,?,?,?)").bind(id, tid, m.id, body, now()).run();
    return json({ id, body, author: m.name }, 201);
  }
  const upload = path.match(/^\/api\/trips\/([a-f0-9-]{36})\/photos$/);
  if (upload && post) {
    const tid = upload[1];
    if (!await env.DB.prepare("SELECT id FROM trips WHERE id=? AND author_id=?").bind(tid, m.id).first()) fail(403, "\u0424\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u0438 \u043C\u043E\u0436\u0435\u0442 \u0434\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u0442\u043E\u043B\u044C\u043A\u043E \u0430\u0432\u0442\u043E\u0440.");
    await rate(env, "photos:" + m.id, 100, 86400);
    if (Number(req.headers.get("content-length")) > 1e6) fail(413, "\u0424\u043E\u0442\u043E \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u0431\u043E\u043B\u044C\u0448\u043E\u0435.");
    const bytes = await limitedBody(req, 1e6);
    if (bytes.byteLength > 1e6 || bytes.byteLength < 4) fail(413, "\u0424\u043E\u0442\u043E \u0434\u043E\u043B\u0436\u043D\u043E \u0431\u044B\u0442\u044C \u043C\u0435\u043D\u044C\u0448\u0435 1 \u041C\u0411.");
    const magic = bytes;
    if (magic[0] !== 255 || magic[1] !== 216 || magic[2] !== 255) fail(415, "\u041D\u0443\u0436\u043D\u0430 \u0444\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u044F JPEG.");
    const id = req.headers.get("X-Photo-Id") || crypto.randomUUID();
    if (!/^[a-f0-9-]{36}$/.test(id)) fail(400, "\u041D\u0435\u043A\u043E\u0440\u0440\u0435\u043A\u0442\u043D\u044B\u0439 ID.");
    const previous = await env.DB.prepare("SELECT trip_id,ready FROM photos WHERE id=?").bind(id).first();
    if (previous) {
      if (previous.trip_id !== tid) fail(403, "\u041D\u0435\u0442 \u0434\u043E\u0441\u0442\u0443\u043F\u0430.");
      if (previous.ready) return json({ id, url: "/api/photos/" + id });
      fail(409, "\u0424\u043E\u0442\u043E \u0435\u0449\u0451 \u0437\u0430\u0433\u0440\u0443\u0436\u0430\u0435\u0442\u0441\u044F. \u041F\u043E\u0432\u0442\u043E\u0440\u0438\u0442\u0435 \u0447\u0435\u0440\u0435\u0437 \u043C\u0438\u043D\u0443\u0442\u0443.");
    }
    let r;
    try {
      r = await env.DB.prepare("INSERT INTO photos(id,trip_id,size,position) SELECT ?,?,?,COUNT(*) FROM photos WHERE trip_id=? HAVING COUNT(*)<100").bind(id, tid, bytes.byteLength, tid).run();
    } catch (e) {
      if (String(e).includes("CHECK constraint")) fail(413, "\u0411\u0435\u0441\u043F\u043B\u0430\u0442\u043D\u043E\u0435 \u043C\u0435\u0441\u0442\u043E \u0434\u043B\u044F \u0444\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u0439 \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D\u043E.");
      throw e;
    }
    if (!r.meta.changes) fail(400, "\u0412 \u043E\u0434\u043D\u043E\u043C \u043F\u0443\u0442\u0435\u0448\u0435\u0441\u0442\u0432\u0438\u0438 \u043C\u043E\u0436\u043D\u043E \u0441\u043E\u0445\u0440\u0430\u043D\u0438\u0442\u044C \u0434\u043E 100 \u0444\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u0439.");
    try {
      await env.PHOTOS.put(id, bytes);
      await env.DB.prepare("UPDATE photos SET ready=1 WHERE id=?").bind(id).run();
    } catch (e) {
      await env.PHOTOS.delete(id).catch(() => {
      });
      await env.DB.prepare("DELETE FROM photos WHERE id=?").bind(id).run();
      throw e;
    }
    return json({ id, url: "/api/photos/" + id }, 201);
  }
  const photo = path.match(/^\/api\/photos\/([a-f0-9-]{36})$/);
  if (photo && !post) {
    if (!await env.DB.prepare("SELECT id FROM photos WHERE id=? AND ready=1").bind(photo[1]).first()) fail(404, "\u0424\u043E\u0442\u043E \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D\u043E.");
    const stream = await env.PHOTOS.get(photo[1], "stream");
    if (!stream) fail(503, "\u0424\u043E\u0442\u043E\u0433\u0440\u0430\u0444\u0438\u044F \u0435\u0449\u0451 \u0437\u0430\u0433\u0440\u0443\u0436\u0430\u0435\u0442\u0441\u044F. \u041E\u0431\u043D\u043E\u0432\u0438\u0442\u0435 \u0441\u0442\u0440\u0430\u043D\u0438\u0446\u0443 \u0447\u0435\u0440\u0435\u0437 \u043C\u0438\u043D\u0443\u0442\u0443.");
    return new Response(stream, { headers: { "Content-Type": "image/jpeg" } });
  }
  fail(404, "\u0421\u0442\u0440\u0430\u043D\u0438\u0446\u0430 \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D\u0430.");
}
var club_default = { async fetch(req, env, ctx) {
  try {
    const response = await route(req, env, ctx);
    const r = new Response(response.body, response);
    if (new URL(req.url).pathname.startsWith("/api/")) {
      r.headers.set("Cache-Control", "no-store");
      r.headers.set("Vary", "Cookie");
    }
    r.headers.set("X-Content-Type-Options", "nosniff");
    r.headers.set("Referrer-Policy", "no-referrer");
    r.headers.set("X-Frame-Options", "DENY");
    return r;
  } catch (e) {
    const r = e instanceof Response ? e : json({ error: "\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u0432\u044B\u043F\u043E\u043B\u043D\u0438\u0442\u044C \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u043F\u043E\u0437\u0436\u0435." }, 503);
    r.headers.set("Cache-Control", "no-store");
    return r;
  }
} };
export {
  club_default as default
};
