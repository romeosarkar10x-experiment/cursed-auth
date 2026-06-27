import { chromium } from "playwright";
import { writeFileSync } from "node:fs";

const browser = await chromium.launch({
    headless: false,
});

const context = await browser.newContext();

const page = await context.newPage();
await page.goto("https://leetcode.com/accounts/login/");

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
