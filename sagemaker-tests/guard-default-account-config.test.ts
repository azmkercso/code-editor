import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('guard-default-account-config.diff validation', () => {
  test('defaultAccount.ts should use optional chaining for provider fields', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/workbench/services/accounts/browser/defaultAccount.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    const guards = [
      'defaultChatAgent.provider?.default?.id',
      'defaultChatAgent.provider?.default?.name',
      'defaultChatAgent.provider?.enterprise?.id',
      'defaultChatAgent.provider?.enterprise?.name',
      'defaultChatAgent.providerScopes ?? []',
      'defaultChatAgent.entitlementUrl ?? ',
    ];
    for (const guard of guards) {
      if (!content.includes(guard)) {
        throw new Error(`Expected optional chaining guard not found: ${guard}`);
      }
    }
  });
});
