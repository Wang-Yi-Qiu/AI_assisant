#!/usr/bin/env python3
"""
图表渲染器模块
支持多种图表类型的渲染和导出
"""

import json
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import seaborn as sns
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Optional
import base64
import io

# 设置中文字体支持
plt.rcParams['font.sans-serif'] = ['SimHei', 'Arial Unicode MS', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

class ChartRenderer:
    """图表渲染器类"""

    def __init__(self, backend: str = 'plotly'):
        """
        初始化渲染器
        Args:
            backend: 渲染后端 ('plotly', 'matplotlib', 'seaborn')
        """
        self.backend = backend
        self.color_schemes = {
            'category10': px.colors.qualitative.Plotly,
            'tableau10': px.colors.qualitative.Tableau,
            'set3': px.colors.qualitative.Set3,
            'viridis': px.colors.sequential.Viridis,
            'plasma': px.colors.sequential.Plasma,
            'blues': px.colors.sequential.Blues,
            'reds': px.colors.sequential.Reds
        }

    def render_chart(self, config: Dict[str, Any], data: pd.DataFrame) -> str:
        """
        渲染图表
        Args:
            config: 图表配置
            data: 数据框
        Returns:
            HTML字符串或图片数据
        """
        chart_type = config.get('type', 'bar')

        if self.backend == 'plotly':
            return self._render_with_plotly(chart_type, config, data)
        elif self.backend == 'matplotlib':
            return self._render_with_matplotlib(chart_type, config, data)
        elif self.backend == 'seaborn':
            return self._render_with_seaborn(chart_type, config, data)
        else:
            raise ValueError(f"Unsupported backend: {self.backend}")

    def _render_with_plotly(self, chart_type: str, config: Dict[str, Any],
                           data: pd.DataFrame) -> str:
        """使用Plotly渲染图表"""
        encoding = config.get('encoding', {})
        chart_config = config.get('config', {})
        color_scheme = self.color_schemes.get(
            chart_config.get('colorScheme', 'category10'),
            self.color_schemes['category10']
        )

        fig = None

        if chart_type == 'scatter':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')
            size_field = encoding.get('size', {}).get('field')

            fig = px.scatter(
                data, x=x_field, y=y_field,
                color=color_field, size=size_field,
                color_discrete_sequence=color_scheme,
                title=chart_config.get('title', ''),
                width=config.get('width', 800),
                height=config.get('height', 600)
            )

        elif chart_type == 'bar':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            fig = px.bar(
                data, x=x_field, y=y_field,
                color=color_field,
                color_discrete_sequence=color_scheme,
                title=chart_config.get('title', ''),
                width=config.get('width', 800),
                height=config.get('height', 600)
            )

        elif chart_type == 'line':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            fig = px.line(
                data, x=x_field, y=y_field,
                color=color_field,
                color_discrete_sequence=color_scheme,
                title=chart_config.get('title', ''),
                width=config.get('width', 800),
                height=config.get('height', 600)
            )

        elif chart_type == 'area':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            fig = px.area(
                data, x=x_field, y=y_field,
                color=color_field,
                color_discrete_sequence=color_scheme,
                title=chart_config.get('title', ''),
                width=config.get('width', 800),
                height=config.get('height', 600)
            )

        elif chart_type == 'treemap':
            # 树状图需要特殊的数据处理
            path_fields = []
            values_field = None
            color_field = encoding.get('color', {}).get('field')

            # 尝试从配置中获取路径和值字段
            for field, field_config in encoding.items():
                if field in ['x', 'y', 'group']:
                    path_fields.append(field_config.get('field'))
                elif field == 'size':
                    values_field = field_config.get('field')

            if path_fields and values_field:
                fig = px.treemap(
                    data, path=path_fields, values=values_field,
                    color=color_field,
                    color_discrete_sequence=color_scheme,
                    title=chart_config.get('title', ''),
                    width=config.get('width', 800),
                    height=config.get('height', 600)
                )

        elif chart_type == 'heatmap':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            # 为热力图创建透视表
            if x_field and y_field:
                pivot_data = data.pivot_table(
                    values=color_field, index=y_field, columns=x_field,
                    aggfunc='mean', fill_value=0
                )

                fig = px.imshow(
                    pivot_data,
                    color_continuous_scale='Viridis',
                    title=chart_config.get('title', ''),
                    width=config.get('width', 800),
                    height=config.get('height', 600)
                )

        elif chart_type == 'sankey':
            # 桑基图需要特殊的数据结构
            fig = self._create_sankey_diagram(data, config)

        elif chart_type == 'chord':
            # 弦图需要特殊的数据结构
            fig = self._create_chord_diagram(data, config)

        if fig:
            # 添加交互配置
            if chart_config.get('interactive', True):
                fig.update_layout(
                    hovermode='closest',
                    showlegend=True,
                    template='plotly_white'
                )
            else:
                fig.update_layout(showlegend=False)

            return fig.to_html(include_plotlyjs='cdn')

        return "<p>无法创建指定类型的图表</p>"

    def _render_with_matplotlib(self, chart_type: str, config: Dict[str, Any],
                               data: pd.DataFrame) -> str:
        """使用Matplotlib渲染图表"""
        fig, ax = plt.subplots(figsize=(config.get('width', 800)/100,
                                     config.get('height', 600)/100))

        encoding = config.get('encoding', {})
        chart_config = config.get('config', {})
        color_scheme = self.color_schemes.get(
            chart_config.get('colorScheme', 'category10'),
            self.color_schemes['category10']
        )

        if chart_type == 'scatter':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            if x_field and y_field:
                if color_field:
                    unique_categories = data[color_field].unique()
                    for i, category in enumerate(unique_categories):
                        mask = data[color_field] == category
                        ax.scatter(
                            data[mask][x_field],
                            data[mask][y_field],
                            color=color_scheme[i % len(color_scheme)],
                            label=category,
                            alpha=0.7
                        )
                    ax.legend()
                else:
                    ax.scatter(data[x_field], data[y_field], alpha=0.7)

                ax.set_xlabel(x_field)
                ax.set_ylabel(y_field)

        elif chart_type == 'bar':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')

            if x_field and y_field:
                # 聚合数据
                grouped_data = data.groupby(x_field)[y_field].sum().reset_index()

                bars = ax.bar(
                    grouped_data[x_field],
                    grouped_data[y_field],
                    color=color_scheme[0] if len(grouped_data) == 1 else
                    color_scheme[:len(grouped_data)]
                )

                ax.set_xlabel(x_field)
                ax.set_ylabel(y_field)

        # 设置标题和样式
        ax.set_title(chart_config.get('title', ''))
        ax.grid(True, alpha=0.3)

        # 保存为base64字符串
        buffer = io.BytesIO()
        plt.savefig(buffer, format='png', bbox_inches='tight', dpi=150)
        buffer.seek(0)

        image_base64 = base64.b64encode(buffer.getvalue()).decode()
        plt.close()

        return f'<img src="data:image/png;base64,{image_base64}" style="max-width: 100%;">'

    def _render_with_seaborn(self, chart_type: str, config: Dict[str, Any],
                           data: pd.DataFrame) -> str:
        """使用Seaborn渲染图表"""
        encoding = config.get('encoding', {})
        chart_config = config.get('config', {})

        plt.figure(figsize=(config.get('width', 800)/100,
                          config.get('height', 600)/100))

        if chart_type == 'scatter':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')
            color_field = encoding.get('color', {}).get('field')

            if x_field and y_field:
                if color_field:
                    sns.scatterplot(
                        data=data, x=x_field, y=y_field,
                        hue=color_field, alpha=0.7
                    )
                else:
                    sns.scatterplot(data=data, x=x_field, y=y_field, alpha=0.7)

        elif chart_type == 'bar':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')

            if x_field and y_field:
                sns.barplot(data=data, x=x_field, y=y_field)

        elif chart_type == 'heatmap':
            x_field = encoding.get('x', {}).get('field')
            y_field = encoding.get('y', {}).get('field')

            if x_field and y_field:
                # 创建透视表
                pivot_data = data.pivot_table(
                    index=y_field, columns=x_field,
                    aggfunc='mean', fill_value=0
                )
                sns.heatmap(pivot_data, annot=True, cmap='viridis')

        plt.title(chart_config.get('title', ''))
        plt.tight_layout()

        # 保存为base64字符串
        buffer = io.BytesIO()
        plt.savefig(buffer, format='png', bbox_inches='tight', dpi=150)
        buffer.seek(0)

        image_base64 = base64.b64encode(buffer.getvalue()).decode()
        plt.close()

        return f'<img src="data:image/png;base64,{image_base64}" style="max-width: 100%;">'

    def _create_sankey_diagram(self, data: pd.DataFrame, config: Dict[str, Any]) -> go.Figure:
        """创建桑基图"""
        # 桑基图需要特殊的数据预处理
        # 这里是一个简化的实现
        encoding = config.get('encoding', {})

        # 假设有source和target字段
        if 'source' in data.columns and 'target' in data.columns and 'value' in data.columns:
            nodes = list(set(data['source'].unique()) | set(data['target'].unique()))

            fig = go.Figure(data=[go.Sankey(
                node=dict(
                    pad=15,
                    thickness=20,
                    line=dict(color="black", width=0.5),
                    label=nodes
                ),
                link=dict(
                    source=[nodes.index(s) for s in data['source']],
                    target=[nodes.index(t) for t in data['target']],
                    value=data['value']
                )
            )])

            fig.update_layout(
                title_text=config.get('config', {}).get('title', '桑基图'),
                font_size=10
            )

            return fig

        return go.Figure()

    def _create_chord_diagram(self, data: pd.DataFrame, config: Dict[str, Any]) -> go.Figure:
        """创建弦图"""
        # 弦图的简化实现
        # 实际的弦图可能需要更复杂的处理

        fig = go.Figure()

        # 这里可以添加弦图的实现逻辑
        fig.add_annotation(
            text="弦图功能开发中...",
            xref="paper", yref="paper",
            x=0.5, y=0.5, showarrow=False,
            font=dict(size=20)
        )

        fig.update_layout(
            title_text=config.get('config', {}).get('title', '弦图'),
            showlegend=False
        )

        return fig

    def export_chart(self, fig: go.Figure, format_type: str,
                    filename: str = None) -> str:
        """
        导出图表
        Args:
            fig: Plotly图表对象
            format_type: 导出格式 ('html', 'png', 'svg', 'pdf', 'json')
            filename: 文件名
        Returns:
            导出内容的字符串或路径
        """
        if format_type == 'html':
            return fig.to_html(include_plotlyjs='cdn')

        elif format_type == 'json':
            return fig.to_json()

        elif format_type in ['png', 'svg', 'pdf']:
            if hasattr(fig, 'write_image'):
                if filename:
                    fig.write_image(filename, format=format_type)
                    return filename
                else:
                    # 返回base64编码的图片
                    img_bytes = fig.to_image(format=format_type)
                    if format_type == 'png':
                        return base64.b64encode(img_bytes).decode()
                    else:
                        return img_bytes.decode('utf-8')

        else:
            raise ValueError(f"Unsupported export format: {format_type}")

    def get_color_scheme(self, scheme_name: str) -> List[str]:
        """获取颜色方案"""
        return self.color_schemes.get(scheme_name, self.color_schemes['category10'])

# 使用示例
if __name__ == "__main__":
    # 创建示例数据
    data = pd.DataFrame({
        'x': range(10),
        'y': np.random.randint(1, 100, 10),
        'category': np.random.choice(['A', 'B', 'C'], 10),
        'size': np.random.randint(10, 50, 10)
    })

    # 创建渲染器
    renderer = ChartRenderer(backend='plotly')

    # 创建配置
    config = {
        'type': 'scatter',
        'encoding': {
            'x': {'field': 'x'},
            'y': {'field': 'y'},
            'color': {'field': 'category'},
            'size': {'field': 'size'}
        },
        'config': {
            'title': '散点图示例',
            'colorScheme': 'category10',
            'interactive': True
        },
        'width': 800,
        'height': 600
    }

    # 渲染图表
    html_output = renderer.render_chart(config, data)

    # 保存到文件
    with open('chart_example.html', 'w', encoding='utf-8') as f:
        f.write(html_output)

    print("图表已生成并保存为 chart_example.html")