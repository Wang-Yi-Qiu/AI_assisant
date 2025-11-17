#!/usr/bin/env python3
"""
数据可视化生成器核心模块
基于 RawGraphs 理念的智能数据可视化工具
"""

import pandas as pd
import numpy as np
import json
import csv
import io
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

class ChartType(Enum):
    """支持的图表类型枚举"""
    SCATTER = "scatter"
    BAR = "bar"
    STACKED_BAR = "stacked_bar"
    TREEMAP = "treemap"
    SANKEY = "sankey"
    CHORD = "chord"
    CIRCLE_PACKING = "circle_packing"
    LINE = "line"
    AREA = "area"
    HEATMAP = "heatmap"

class DataType(Enum):
    """数据类型枚举"""
    NUMERICAL = "numerical"
    CATEGORICAL = "categorical"
    TEMPORAL = "temporal"
    BOOLEAN = "boolean"

@dataclass
class FieldInfo:
    """字段信息数据类"""
    name: str
    data_type: DataType
    unique_count: int
    missing_count: int
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    sample_values: List[Any] = None

@dataclass
class ChartConfig:
    """图表配置数据类"""
    chart_type: ChartType
    x_field: Optional[str] = None
    y_field: Optional[str] = None
    color_field: Optional[str] = None
    size_field: Optional[str] = None
    group_field: Optional[str] = None
    width: int = 800
    height: int = 600
    color_scheme: str = "category10"
    title: str = ""
    interactive: bool = True

