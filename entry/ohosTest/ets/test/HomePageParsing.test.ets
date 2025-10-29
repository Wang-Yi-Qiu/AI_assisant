import { describe, it, expect } from '@ohos/hypium';
import { parseUserInput, parseCSV, parseFileContent } from '../../src/main/ets/pages/HomePage';

export default function HomePageParsingTests() {
  describe('HomePage Parsing', () => {
    it('should parse valid JSON text', () => {
      const input = '{"a":1,"b":2}';
      const result = parseUserInput(input) as any;
      expect(result.a).toEqual(1);
      expect(result.b).toEqual(2);
    });

    it('should fall back to CSV parsing when not JSON', () => {
      const csv = 'x,y\n1,2';
      const result = parseUserInput(csv) as any;
      expect(result.headers.length).toBe(2);
      expect(result.data.length).toBe(1);
      expect(result.data[0].x).toEqual('1');
    });

    it('should parse CSV content by extension', () => {
      const csv = 'a,b\n3,4';
      const result = parseFileContent(csv, 'data.csv') as any;
      expect(result.headers[0]).toEqual('a');
      expect(result.data[0].b).toEqual('4');
    });

    it('should throw on invalid JSON extension content', () => {
      let threw = false;
      try {
        parseFileContent('not-json', 'bad.json');
      } catch (e) {
        threw = true;
      }
      expect(threw).toBeTruthy();
    });
  });
}


