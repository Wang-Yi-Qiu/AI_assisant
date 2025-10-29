// ChartPage: render ECharts with provided option JSON
// NOTE: Actual ArkTS UI integration via WebView should be wired in UI layer

let currentOption: any = null;

export function setChartOption(option: any): void {
  currentOption = option;
  // TODO: bridge to WebView and call chart.setOption(option)
  // In HarmonyOS: webView.executeJavaScript('chart.setOption(' + JSON.stringify(option) + ')')
}

export function getCurrentOption(): any {
  return currentOption;
}

export async function exportPng(): Promise<string> {
  // TODO: bridge to chart.getDataURL({ type: 'png', backgroundColor: '#fff' })
  // In HarmonyOS: return await webView.executeJavaScript('chart.getDataURL({ type: "png", backgroundColor: "#fff" })')
  return '';
}

export function exportJson(): any {
  return getCurrentOption();
}