class DataVisualizationGenerator:
    """数据可视化生成器主类"""

    def __init__(self):
        self.data = None
        self.field_info = {}
        self.supported_formats = ['csv', 'tsv', 'json', 'excel']

    def load_data(self, source: str, format_type: str = 'csv', **kwargs) -> bool:
        """
        加载数据
        Args:
            source: 数据源（文件路径或数据字符串）
            format_type: 数据格式类型
            **kwargs: 额外参数
        Returns:
            bool: 加载是否成功
        """
        try:
            if format_type == 'csv':
                self.data = pd.read_csv(source, **kwargs)
            elif format_type == 'tsv':
                self.data = pd.read_csv(source, sep='\t', **kwargs)
            elif format_type == 'json':
                self.data = pd.read_json(source, **kwargs)
            elif format_type == 'excel':
                self.data = pd.read_excel(source, **kwargs)
            else:
                raise ValueError(f"Unsupported format: {format_type}")

            self._analyze_fields()
            return True
        except Exception as e:
            print(f"Error loading data: {e}")
            return False

    def load_data_from_string(self, data_string: str, format_type: str = 'csv') -> bool:
        """从字符串加载数据"""
        try:
            if format_type == 'csv':
                self.data = pd.read_csv(io.StringIO(data_string))
            elif format_type == 'json':
                self.data = pd.read_json(io.StringIO(data_string))
            else:
                raise ValueError(f"String loading only supports CSV and JSON")

            self._analyze_fields()
            return True
        except Exception as e:
            print(f"Error loading data from string: {e}")
            return False

    def _analyze_fields(self):
        """分析数据字段类型和统计信息"""
        self.field_info = {}

        for column in self.data.columns:
            series = self.data[column]
            field_info = FieldInfo(
                name=column,
                data_type=self._detect_data_type(series),
                unique_count=series.nunique(),
                missing_count=series.isnull().sum(),
                sample_values=series.dropna().head(5).tolist()
            )

            if field_info.data_type == DataType.NUMERICAL:
                field_info.min_value = series.min()
                field_info.max_value = series.max()

            self.field_info[column] = field_info

    def _detect_data_type(self, series: pd.Series) -> DataType:
        """检测字段数据类型"""
        # 检查是否为数值型
        if pd.api.types.is_numeric_dtype(series):
            return DataType.NUMERICAL

        # 检查是否为时间型
        if pd.api.types.is_datetime64_any_dtype(series):
            return DataType.TEMPORAL

        # 检查是否为布尔型
        if series.dtype == 'bool':
            return DataType.BOOLEAN

        # 检查唯一值比例
        unique_ratio = series.nunique() / len(series)
        if unique_ratio < 0.1 and series.nunique() <= 50:
            return DataType.CATEGORICAL

        # 默认为分类变量
        return DataType.CATEGORICAL

    def get_field_summary(self) -> Dict[str, Any]:
        """获取字段摘要信息"""
        if not self.field_info:
            return {}

        summary = {
            'total_rows': len(self.data),
            'total_columns': len(self.data.columns),
            'fields': {}
        }

        for field_name, info in self.field_info.items():
            summary['fields'][field_name] = {
                'type': info.data_type.value,
                'unique_count': info.unique_count,
                'missing_count': info.missing_count,
                'min_value': info.min_value,
                'max_value': info.max_value,
                'sample_values': info.sample_values
            }

        return summary

    def recommend_chart_types(self) -> List[Tuple[ChartType, float, str]]:
        """
        推荐适合的图表类型
        Returns:
            List of (ChartType, score, reason)
        """
        if not self.field_info:
            return []

        recommendations = []
        numerical_fields = [f for f in self.field_info.values() if f.data_type == DataType.NUMERICAL]
        categorical_fields = [f for f in self.field_info.values() if f.data_type == DataType.CATEGORICAL]

        # 散点图推荐
        if len(numerical_fields) >= 2:
            recommendations.append((ChartType.SCATTER, 0.9, "适合展示两个数值变量的关系"))

        # 条形图推荐
        if len(categorical_fields) >= 1 and len(numerical_fields) >= 1:
            recommendations.append((ChartType.BAR, 0.85, "适合比较不同类别的数值"))

        # 折线图推荐（如果有时间字段）
        temporal_fields = [f for f in self.field_info.values() if f.data_type == DataType.TEMPORAL]
        if temporal_fields and len(numerical_fields) >= 1:
            recommendations.append((ChartType.LINE, 0.9, "适合展示时间序列趋势"))

        # 热力图推荐
        if len(categorical_fields) >= 2 and len(numerical_fields) >= 1:
            recommendations.append((ChartType.HEATMAP, 0.8, "适合展示两个分类变量的交叉数据"))

        # 树状图推荐
        if len(categorical_fields) >= 2 and len(numerical_fields) >= 1:
            recommendations.append((ChartType.TREEMAP, 0.75, "适合展示层次化数据"))

        # 按分数排序
        recommendations.sort(key=lambda x: x[1], reverse=True)
        return recommendations

    def create_chart_config(self, chart_type: ChartType, **kwargs) -> Dict[str, Any]:
        """
        创建图表配置
        Args:
            chart_type: 图表类型
            **kwargs: 配置参数
        Returns:
            图表配置字典
        """
        config = {
            'type': chart_type.value,
            'width': kwargs.get('width', 800),
            'height': kwargs.get('height', 600),
            'data': self._prepare_chart_data(chart_type, **kwargs),
            'encoding': self._create_encoding(chart_type, **kwargs),
            'config': {
                'colorScheme': kwargs.get('color_scheme', 'category10'),
                'title': kwargs.get('title', ''),
                'interactive': kwargs.get('interactive', True)
            }
        }

        return config

    def _prepare_chart_data(self, chart_type: ChartType, **kwargs) -> List[Dict]:
        """准备图表数据"""
        data_records = self.data.to_dict('records')

        # 根据图表类型进行数据预处理
        if chart_type in [ChartType.TREEMAP, ChartType.SANKEY]:
            # 对于层次化图表，可能需要特殊的数据结构
            return self._prepare_hierarchical_data(chart_type, **kwargs)

        return data_records

    def _prepare_hierarchical_data(self, chart_type: ChartType, **kwargs) -> List[Dict]:
        """准备层次化数据结构"""
        # 这里实现层次化数据的转换逻辑
        # 具体实现取决于图表类型的需求
        return self.data.to_dict('records')

    def _create_encoding(self, chart_type: ChartType, **kwargs) -> Dict[str, Any]:
        """创建视觉编码配置"""
        encoding = {}

        # 基于图表类型和字段信息创建编码
        if chart_type in [ChartType.SCATTER, ChartType.LINE]:
            encoding.update({
                'x': {'field': kwargs.get('x_field'), 'type': 'quantitative'},
                'y': {'field': kwargs.get('y_field'), 'type': 'quantitative'}
            })

        if chart_type == ChartType.BAR:
            encoding.update({
                'x': {'field': kwargs.get('x_field'), 'type': 'nominal'},
                'y': {'field': kwargs.get('y_field'), 'type': 'quantitative'}
            })

        # 添加颜色编码
        if kwargs.get('color_field'):
            encoding['color'] = {'field': kwargs['color_field'], 'type': 'nominal'}

        # 添加大小编码
        if kwargs.get('size_field'):
            encoding['size'] = {'field': kwargs['size_field'], 'type': 'quantitative'}

        return encoding

    def export_chart(self, config: Dict[str, Any], format_type: str = 'svg',
                    filename: str = None) -> str:
        """
        导出图表
        Args:
            config: 图表配置
            format_type: 导出格式
            filename: 文件名
        Returns:
            导出文件的路径或内容
        """
        # 这里需要实现实际的图表生成和导出逻辑
        # 可以使用 matplotlib, plotly,或者其他图表库

        if not filename:
            filename = f"chart.{format_type}"

        # 模拟导出过程
        export_info = {
            'config': config,
            'format': format_type,
            'filename': filename,
            'timestamp': pd.Timestamp.now().isoformat()
        }

        return json.dumps(export_info, indent=2)

    def validate_data_quality(self) -> Dict[str, Any]:
        """验证数据质量"""
        issues = []
        warnings = []

        if self.data is None:
            return {'valid': False, 'issues': ['No data loaded']}

        # 检查数据完整性
        total_cells = len(self.data) * len(self.data.columns)
        missing_cells = self.data.isnull().sum().sum()
        missing_ratio = missing_cells / total_cells

        if missing_ratio > 0.5:
            issues.append(f"高缺失率: {missing_ratio:.1%}")
        elif missing_ratio > 0.1:
            warnings.append(f"中度缺失率: {missing_ratio:.1%}")

        # 检查数据量
        if len(self.data) < 10:
            warnings.append("数据量较少，可能影响可视化效果")
        elif len(self.data) > 100000:
            warnings.append("数据量较大，可能影响性能")

        # 检查字段类型
        for field_name, field_info in self.field_info.items():
            if field_info.missing_count > len(self.data) * 0.8:
                issues.append(f"字段 {field_name} 缺失率过高")

        return {
            'valid': len(issues) == 0,
            'issues': issues,
            'warnings': warnings,
            'summary': {
                'rows': len(self.data),
                'columns': len(self.data.columns),
                'missing_ratio': missing_ratio,
                'numerical_fields': len([f for f in self.field_info.values()
                                      if f.data_type == DataType.NUMERICAL]),
                'categorical_fields': len([f for f in self.field_info.values()
                                         if f.data_type == DataType.CATEGORICAL])
            }
        }

