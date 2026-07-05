import Database from "better-sqlite3";
import { writeFileSync } from "node:fs";
import { execSync } from "node:child_process";

const ua = execSync(
    `sqlite3 /tmp/chrome-profile/Default/Preferences "SELECT * FROM preference" 2>/dev/null || cat /tmp/chrome-profile/Default/Preferences`,
).toString();

const parsed = JSON.parse(ua);
const userAgent = parsed?.user_agent?.chrome || "unknown";

const db = new Database("/tmp/chrome-profile/Default/Cookies", { readonly: true });
const rows = db.prepare("SELECT name, value FROM cookies WHERE host_key LIKE '%leetcode.com%'").all();

const extract = (name: string) => rows.find((r: { name: string }) => r.name === name)?.value;

const result = {
    LEETCODE_SESSION: extract("LEETCODE_SESSION"),
    csrftoken: extract("csrftoken"),
    cf_clearance: extract("cf_clearance"),
    userAgent,
};

writeFileSync("/app/cookies.json", JSON.stringify(result, null, 2));
console.log("✅ Cookies saved");
console.log(JSON.stringify(result, null, 2));
