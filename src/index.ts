import { chromium } from "playwright";
import { writeFileSync } from "node:fs";

const browser = await chromium.launch({
    headless: false,
    args: ["--disable-blink-features=AutomationControlled", "--no-first-run", "--no-default-browser-check"],
});

const context = await browser.newContext({
    userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
});

const page = await context.newPage();

await page.addInitScript(() => {
    Object.defineProperty(navigator, "webdriver", { get: () => false });
    // patch chrome runtime
    window.chrome = { runtime: {} } as any;
    // patch permissions
    const originalQuery = window.navigator.permissions.query;
    window.navigator.permissions.query = (params: any) =>
        params.name === "notifications"
            ? Promise.resolve({ state: Notification.permission } as PermissionStatus)
            : originalQuery(params);
});

await page.goto("https://leetcode.com/accounts/login/");
// ... rest stays the same

console.log("⏳ Waiting for login...");
await page.waitForURL("**/problemset/**", { timeout: 600_000 });

const cookies = await context.cookies("https://leetcode.com");
const extract = (name: string) => cookies.find(c => c.name === name)?.value;

const result = {
    LEETCODE_SESSION: extract("LEETCODE_SESSION"),
    csrftoken: extract("csrftoken"),
    cf_clearance: extract("cf_clearance"),
    userAgent: await page.evaluate(() => navigator.userAgent),
};

writeFileSync("/app/cookies.json", JSON.stringify(result, null, 2));
console.log("✅ Cookies saved to /app/cookies.json");
console.log(JSON.stringify(result, null, 2));

await browser.close();