# 使用示例
if __name__ == "__main__":
    # 创建可视化生成器实例
    viz_gen = DataVisualizationGenerator()

    # 示例数据
    sample_data = """name,category,value,year
产品A,电子,1200,2023
产品B,服装,800,2023
产品C,食品,600,2023
产品A,电子,1500,2024
产品B,服装,950,2024
产品C,食品,720,2024"""

    # 加载数据
    if viz_gen.load_data_from_string(sample_data, 'csv'):
        print("数据加载成功!")

        # 获取字段摘要
        summary = viz_gen.get_field_summary()
        print("字段摘要:", json.dumps(summary, indent=2, ensure_ascii=False))

        # 获取图表推荐
        recommendations = viz_gen.recommend_chart_types()
        print("\n推荐的图表类型:")
        for chart_type, score, reason in recommendations:
            print(f"  {chart_type.value}: {score:.2f} - {reason}")

        # 验证数据质量
        quality = viz_gen.validate_data_quality()
        print("\n数据质量验证:", json.dumps(quality, indent=2, ensure_ascii=False))

        # 创建条形图配置
        config = viz_gen.create_chart_config(
            ChartType.BAR,
            x_field='category',
            y_field='value',
            title='产品类别销售对比'
        )

        print("\n图表配置:", json.dumps(config, indent=2, ensure_ascii=False))