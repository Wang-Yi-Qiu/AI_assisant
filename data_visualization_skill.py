#!/usr/bin/env python3
"""
数据可视化技能完整实现
基于 RawGraphs 理念的智能数据可视化工具
"""

import json
import pandas as pd
from typing import Dict, List, Any, Optional, Union
from data_viz_core import DataVisualizationGenerator, ChartType, FieldInfo
from chart_renderer import ChartRenderer
import os

class DataVisualizationSkill:
    """数据可视化技能主类"""

    def __init__(self, backend: str = 'plotly'):
        """
        初始化技能
        Args:
            backend: 渲染后端 ('plotly', 'matplotlib', 'seaborn')
        """
        self.generator = DataVisualizationGenerator()
        self.renderer = ChartRenderer(backend)
        self.current_data = None
        self.current_config = None

    # 核心数据操作方法
    def load_data(self, source: Union[str, bytes, pd.DataFrame],
                  format_type: str = 'auto', **kwargs) -> Dict[str, Any]:
        """
        加载数据
        Args:
            source: 数据源（文件路径、数据字符串或DataFrame）
            format_type: 数据格式类型
            **kwargs: 额外参数
        Returns:
            操作结果
        """
        try:
            if isinstance(source, pd.DataFrame):
                self.current_data = source
                self.generator.data = source
                self.generator._analyze_fields()
            elif isinstance(source, (str, bytes)):
                if format_type == 'auto':
                    format_type = self._detect_format(source)

                if isinstance(source, str) and os.path.exists(source):
                    success = self.generator.load_data(source, format_type, **kwargs)
                else:
                    success = self.generator.load_data_from_string(source, format_type)

                if not success:
                    return {'success': False, 'error': '数据加载失败'}

            self.current_data = self.generator.data
            return {
                'success': True,
                'summary': self.generator.get_field_summary(),
                'recommendations': self.generator.recommend_chart_types(),
                'quality': self.generator.validate_data_quality()
            }

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _detect_format(self, source: str) -> str:
        """自动检测数据格式"""
        if isinstance(source, str):
            source = source.strip()
            if source.startswith('{') or source.startswith('['):
                return 'json'
            elif '\t' in source:
                return 'tsv'
            elif ',' in source and '\n' in source:
                return 'csv'
            elif source.endswith('.json'):
                return 'json'
            elif source.endswith('.xlsx') or source.endswith('.xls'):
                return 'excel'

        return 'csv'

    def create_visualization(self, chart_type: str, **kwargs) -> Dict[str, Any]:
        """
        创建可视化
        Args:
            chart_type: 图表类型
            **kwargs: 配置参数
        Returns:
            创建结果
        """
        if self.current_data is None:
            return {'success': False, 'error': '请先加载数据'}

        try:
            chart_type_enum = ChartType(chart_type)

            # 智能字段映射
            if not kwargs.get('x_field') and not kwargs.get('y_field'):
                field_mapping = self._auto_map_fields(chart_type_enum)
                kwargs.update(field_mapping)

            # 创建图表配置
            config = self.generator.create_chart_config(chart_type_enum, **kwargs)
            self.current_config = config

            # 渲染图表
            html_output = self.renderer.render_chart(config, self.current_data)

            return {
                'success': True,
                'config': config,
                'html': html_output,
                'field_mapping': kwargs
            }

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _auto_map_fields(self, chart_type: ChartType) -> Dict[str, str]:
        """自动映射字段"""
        mapping = {}
        fields = self.generator.field_info

        # 数值字段
        numerical_fields = [name for name, info in fields.items()
                          if info.data_type.value == 'numerical']

        # 分类字段
        categorical_fields = [name for name, info in fields.items()
                            if info.data_type.value == 'categorical']

        # 时间字段
        temporal_fields = [name for name, info in fields.items()
                         if info.data_type.value == 'temporal']

        if chart_type in [ChartType.SCATTER, ChartType.LINE]:
            if len(numerical_fields) >= 1:
                mapping['y_field'] = numerical_fields[0]
            if len(numerical_fields) >= 2:
                mapping['x_field'] = numerical_fields[1]
            elif len(temporal_fields) >= 1:
                mapping['x_field'] = temporal_fields[0]
            elif len(categorical_fields) >= 1:
                mapping['x_field'] = categorical_fields[0]

        elif chart_type == ChartType.BAR:
            if len(categorical_fields) >= 1:
                mapping['x_field'] = categorical_fields[0]
            if len(numerical_fields) >= 1:
                mapping['y_field'] = numerical_fields[0]

        elif chart_type == ChartType.TREEMAP:
            if len(categorical_fields) >= 1:
                mapping['x_field'] = categorical_fields[0]
            if len(numerical_fields) >= 1:
                mapping['y_field'] = numerical_fields[0]

        # 颜色字段
        if len(categorical_fields) >= 2:
            mapping['color_field'] = categorical_fields[1]

        # 大小字段
        if len(numerical_fields) >= 2:
            mapping['size_field'] = numerical_fields[1]

        return mapping

    def export_visualization(self, format_type: str = 'html',
                           filename: str = None) -> Dict[str, Any]:
        """
        导出可视化
        Args:
            format_type: 导出格式
            filename: 文件名
        Returns:
            导出结果
        """
        if not self.current_config:
            return {'success': False, 'error': '请先创建可视化'}

        try:
            if format_type == 'html':
                html_content = self.renderer.render_chart(
                    self.current_config, self.current_data
                )
                if filename:
                    with open(filename, 'w', encoding='utf-8') as f:
                        f.write(html_content)
                    return {'success': True, 'filename': filename}
                else:
                    return {'success': True, 'content': html_content}

            elif format_type == 'json':
                config_json = json.dumps(self.current_config, indent=2,
                                        ensure_ascii=False)
                if filename:
                    with open(filename, 'w', encoding='utf-8') as f:
                        f.write(config_json)
                    return {'success': True, 'filename': filename}
                else:
                    return {'success': True, 'content': config_json}

            elif format_type in ['png', 'svg', 'pdf']:
                # 使用plotly导出其他格式
                from plotly.subplots import make_subplots
                import plotly.graph_objects as go

                # 重建图表对象
                fig = self._rebuild_figure()
                if fig:
                    exported_content = self.renderer.export_chart(
                        fig, format_type, filename
                    )
                    return {'success': True, 'content': exported_content}

            else:
                return {'success': False, 'error': f'不支持的格式: {format_type}'}

        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _rebuild_figure(self):
        """重建图表对象"""
        # 这里需要根据配置重建plotly图表对象
        # 具体实现取决于图表类型和配置
        return None

    def get_insights(self) -> Dict[str, Any]:
        """获取数据洞察"""
        if self.current_data is None:
            return {'success': False, 'error': '请先加载数据'}

        insights = {
            'data_overview': self.generator.get_field_summary(),
            'quality_report': self.generator.validate_data_quality(),
            'chart_recommendations': self.generator.recommend_chart_types(),
            'patterns': self._detect_patterns()
        }

        return {'success': True, 'insights': insights}

    def _detect_patterns(self) -> List[str]:
        """检测数据模式"""
        patterns = []

        if self.current_data is None:
            return patterns

        # 检测简单的数据模式
        for column in self.current_data.select_dtypes(include=['number']).columns:
            col_data = self.current_data[column].dropna()

            # 检测趋势
            if len(col_data) > 2:
                correlation = col_data.corr(
                    pd.Series(range(len(col_data)))
                )
                if abs(correlation) > 0.7:
                    trend = "上升" if correlation > 0 else "下降"
                    patterns.append(f"{column} 显示明显的{trend}趋势")

            # 检测异常值
            q1 = col_data.quantile(0.25)
            q3 = col_data.quantile(0.75)
            iqr = q3 - q1
            outliers = col_data[(col_data < q1 - 1.5 * iqr) |
                              (col_data > q3 + 1.5 * iqr)]

            if len(outliers) > 0:
                patterns.append(f"{column} 中发现 {len(outliers)} 个异常值")

        return patterns

    def get_supported_chart_types(self) -> List[Dict[str, Any]]:
        """获取支持的图表类型"""
        chart_types = []

        for chart_type in ChartType:
            chart_types.append({
                'id': chart_type.value,
                'name': self._get_chart_name(chart_type),
                'description': self._get_chart_description(chart_type),
                'requirements': self._get_chart_requirements(chart_type)
            })

        return chart_types

    def _get_chart_name(self, chart_type: ChartType) -> str:
        """获取图表类型名称"""
        names = {
            ChartType.SCATTER: '散点图',
            ChartType.BAR: '条形图',
            ChartType.STACKED_BAR: '堆叠条形图',
            ChartType.TREEMAP: '树状图',
            ChartType.SANKEY: '桑基图',
            ChartType.CHORD: '弦图',
            ChartType.CIRCLE_PACKING: '圆形打包图',
            ChartType.LINE: '折线图',
            ChartType.AREA: '面积图',
            ChartType.HEATMAP: '热力图'
        }
        return names.get(chart_type, chart_type.value)

    def _get_chart_description(self, chart_type: ChartType) -> str:
        """获取图表类型描述"""
        descriptions = {
            ChartType.SCATTER: '用于展示两个数值变量之间的关系',
            ChartType.BAR: '用于比较不同类别的数值大小',
            ChartType.STACKED_BAR: '显示各部分在整体中的占比',
            ChartType.TREEMAP: '通过矩形面积展示层次化数据',
            ChartType.SANKEY: '显示流量在不同节点间的流动',
            ChartType.CHORD: '展示实体之间的相互关系和流量',
            ChartType.CIRCLE_PACKING: '通过圆形大小展示层次化数据',
            ChartType.LINE: '展示数据随时间或其他连续变量的变化趋势',
            ChartType.AREA: '在折线图基础上填充区域，强调总量变化',
            ChartType.HEATMAP: '通过颜色深浅展示矩阵数据的数值大小'
        }
        return descriptions.get(chart_type, '')

    def _get_chart_requirements(self, chart_type: ChartType) -> Dict[str, List[str]]:
        """获取图表类型数据要求"""
        requirements = {
            ChartType.SCATTER: {
                'numerical': ['至少1个数值字段（建议2个）'],
                'optional': ['分类字段（用于分组着色）']
            },
            ChartType.BAR: {
                'categorical': ['至少1个分类字段'],
                'numerical': ['至少1个数值字段'],
                'optional': ['第二分类字段（用于分组）']
            },
            ChartType.LINE: {
                'numerical': ['至少1个数值字段'],
                'temporal': ['建议1个时间字段'],
                'optional': ['分类字段（用于多条线）']
            },
            ChartType.HEATMAP: {
                'categorical': ['建议2个分类字段'],
                'numerical': ['至少1个数值字段']
            }
        }

        return requirements.get(chart_type, {'numerical': ['至少1个数值字段']})

