import esbuild from "esbuild";

esbuild.build({
    outdir: "dist",
    entryPoints: ["src/index.ts"],
    bundle: true,
    platform: "node",
    packages: "external",
});
