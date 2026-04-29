import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('proxy-uri.diff validation', () => {
  test('http-proxy dependency should be added to root package.json', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'package.json');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const pkg = JSON.parse(readFileSync(filePath, 'utf8'));

    if (!pkg.dependencies?.['http-proxy']) {
      throw new Error('Expected http-proxy dependency in root package.json');
    }
  });

  test('http-proxy dependency should be added to remote/package.json', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'remote/package.json');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const pkg = JSON.parse(readFileSync(filePath, 'utf8'));

    if (!pkg.dependencies?.['http-proxy']) {
      throw new Error('Expected http-proxy dependency in remote/package.json');
    }
  });
});
