import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('product.json branding validation', () => {
  test('product.json should use Code Editor branding', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'product.json');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const product = JSON.parse(readFileSync(filePath, 'utf8'));

    if (product.nameShort !== 'Code Editor') {
      throw new Error(`Expected nameShort "Code Editor", got "${product.nameShort}"`);
    }
    if (product.nameLong !== 'Code Editor') {
      throw new Error(`Expected nameLong "Code Editor", got "${product.nameLong}"`);
    }
    if (product.serverApplicationName !== 'code-editor-server') {
      throw new Error(`Expected serverApplicationName "code-editor-server", got "${product.serverApplicationName}"`);
    }
  });

  test('product.json should have codeEditorVersion field', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'product.json');
    const product = JSON.parse(readFileSync(filePath, 'utf8'));

    if (!product.codeEditorVersion) {
      throw new Error('Expected codeEditorVersion field in product.json');
    }
  });
});

describe('overrides validation', () => {
  test('custom index.html should exist in patched source', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'resources/server/index.html');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    // Custom index.html has error suppression script
    if (!content.includes('window.onerror') && !content.includes('suppressErrors')) {
      // Check it's not the upstream default
      if (content.includes('{{WORKBENCH_WEB_CONFIGURATION}}') && !content.includes('script')) {
        throw new Error('index.html appears to be the upstream default, not the custom override');
      }
    }
  });

  test('custom favicon.ico should exist in patched source', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'resources/server/favicon.ico');
    if (!existsSync(filePath)) {
      throw new Error(`Custom favicon.ico not found: ${filePath}`);
    }
  });

  test('custom letterpress SVGs should exist in patched source', () => {
    const svgs = [
      'src/vs/workbench/browser/parts/editor/media/letterpress-dark.svg',
      'src/vs/workbench/browser/parts/editor/media/letterpress-light.svg',
      'src/vs/workbench/browser/parts/editor/media/letterpress-hcDark.svg',
      'src/vs/workbench/browser/parts/editor/media/letterpress-hcLight.svg',
      'src/vs/workbench/browser/media/code-icon.svg',
    ];
    for (const svg of svgs) {
      const filePath = join(PATCHED_VSCODE_DIR, svg);
      if (!existsSync(filePath)) {
        throw new Error(`Custom SVG not found: ${filePath}`);
      }
    }
  });
});