# CLI 接口
def main():
    """命令行接口"""
    import argparse

    parser = argparse.ArgumentParser(description='数据可视化生成器')
    parser.add_argument('data_file', help='数据文件路径')
    parser.add_argument('--chart-type', default='bar',
                       choices=[t.value for t in ChartType],
                       help='图表类型')
    parser.add_argument('--output', help='输出文件路径')
    parser.add_argument('--format', default='html',
                       choices=['html', 'json', 'png', 'svg', 'pdf'],
                       help='输出格式')
    parser.add_argument('--backend', default='plotly',
                       choices=['plotly', 'matplotlib', 'seaborn'],
                       help='渲染后端')

    args = parser.parse_args()

    # 创建技能实例
    skill = DataVisualizationSkill(backend=args.backend)

    # 加载数据
    result = skill.load_data(args.data_file)
    if not result['success']:
        print(f"数据加载失败: {result['error']}")
        return

    print("数据加载成功!")
    print(f"数据摘要: {len(skill.current_data)} 行, {len(skill.current_data.columns)} 列")

    # 创建可视化
    viz_result = skill.create_visualization(args.chart_type)
    if not viz_result['success']:
        print(f"可视化创建失败: {viz_result['error']}")
        return

    print("可视化创建成功!")

    # 导出结果
    export_result = skill.export_visualization(
        args.format,
        args.output or f"chart.{args.format}"
    )

    if export_result['success']:
        print(f"图表已导出到: {export_result.get('filename', '内存中')}")
    else:
        print(f"导出失败: {export_result['error']}")

if __name__ == "__main__":
    main()