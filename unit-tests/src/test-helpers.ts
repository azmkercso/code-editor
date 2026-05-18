import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import * as assert from 'assert';

type Target =
  | 'code-editor-sagemaker-server'
  | 'code-editor-server'
  | 'code-editor-web-embedded'
  | 'code-editor-web-embedded-with-terminal';

const TARGET = (process.env.TARGET || 'code-editor-sagemaker-server') as Target;

const WEB_TARGETS: Target[] = ['code-editor-web-embedded', 'code-editor-web-embedded-with-terminal'];
const SERVER_TARGETS: Target[] = ['code-editor-server', 'code-editor-sagemaker-server'];

/** describe that only runs for web-embedded targets */
export const describeIfWeb = WEB_TARGETS.includes(TARGET) ? describe : describe.skip;

/** describe that only runs for server targets (code-editor-server + sagemaker) */
export const describeIfServer = SERVER_TARGETS.includes(TARGET) ? describe : describe.skip;

/** describe that only runs for sagemaker */
export const describeIfSageMaker = TARGET === 'code-editor-sagemaker-server' ? describe : describe.skip;

/** Patched source directory — overridable via PATCHED_SRC_DIR env */
export const PATCHED_VSCODE_DIR = process.env.PATCHED_SRC_DIR || join(__dirname, '..', '..', 'code-editor-src');

/** Current target for variant-specific assertions */
export const currentTarget = TARGET;

/** Read a file from the patched source, asserting it exists */
export function readPatched(relativePath: string): string {
  const filePath = join(PATCHED_VSCODE_DIR, relativePath);
  assert.ok(existsSync(filePath), `File not found: ${filePath}`);
  return readFileSync(filePath, 'utf8');
}

/** Assert content includes expected string */
export function assertContains(content: string, expected: string, message?: string): void {
  assert.ok(content.includes(expected), message || `Expected content to include: ${expected}`);
}

/** Assert content does NOT include unexpected string */
export function assertNotContains(content: string, unexpected: string, message?: string): void {
  assert.ok(!content.includes(unexpected), message || `Expected content NOT to include: ${unexpected}`);
}

/** Assert content matches a regex pattern */
export function assertMatches(content: string, pattern: RegExp, message?: string): void {
  assert.ok(pattern.test(content), message || `Expected content to match: ${pattern}`);
}
