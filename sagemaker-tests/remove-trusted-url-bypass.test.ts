import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('remove-disable-prompting-for-non-trusted-urls-option.diff validation', () => {
  test('trustedDomainsValidator.ts should not bypass prompt for trusted workspaces', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/workbench/contrib/url/browser/trustedDomainsValidator.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (content.includes('promptInTrustedWorkspace')) {
      throw new Error('promptInTrustedWorkspace bypass should be removed');
    }
    if (content.includes('IWorkspaceTrustManagementService')) {
      throw new Error('IWorkspaceTrustManagementService import should be removed');
    }
  });

  test('url.contribution.ts should not register promptInTrustedWorkspace setting', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/workbench/contrib/url/browser/url.contribution.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (content.includes('promptInTrustedWorkspace')) {
      throw new Error('promptInTrustedWorkspace configuration registration should be removed');
    }
  });
});
