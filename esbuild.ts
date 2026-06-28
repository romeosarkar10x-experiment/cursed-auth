import esbuild from "esbuild";
import { glob } from "glob";

esbuild.build({
    outdir: "dist",
    entryPoints: await glob("src/**/*.ts"),
    bundle: false,
    format: "esm",
    platform: "node",
    packages: "external",
});
