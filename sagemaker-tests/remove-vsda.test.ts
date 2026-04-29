import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('remove-vsda.diff validation', () => {
  test('signService.ts should stub vsda with "not supported" error', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/platform/sign/browser/signService.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (!content.includes('throw new Error("not supported")')) {
      throw new Error('Expected vsda stub throwing "not supported" not found');
    }
    // Ensure the original WASM loading code is removed
    if (content.includes('vsda_bg.wasm')) {
      throw new Error('Original VSDA WASM loading code should be removed');
    }
  });
});
