import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('installer.diff validation', () => {
  test('getVersion.ts should fall back to "unknown" when git version is missing', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'build/lib/getVersion.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (!content.includes('|| "unknown"')) {
      throw new Error('Expected fallback to "unknown" for missing git version');
    }
  });

  test('gulpfile.reh.ts should support CUSTOM_NODE_PATH', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'build/gulpfile.reh.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (!content.includes("process.env['CUSTOM_NODE_PATH']")) {
      throw new Error('Expected CUSTOM_NODE_PATH support not found');
    }
  });
});
