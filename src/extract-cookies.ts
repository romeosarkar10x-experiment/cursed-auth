import Database from "better-sqlite3";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pbkdf2Sync, createDecipheriv, createHash } from "node:crypto";

// Preferences is a JSON file (not a SQLite DB), so read it directly. Note it
// does not actually contain a user_agent field, so this stays "unknown" unless
// Chrome writes one — capture the real UA elsewhere if cf_clearance needs it.
let userAgent = "unknown";
try {
    const parsed = JSON.parse(readFileSync("/tmp/chrome-profile/Default/Preferences", "utf-8"));
    userAgent = parsed?.user_agent?.chrome || "unknown";
} catch {
    /* Preferences missing or unparseable — keep "unknown". */
}

// On Linux, Chromium encrypts cookie values at rest. The plaintext `value`
// column is left empty and the real data lives in the `encrypted_value` BLOB.
// In a container with no OS keyring, Chromium uses the "basic" password store:
//   - prefix     : "v10"
//   - password   : "peanuts" (hardcoded)
//   - kdf        : PBKDF2-HMAC-SHA1, salt "saltysalt", 1 iteration, 16-byte key
//   - cipher     : AES-128-CBC, IV = 16 bytes of 0x20 (space)
// ("v11" would mean the key came from gnome-keyring/kwallet, which isn't
// available in CI, so we don't handle it here.)
const KEY = pbkdf2Sync("peanuts", "saltysalt", 1, 16, "sha1");
const IV = Buffer.alloc(16, " ");

function decrypt(encrypted: Buffer | null, hostKey: string): string {
    if (!encrypted || encrypted.length === 0) return "";

    const prefix = encrypted.subarray(0, 3).toString("latin1");
    if (prefix !== "v10" && prefix !== "v11") {
        // Not encrypted (older Chrome / other platforms) — value is plaintext.
        return encrypted.toString("utf-8");
    }

    const decipher = createDecipheriv("aes-128-cbc", KEY, IV);
    decipher.setAutoPadding(false);
    let decrypted = Buffer.concat([decipher.update(encrypted.subarray(3)), decipher.final()]);

    // Strip PKCS#7 padding.
    const pad = decrypted[decrypted.length - 1] ?? 0;
    if (pad > 0 && pad <= 16) {
        decrypted = decrypted.subarray(0, decrypted.length - pad);
    }

    // Chrome >= ~v130 prepends a 32-byte SHA-256 of the host_key to the plaintext.
    const domainHash = createHash("sha256").update(hostKey).digest();
    if (decrypted.length >= 32 && decrypted.subarray(0, 32).equals(domainHash)) {
        decrypted = decrypted.subarray(32);
    }

    return decrypted.toString("utf-8");
}

type CookieRow = { name: string; encrypted_value: Buffer | null; value: string; host_key: string };

// better-sqlite3 opens the live DB read-only fine while Chrome is running.
const cookiesDb = process.env.COOKIES_DB || "/tmp/chrome-profile/Default/Cookies";
const db = new Database(cookiesDb, { readonly: true });
const rows = db
    .prepare("SELECT name, encrypted_value, value, host_key FROM cookies WHERE host_key LIKE '%leetcode.com%'")
    .all() as CookieRow[];

const extract = (name: string) => {
    const row = rows.find(r => r.name === name);
    if (!row) return undefined;
    // Prefer the plaintext column if Chromium happened to store it unencrypted.
    return row.value || decrypt(row.encrypted_value, row.host_key);
};

const result = {
    LEETCODE_SESSION: extract("LEETCODE_SESSION"),
    csrftoken: extract("csrftoken"),
    cf_clearance: extract("cf_clearance"),
    userAgent,
};

// There is no /app in this image (WORKDIR is /home/x); default to the cwd.
const outPath = resolve(process.env.COOKIES_OUT || "cookies.json");
writeFileSync(outPath, JSON.stringify(result, null, 2));
console.log(`✅ Cookies saved to ${outPath}`);
console.log(JSON.stringify(result, null, 2));
