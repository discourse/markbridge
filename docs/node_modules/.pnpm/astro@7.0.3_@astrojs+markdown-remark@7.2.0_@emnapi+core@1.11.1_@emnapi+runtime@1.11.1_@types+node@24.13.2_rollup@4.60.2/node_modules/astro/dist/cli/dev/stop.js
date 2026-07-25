import { pathToFileURL } from "node:url";
import {
  checkExistingServer,
  removeLockFile,
  isProcessAlive,
  GRACEFUL_SHUTDOWN_TIMEOUT
} from "../../core/dev/lockfile.js";
import { resolveRoot } from "../../core/config/config.js";
function formatStopOutput(result) {
  return JSON.stringify(result);
}
async function stop({
  flags,
  logger
}) {
  const root = pathToFileURL(resolveRoot(flags.root) + "/");
  const existing = checkExistingServer(root);
  if (!existing) {
    logger.info("SKIP_FORMAT", "No dev server is running.");
    return;
  }
  try {
    process.kill(existing.pid, "SIGTERM");
  } catch {
  }
  const deadline = Date.now() + GRACEFUL_SHUTDOWN_TIMEOUT;
  while (Date.now() < deadline) {
    if (!isProcessAlive(existing.pid)) break;
    await new Promise((r) => setTimeout(r, 100));
  }
  if (isProcessAlive(existing.pid)) {
    try {
      process.kill(existing.pid, "SIGKILL");
    } catch {
    }
  }
  removeLockFile(root);
  logger.info("SKIP_FORMAT", `Stopped dev server (pid ${existing.pid}).`);
}
export {
  formatStopOutput,
  stop
};
