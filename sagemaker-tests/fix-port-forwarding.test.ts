import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('fix-port-forwarding.diff validation', () => {
  test('workbench.ts should include /codeeditor/default/ in proxy URI path', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/code/browser/workbench/workbench.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (!content.includes('/codeeditor/default/ports/')) {
      throw new Error('Expected /codeeditor/default/ports/ path segment not found in proxy URI');
    }
  });
});
