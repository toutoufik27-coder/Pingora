// Starts the production server for the end-to-end tests with an empty database
// and a file outbox for emails. Usage: node e2e/start-server.mjs <port>
import { spawn } from "node:child_process";
import { rmSync } from "node:fs";
import path from "node:path";

const port = process.argv[2] ?? "3100";
const root = path.resolve(import.meta.dirname, "..");
const workDir = path.join(root, ".e2e");
rmSync(workDir, { recursive: true, force: true });

const env = {
  ...process.env,
  PORT: port,
  APP_URL: `http://localhost:${port}`,
  PGLITE_DATA_DIR: path.join(workDir, "db"),
  EMAIL_OUTBOX_DIR: path.join(workDir, "outbox"),
};
// Tests run without an email provider or billing account, and on an embedded
// database unless E2E_DATABASE_URL points at a (disposable) Postgres database.
for (const key of ["DATABASE_URL", "RESEND_API_KEY", "LEMONSQUEEZY_API_KEY"]) delete env[key];
if (process.env.E2E_DATABASE_URL) env.DATABASE_URL = process.env.E2E_DATABASE_URL;

const nextBin = path.join(root, "node_modules", "next", "dist", "bin", "next");
const server = spawn(process.execPath, [nextBin, "start", "-p", port], { cwd: root, env, stdio: "inherit" });
for (const signal of ["SIGINT", "SIGTERM"]) process.on(signal, () => server.kill(signal));
server.on("exit", (code) => process.exit(code ?? 0));
