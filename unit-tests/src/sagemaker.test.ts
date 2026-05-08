import { existsSync } from 'fs';
import { join } from 'path';
import * as assert from 'assert';
import { readPatched, assertContains, describeIfSageMaker, PATCHED_VSCODE_DIR } from './test-helpers';

describeIfSageMaker('sagemaker patches', () => {
  describe('sagemaker-product-config.diff (generated)', () => {
    it('should rename to SageMaker Code Editor', () => {
      const productJson = JSON.parse(readPatched('product.json'));
      assert.strictEqual(productJson.nameShort, 'SageMaker Code Editor');
      assert.strictEqual(productJson.nameLong, 'SageMaker Code Editor');
    });

    it('should have sagemakerCodeEditorVersion', () => {
      assertContains(readPatched('product.json'), '"sagemakerCodeEditorVersion"');
    });
  });

  describe('sagemaker-integration.diff', () => {
    it('web.main.ts should import SagemakerServerClient', () => {
      assertContains(readPatched('src/vs/workbench/browser/web.main.ts'), 'SagemakerServerClient');
    });

    it('client.ts should define SagemakerServerClient class', () => {
      assertContains(readPatched('src/vs/workbench/browser/client.ts'), 'class SagemakerServerClient');
    });
  });

  describe('update-csp.diff', () => {
    it('should set Content-Security-Policy header', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), "'Content-Security-Policy'");
    });
  });

  describe('base-path-compatibility.diff', () => {
    it('webClientServer.ts should have basePath support', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'basePath');
    });
  });

  describe('fix-port-forwarding.diff', () => {
    it('workbench.ts should have port forwarding proxy URI', () => {
      assertContains(readPatched('src/vs/code/browser/workbench/workbench.ts'), 'codeeditor/default/ports/');
    });
  });

  describe('sagemaker-ui-post-startup.diff', () => {
    it('webClientServer.ts should have spawn import for post-startup', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'spawn');
    });
  });

  describe('post-startup-notifications.diff', () => {
    it('extension should have chokidar dependency', () => {
      assertContains(readPatched('extensions/post-startup-notifications/package.json'), '"chokidar"');
    });
  });

  describe('sagemaker-extension.diff', () => {
    it('should have extension.ts', () => {
      assert.ok(existsSync(join(PATCHED_VSCODE_DIR, 'extensions/sagemaker-extension/src/extension.ts')));
    });

    it('should have correct package name', () => {
      assertContains(readPatched('extensions/sagemaker-extension/package.json'), '"name": "sagemaker-extension"');
    });
  });

  describe('sagemaker-extension-smus-support.diff', () => {
    it('constant.ts should have SMUS constants', () => {
      assertContains(readPatched('extensions/sagemaker-extension/src/constant.ts'), 'SMUS');
    });
  });

  describe('sagemaker-extensions-sync.diff', () => {
    it('gulpfile.extensions.ts should include it', () => {
      assertContains(readPatched('build/gulpfile.extensions.ts'), 'sagemaker-extensions-sync');
    });

    it('dirs.ts should include it', () => {
      assertContains(readPatched('build/npm/dirs.ts'), 'sagemaker-extensions-sync');
    });
  });

  describe('sagemaker-idle-extension.diff', () => {
    it('should have correct package name', () => {
      assertContains(readPatched('extensions/sagemaker-idle-extension/package.json'), '"name": "sagemaker-idle-extension"');
    });
  });

  describe('sagemaker-open-notebook-extension.diff', () => {
    it('gulpfile.extensions.ts should include it', () => {
      assertContains(readPatched('build/gulpfile.extensions.ts'), 'sagemaker-open-notebook-extension');
    });

    it('should have correct package name', () => {
      assertContains(readPatched('extensions/sagemaker-open-notebook-extension/package.json'), '"name": "sagemaker-open-notebook-extension"');
    });
  });

  describe('sagemaker-ui-dark-theme.diff', () => {
    it('should have package.json', () => {
      assertContains(readPatched('extensions/sagemaker-ui-dark-theme/package.json'), '"name": "sagemaker-ui-dark-theme"');
    });

    it('should have .vscodeignore', () => {
      assert.ok(existsSync(join(PATCHED_VSCODE_DIR, 'extensions/sagemaker-ui-dark-theme/.vscodeignore')));
    });
  });

  describe('terminal-crash-mitigation.diff', () => {
    it('should have correct package name', () => {
      assertContains(readPatched('extensions/sagemaker-terminal-crash-mitigation/package.json'), '"name": "sagemaker-terminal-crash-mitigation"');
    });

    it('should have .vscodeignore', () => {
      assert.ok(existsSync(join(PATCHED_VSCODE_DIR, 'extensions/sagemaker-terminal-crash-mitigation/.vscodeignore')));
    });
  });
});
