import { readPatched, assertContains, describeIfWeb } from './test-helpers';

describeIfWeb('web-embedded patches', () => {
  describe('set-default-log-level-to-error.diff', () => {
    it('should set DEFAULT_LOG_LEVEL to LogLevel.Error', () => {
      assertContains(readPatched('src/vs/platform/log/common/log.ts'), 'DEFAULT_LOG_LEVEL: LogLevel = LogLevel.Error');
    });
  });
});
