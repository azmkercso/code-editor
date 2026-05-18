import { readPatched, assertContains, assertNotContains, currentTarget } from './test-helpers';

describe('common patches', () => {
  describe('installer.diff', () => {
    it('should clear builtInExtensions', () => {
      assertContains(readPatched('product.json'), '"builtInExtensions": []');
    });

    it('getVersion.ts should fall back to "unknown"', () => {
      assertContains(readPatched('build/lib/getVersion.ts'), '"unknown"');
    });
  });

  describe('branding', () => {
    it('should not use VS Code marketplace', () => {
      assertNotContains(readPatched('product.json'), 'marketplace.visualstudio.com');
    });

    it('should have correct nameShort for target', () => {
      const content = readPatched('product.json');
      if (currentTarget === 'code-editor-sagemaker-server') {
        assertContains(content, '"nameShort": "SageMaker Code Editor"');
      } else {
        assertContains(content, '"nameShort": "Code Editor"');
      }
    });
  });

  describe('disable-telemetry.diff', () => {
    it('should restrict telemetry to OFF only', () => {
      const content = readPatched('src/vs/platform/telemetry/common/telemetryService.ts');
      assertContains(content, "'enum': [TelemetryConfiguration.OFF],");
      assertContains(content, "'default': TelemetryConfiguration.OFF,");
    });

    it('should block Microsoft telemetry endpoints', () => {
      const content = readPatched('src/vs/platform/telemetry/common/1dsAppender.ts');
      assertContains(content, "const endpointUrl = 'https://0.0.0.0/OneCollector/1.0';");
      assertContains(content, "const endpointHealthUrl = 'https://0.0.0.0/ping';");
    });
  });

  describe('disable-online-services.diff', () => {
    it('should default update mode to none', () => {
      assertContains(readPatched('src/vs/platform/update/common/update.config.contribution.ts'), "default: 'none'");
    });
  });

  describe('guard-default-account-config.diff', () => {
    it('should reference defaultAccountConfig', () => {
      assertContains(readPatched('src/vs/workbench/services/accounts/browser/defaultAccount.ts'), 'defaultAccountConfig');
    });
  });

  describe('remove-vsda.diff', () => {
    it('should stub out VSDA signing service', () => {
      assertContains(readPatched('src/vs/platform/extensionManagement/node/extensionSignatureVerificationService.ts'), 'return undefined');
    });
  });

  describe('remove-trusted-url-bypass', () => {
    it('product.json should not have trustedDomains', () => {
      assertNotContains(readPatched('product.json'), '"trustedDomains"');
    });
  });

  describe('license', () => {
    it('LICENSE override should be MIT', () => {
      assertContains(readPatched('LICENSE'), 'MIT License');
    });
  });
});
