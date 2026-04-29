import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import './test-framework';

const PATCHED_VSCODE_DIR = join(process.cwd(), 'code-editor-src');

describe('set-default-log-level-to-error.diff validation', () => {
  test('log.ts should set DEFAULT_LOG_LEVEL to LogLevel.Error', () => {
    const filePath = join(PATCHED_VSCODE_DIR, 'src/vs/platform/log/common/log.ts');
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }
    const content = readFileSync(filePath, 'utf8');

    if (!content.includes('DEFAULT_LOG_LEVEL: LogLevel = LogLevel.Error')) {
      throw new Error('Expected DEFAULT_LOG_LEVEL to be LogLevel.Error');
    }
  });
});
