// Creates Jotty's first admin from ADMIN_USERNAME / ADMIN_PASSWORD when no user exists yet.
// Same record shape and password hash (sha256 hex) as Jotty's own /auth/setup form.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const usersFile = path.join("/app/data/users/users.json");
let users = [];
try {
  const raw = fs.readFileSync(usersFile, "utf-8").trim();
  users = raw ? JSON.parse(raw) : [];
} catch (e) {
  if (e.code !== "ENOENT") {
    console.error(`[railway] cannot read ${usersFile}: ${e.message}`);
    process.exit(1);
  }
}
if (Array.isArray(users) && users.length > 0) {
  console.log(`[railway] ${users.length} user(s) found, admin bootstrap skipped`);
  process.exit(0);
}

const username = (process.env.ADMIN_USERNAME || "admin").trim();
const password = process.env.ADMIN_PASSWORD || "";
const sso = (process.env.AUTH_MODE || process.env.SSO_MODE || "").toLowerCase() === "oidc";
if (!password) {
  if (sso) {
    console.log("[railway] AUTH_MODE=oidc and no ADMIN_PASSWORD: the first SSO login becomes admin");
    process.exit(0);
  }
  console.error("[railway] ADMIN_PASSWORD is empty and no user exists. Set ADMIN_PASSWORD so the setup page is not left open.");
  process.exit(1);
}
if (password.length < 8) {
  console.error("[railway] ADMIN_PASSWORD must be at least 8 characters.");
  process.exit(1);
}
if (!/^[A-Za-z0-9._-]{1,64}$/.test(username)) {
  console.error("[railway] ADMIN_USERNAME may only use letters, digits, '.', '_' and '-'.");
  process.exit(1);
}

const now = new Date().toISOString();
const record = {
  uuid: crypto.randomUUID(),
  username,
  passwordHash: crypto.createHash("sha256").update(password).digest("hex"),
  isAdmin: true,
  isSuperAdmin: true,
  createdAt: now,
  preferredDateFormat: "system",
  preferredTimeFormat: "system",
};

fs.mkdirSync(path.dirname(usersFile), { recursive: true });
const tmp = `${usersFile}.${process.pid}.tmp`;
fs.writeFileSync(tmp, JSON.stringify([record], null, 2));
fs.renameSync(tmp, usersFile);
for (const [f, seed] of [["sessions.json", "{}"], ["session-data.json", "{}"]]) {
  const p = path.join(path.dirname(usersFile), f);
  if (!fs.existsSync(p)) fs.writeFileSync(p, seed);
}
for (const d of ["checklists", "notes"]) fs.mkdirSync(path.join("/app/data", d, username), { recursive: true });
console.log(`[railway] created admin user '${username}'`);
