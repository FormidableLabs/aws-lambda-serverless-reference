"use strict";

/**
 * Helper script to switch from published version of `terraform-aws-serverless`
 * to a locally installed version in `../terraform-aws-serverless`.
 *
 * The script basically changes the `source` of the module to local path and
 * comments out the `version` which produces an error in terraform 0.12+.
 *
 * Usage:
 *
 * ```sh
 * $ node terraform/scripts/dev.js --on
 * $ node terraform/scripts/dev.js --off
 * ```
 */
const fs = require("fs").promises;
const path = require("path");
const { log } = console;
const mainFile = path.resolve(__dirname, "../main.tf");

const enableDev = async () => {
  log("Enabling development mode.");

  const buffer = await fs.readFile(mainFile);
  const data = buffer.toString()
    .replace(
      /(\= \"FormidableLabs\/serverless\/aws)(.*\n[ ]*)(version)/g,
      (match, mod, middle) => `= "../../terraform-aws-serverless${middle}# version`
    );

  await fs.writeFile(mainFile, data);
};

const disableDev = async () => {
  log("Disabling development mode.");

  const buffer = await fs.readFile(mainFile);
  const data = buffer.toString()
    .replace(
      /(\= \"..\/..\/terraform-aws-serverless)(.*\n[ ]*)(# version)/g,
      (match, mod, middle) => `= "FormidableLabs/serverless/aws${middle}version`
    );

  await fs.writeFile(mainFile, data);
};

const main = async ({ on, off }) => {
  if (on && off || !on && !off) {
    throw new Error("Must select exactly one of --on|-off");
  }

  if (on) {
    return enableDev();
  }
  return disableDev();
};

if (require.main === module) {
  main({
    on: process.argv.includes("--on"),
    off: process.argv.includes("--off")
  }).catch((err) => {
    console.error(err); // eslint-disable-line no-console
    process.exit(1); // eslint-disable-line no-process-exit
  });
}
