import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const task = process.argv[2] || 'assembleDebug';
const androidDir = join(import.meta.dirname, '..', 'android');
const wrapper = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';
const wrapperPath = join(androidDir, process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');

if (!existsSync(wrapperPath)) {
  console.error(`Gradle wrapper not found: ${wrapperPath}`);
  process.exit(1);
}

const result = spawnSync(wrapper, [task, '--no-daemon'], {
  cwd: androidDir,
  env: process.env,
  shell: process.platform === 'win32',
  stdio: 'inherit',
});

process.exit(result.status ?? 1);
