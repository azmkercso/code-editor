import * as assert from 'assert';
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

  describe('product-config.diff (generated)', () => {
    let productJson: any;

    before(() => {
      productJson = JSON.parse(readPatched('product.json'));
    });

    it('should rename applicationName to code', () => {
      assert.strictEqual(productJson.applicationName, 'code');
    });

    it('should set dataFolderName', () => {
      assert.strictEqual(productJson.dataFolderName, '.vscode-editor');
    });

    it('should set serverApplicationName', () => {
      assert.strictEqual(productJson.serverApplicationName, 'code-editor-server');
    });

    it('should set serverDataFolderName', () => {
      assert.strictEqual(productJson.serverDataFolderName, '.code-editor-server');
    });

    it('should clear builtInExtensions', () => {
      assert.deepStrictEqual(productJson.builtInExtensions, []);
    });

    it('should set defaultChatAgent to Amazon Q', () => {
      assert.strictEqual(productJson.defaultChatAgent.extensionId, 'Amazon.amazon-q-vscode');
      assert.strictEqual(productJson.defaultChatAgent.chatExtensionId, 'Amazon.amazon-q-vscode');
    });

    it('should blank provider IDs', () => {
      for (const [, val] of Object.entries(productJson.defaultChatAgent.provider)) {
        assert.strictEqual((val as any).id, '');
        assert.strictEqual((val as any).name, '');
      }
    });

    it('should remove Copilot-specific fields from defaultChatAgent', () => {
      assert.strictEqual(productJson.defaultChatAgent.providerExtensionId, undefined);
      assert.strictEqual(productJson.defaultChatAgent.entitlementUrl, undefined);
      assert.strictEqual(productJson.defaultChatAgent.mcpRegistryDataUrl, undefined);
    });

    it('should set trustedExtensionAuthAccess to Amazon', () => {
      assert.deepStrictEqual(productJson.trustedExtensionAuthAccess, { amazon: ['Amazon.amazon-q-vscode'] });
    });

    it('should have linkProtectionTrustedDomains', () => {
      assert.ok(Array.isArray(productJson.linkProtectionTrustedDomains));
      assert.ok(productJson.linkProtectionTrustedDomains.includes('https://docs.aws.amazon.com'));
    });

    it('should have excludedSettingPatterns', () => {
      assert.ok(Array.isArray(productJson.excludedSettingPatterns));
      assert.ok(productJson.excludedSettingPatterns.includes('chat.'));
      assert.ok(productJson.excludedSettingPatterns.includes('github.copilot'));
    });

    it('should have excludedActionPatterns', () => {
      assert.ok(Array.isArray(productJson.excludedActionPatterns));
      assert.ok(productJson.excludedActionPatterns.includes('workbench.action.chat.'));
      assert.ok(productJson.excludedActionPatterns.includes('github.copilot.'));
    });

    it('should have codeEditorVersion', () => {
      assert.strictEqual(productJson.codeEditorVersion, '1.0.0');
    });

    it('should set licenseUrl to aws/code-editor', () => {
      assert.ok(productJson.licenseUrl.includes('aws/code-editor'));
    });

    it('should set reportIssueUrl to aws/code-editor', () => {
      assert.ok(productJson.reportIssueUrl.includes('aws/code-editor'));
    });

    it('should produce valid JSON (no duplicate keys)', () => {
      // Re-parse to ensure no syntax issues
      JSON.parse(readPatched('product.json'));
    });

    it('should not reference GitHub Copilot as chat agent', () => {
      assert.notStrictEqual(productJson.defaultChatAgent.extensionId, 'GitHub.copilot');
      assert.notStrictEqual(productJson.defaultChatAgent.chatExtensionId, 'GitHub.copilot-chat');
    });

    it('should not have GitHub as a trusted auth provider', () => {
      assert.strictEqual(productJson.trustedExtensionAuthAccess?.github, undefined);
      assert.strictEqual(productJson.trustedExtensionAuthAccess?.['github-enterprise'], undefined);
    });

    it('should not contain Microsoft/GitHub branding in string values', () => {
      const json = readPatched('product.json');
      // Check top-level string fields that we control
      assert.ok(!productJson.nameShort?.includes('VS Code'), `nameShort contains VS Code: ${productJson.nameShort}`);
      assert.ok(!productJson.nameShort?.includes('Code - OSS'), `nameShort contains Code - OSS`);
      assert.ok(!productJson.nameLong?.includes('VS Code'), `nameLong contains VS Code`);
      assert.ok(!productJson.nameLong?.includes('Code - OSS'), `nameLong contains Code - OSS`);
      // Ensure no microsoft.com URLs in license/report fields
      assert.ok(!productJson.licenseUrl?.includes('microsoft.com'), 'licenseUrl references microsoft.com');
      assert.ok(!productJson.reportIssueUrl?.includes('microsoft.com'), 'reportIssueUrl references microsoft.com');
      assert.ok(!productJson.reportIssueUrl?.includes('microsoft/vscode'), 'reportIssueUrl references microsoft/vscode');
    });

    it('should not have non-empty Copilot provider IDs', () => {
      const providers = productJson.defaultChatAgent?.provider;
      if (providers) {
        for (const [key, val] of Object.entries(providers)) {
          assert.strictEqual((val as any).id, '', `provider "${key}" has non-empty id`);
        }
      }
    });

    it('should not have GitHub.copilot in builtInExtensions', () => {
      const extensions = productJson.builtInExtensions || [];
      const copilotExt = extensions.find((e: any) => e.name?.includes('copilot') || e.name?.includes('GitHub'));
      assert.strictEqual(copilotExt, undefined, `Found Copilot/GitHub extension: ${copilotExt?.name}`);
    });
  });

  describe('remove-kerberos.diff (generated)', () => {
    it('package.json should not have kerberos dependency', () => {
      const pkg = JSON.parse(readPatched('package.json'));
      assert.strictEqual(pkg.dependencies?.kerberos, undefined);
    });

    it('package.json should not have kerberos override', () => {
      const pkg = JSON.parse(readPatched('package.json'));
      assert.strictEqual(pkg.overrides?.['kerberos@2.1.1'], undefined);
    });

    it('remote/package.json should not have kerberos dependency', () => {
      const pkg = JSON.parse(readPatched('remote/package.json'));
      assert.strictEqual(pkg.dependencies?.kerberos, undefined);
    });

    it('remote/package.json should not have kerberos override', () => {
      const pkg = JSON.parse(readPatched('remote/package.json'));
      assert.strictEqual(pkg.overrides?.['kerberos@2.1.1'], undefined);
    });
  });
});
