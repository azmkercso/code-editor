import { readPatched, assertContains, assertMatches, describeIfServer } from './test-helpers';

describeIfServer('web-server patches', () => {
  describe('marketplace.diff', () => {
    it('product.json should use Open VSX registry', () => {
      assertContains(readPatched('product.json'), 'open-vsx.org');
    });
  });

  describe('display-language.diff', () => {
    it('webClientServer.ts should have locale support', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'locale');
    });
  });

  describe('local-storage.diff', () => {
    it('webClientServer.ts should pass userDataPath', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'userDataPath');
    });
  });

  describe('proxy-uri.diff', () => {
    it('webClientServer.ts should have proxy path support', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'proxyPath');
    });
  });

  describe('signature-verification.diff', () => {
    it('should disable signature verification', () => {
      assertContains(readPatched('src/vs/platform/extensionManagement/node/extensionManagementService.ts'), 'verifySignature = false');
    });
  });

  describe('webview.diff', () => {
    it('environmentService.ts should have webview endpoint', () => {
      assertContains(readPatched('src/vs/workbench/services/environment/browser/environmentService.ts'), 'webviewEndpoint');
    });

    it('webClientServer.ts should configure webviewEndpoint', () => {
      assertContains(readPatched('src/vs/server/node/webClientServer.ts'), 'webviewEndpoint');
    });

    it('webview pre/index.html should have valid CSP with script-src sha256', () => {
      assertMatches(readPatched('src/vs/workbench/contrib/webview/browser/pre/index.html'),
        /script-src[^;]*'sha256-[A-Za-z0-9+/]+=*'/);
    });

    it('webWorkerExtensionHostIframe.html should have valid CSP with script-src sha256', () => {
      assertMatches(readPatched('src/vs/workbench/services/extensions/worker/webWorkerExtensionHostIframe.html'),
        /script-src[^;]*'sha256-[A-Za-z0-9+/]+=*'/);
    });
  });
});
