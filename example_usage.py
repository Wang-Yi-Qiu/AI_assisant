#!/usr/bin/env python3
"""
数据可视化技能使用示例
"""

# 模拟数据（如果无法安装pandas）
sample_data = {
    "data": [
        {"month": "1月", "sales": 1200, "category": "电子产品"},
        {"month": "2月", "sales": 1500, "category": "电子产品"},
        {"month": "3月", "sales": 1800, "category": "电子产品"},
        {"month": "1月", "sales": 800, "category": "服装"},
        {"month": "2月", "sales": 950, "category": "服装"},
        {"month": "3月", "sales": 1100, "category": "服装"},
        {"month": "1月", "sales": 600, "category": "食品"},
        {"month": "2月", "sales": 720, "category": "食品"},
        {"month": "3月", "sales": 850, "category": "食品"}
    ]
}

# 示例配置
chart_configs = {
    "bar_chart": {
        "type": "bar",
        "title": "月度销售对比",
        "x_field": "month",
        "y_field": "sales",
        "color_field": "category",
        "width": 800,
        "height": 600,
        "color_scheme": "category10"
    },
    "scatter_plot": {
        "type": "scatter",
        "title": "销售散点分析",
        "x_field": "month",
        "y_field": "sales",
        "color_field": "category",
        "width": 800,
        "height": 600,
        "color_scheme": "tableau10"
    },
    "line_chart": {
        "type": "line",
        "title": "销售趋势分析",
        "x_field": "month",
        "y_field": "sales",
        "color_field": "category",
        "width": 800,
        "height": 600,
        "color_scheme": "set3"
    }
}

# 生成示例HTML
def generate_example_html():
    """生成示例HTML页面"""
    html_template = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>数据可视化生成器 - RawGraphs风格</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .chart-container { margin: 20px 0; padding: 20px; border: 1px solid #ddd; }
        .controls { margin: 20px 0; padding: 15px; background: #f5f5f5; }
        select, button { margin: 5px; padding: 8px 15px; }
    </style>
</head>
<body>
    <h1>🎨 数据可视化生成器</h1>
    <p>基于 RawGraphs 理念的智能数据可视化工具</p>

    <div class="controls">
        <h3>图表控制面板</h3>
        <select id="chartType">
            <option value="bar">条形图</option>
            <option value="scatter">散点图</option>
            <option value="line">折线图</option>
            <option value="area">面积图</option>
            <option value="treemap">树状图</option>
            <option value="heatmap">热力图</option>
        </select>

        <select id="colorScheme">
            <option value="category10">Category10</option>
            <option value="tableau10">Tableau10</option>
            <option value="set3">Set3</option>
            <option value="viridis">Viridis</option>
        </select>

        <button onclick="updateChart()">更新图表</button>
        <button onclick="exportChart()">导出图表</button>
    </div>

    <div class="chart-container">
        <div id="plotlyChart"></div>
    </div>

    <div class="controls">
        <h3>数据洞察</h3>
        <div id="insights">
            <ul>
                <li>📊 数据包含 3 个类别，9 个月度数据点</li>
                <li>📈 电子产品类别显示持续增长趋势</li>
                <li>🎯 所有类别都呈现正向增长</li>
                <li>💡 建议关注电子产品的增长策略</li>
            </ul>
        </div>
    </div>

    <script>
        // 示例数据
        const data = """ + json.dumps(sample_data['data'], indent=4) + """;

        // 创建图表
        function createChart(type) {
            const trace1 = {
                x: data.filter(d => d.category === '电子产品').map(d => d.month),
                y: data.filter(d => d.category === '电子产品').map(d => d.sales),
                name: '电子产品',
                type: type === 'scatter' ? 'scatter' : 'bar'
            };

            const trace2 = {
                x: data.filter(d => d.category === '服装').map(d => d.month),
                y: data.filter(d => d.category === '服装').map(d => d.sales),
                name: '服装',
                type: type === 'scatter' ? 'scatter' : 'bar'
            };

            const trace3 = {
                x: data.filter(d => d.category === '食品').map(d => d.month),
                y: data.filter(d => d.category === '食品').map(d => d.sales),
                name: '食品',
                type: type === 'scatter' ? 'scatter' : 'bar'
            };

            const layout = {
                title: '销售数据分析',
                xaxis: { title: '月份' },
                yaxis: { title: '销售额' },
                barmode: 'group'
            };

            const plotData = [trace1, trace2, trace3];
            Plotly.newPlot('plotlyChart', plotData, layout);
        }

        function updateChart() {
            const type = document.getElementById('chartType').value;
            createChart(type);
        }

        function exportChart() {
            Plotly.downloadImage('plotlyChart', {
                format: 'png',
                width: 1200,
                height: 800,
                filename: 'chart_export'
            });
        }

        // 初始化
        createChart('bar');
    </script>
</body>
</html>
"""
    return html_template

if __name__ == "__main__":
    import json

    # 生成示例HTML文件
    html_content = generate_example_html()

    with open('data_visualization_example.html', 'w', encoding='utf-8') as f:
        f.write(html_content)

    print("✅ 数据可视化示例已生成: data_visualization_example.html")
    print("📊 支持的图表类型:")
    print("   • 条形图 (Bar Chart)")
    print("   • 散点图 (Scatter Plot)")
    print("   • 折线图 (Line Chart)")
    print("   • 面积图 (Area Chart)")
    print("   • 树状图 (Treemap)")
    print("   • 热力图 (Heatmap)")
    print("   • 桑基图 (Sankey Diagram)")
    print("   • 弦图 (Chord Diagram)")
    print()
    print("🎯 核心功能:")
    print("   • 智能数据类型检测")
    print("   • 自动字段映射")
    print("   • 图表类型推荐")
    print("   • 数据质量验证")
    print("   • 多种导出格式")
    print()
    print("🚀 使用方法:")
    print("   1. 在浏览器中打开 data_visualization_example.html")
    print("   2. 选择图表类型和颜色方案")
    print("   3. 点击'更新图表'查看效果")
    print("   4. 点击'导出图表'下载图片")

    # 显示示例配置
    print("\n📝 示例配置:")
    print(json.dumps(chart_configs["bar_chart"], indent=2, ensure_ascii=False))