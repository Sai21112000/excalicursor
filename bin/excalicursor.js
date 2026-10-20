#!/usr/bin/env node

const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const rootDir = path.resolve(__dirname, "..");
const bundledApp = path.join(rootDir, "build", "ExcaliCursor.app");
const installedApp = "/Applications/ExcaliCursor.app";

function ensureAppBuilt() {
  if (!fs.existsSync(bundledApp)) {
    console.log("Building ExcaliCursor.app...");
    execSync("make app", { cwd: rootDir, stdio: "inherit" });
  }
}

function installToApplications() {
  ensureAppBuilt();
  try {
    execSync(`rm -rf "${installedApp}" && cp -R "${bundledApp}" "${installedApp}"`, {
      stdio: "inherit"
    });
    console.log(`Installed ExcaliCursor to ${installedApp}`);
    return installedApp;
  } catch {
    console.log(`Could not copy to /Applications automatically; using ${bundledApp}`);
    return bundledApp;
  }
}

const args = process.argv.slice(2);
const cmd = args[0] || "start";

if (cmd === "--postinstall") {
  try {
    ensureAppBuilt();
  } catch {
    // Ignore build errors on non-macOS or missing Xcode CLI environments
  }
  process.exit(0);
}

if (cmd === "install") {
  const target = installToApplications();
  execSync(`open "${target}"`);
  process.exit(0);
}

if (cmd === "dmg") {
  execSync("make dmg", { cwd: rootDir, stdio: "inherit" });
  process.exit(0);
}

if (cmd === "stop" || cmd === "kill") {
  try {
    execSync("killall ExcaliCursor", { stdio: "ignore" });
    console.log("Stopped ExcaliCursor.");
  } catch {
    console.log("ExcaliCursor is not running.");
  }
  process.exit(0);
}

if (cmd === "--help" || cmd === "-h" || cmd === "help") {
  console.log(`ExcaliCursor CLI

Usage:
  excalicursor            Launch ExcaliCursor.app
  excalicursor install    Install ExcaliCursor.app into /Applications and launch it
  excalicursor dmg        Build build/ExcaliCursor.dmg installer image
  excalicursor stop       Quit running ExcaliCursor instance
`);
  process.exit(0);
}

// Default: launch app
const appToOpen = fs.existsSync(installedApp)
  ? installedApp
  : (ensureAppBuilt(), bundledApp);

spawn("open", [appToOpen], { detached: true, stdio: "ignore" }).unref();
console.log(`Launched ${appToOpen}`);
