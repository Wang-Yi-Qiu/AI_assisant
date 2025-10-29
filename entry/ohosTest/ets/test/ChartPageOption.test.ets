import { describe, it, expect } from '@ohos/hypium';
import { setChartOption, getCurrentOption } from '../../src/main/ets/pages/ChartPage';

export default function ChartPageOptionTests() {
  describe('ChartPage Option Validation', () => {
    it('should throw when series is missing', () => {
      let threw = false;
      try {
        // @ts-ignore
        setChartOption({});
      } catch (e) { threw = true; }
      expect(threw).toBeTruthy();
    });

    it('should set option when valid', () => {
      const option = { title: { text: 't' }, series: [{ type: 'line', data: [1,2] }] } as any;
      setChartOption(option);
      const current = getCurrentOption();
      expect(!!current).toBeTruthy();
    });
  });
}


