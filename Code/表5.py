# -*- coding: utf-8 -*-
"""
Created on Sat Nov 23 00:32:49 2024

@author: Lenovo
"""

import pandas as pd

# 文件路径
input_path = r"D:\python\Machine Forecast Disagreement\data\table6_median.xlsx"  # 输入文件路径
hl_output_path = r"D:\python\Machine Forecast Disagreement\data\table6_t.xlsx"  # H-L 输出文件路径
avg_output_path = r"D:\python\Machine Forecast Disagreement\data\table6_avg.xlsx"  # 清理后均值输出文件路径

# 读取 Excel 数据
data = pd.read_excel(input_path)

# 确保时间列格式正确
data['time'] = pd.to_datetime(data['time'])

# 初始化一个 DataFrame 用于存储 H-L 结果
hl_results = pd.DataFrame()

# 定义需要计算 H-L 的因子
factors = [
    "mfd_median", "sue_median", "ag_median", "mom_median", "illiq_median", "op_median",
    "ivol_median", "beta_median", "size_median", "bm_median", "max_median",
    "turn_median", "str_median"
]

# 按时间分组，计算每个因子的 H-L 值
for time, group in data.groupby('time'):
    # 存储当前时间的 H-L 结果
    hl_row = {'time': time}
    
    for factor in factors:
        # 找到 decile_mfd 为 1 和 10 的因子值
        low_value = group.loc[group['decile_mfd'] == 1, factor].mean()
        high_value = group.loc[group['decile_mfd'] == 10, factor].mean()
        
        # 计算 H-L 并存储
        hl_row[factor.replace('_median', '_hl')] = high_value - low_value
    
    # 添加到 H-L 结果 DataFrame 中
    hl_results = hl_results.concat(hl_row, ignore_index=True)

# 保存 H-L 结果为新的 Excel 文件
hl_results.to_excel(hl_output_path, index=False)

# 计算每个因子在不同分组上的均值
# 将列 "1" 重命名为 "Low"，列 "10" 重命名为 "High"
data = data.rename(columns={"1": "Low", "10": "High"})

# 计算因子在时间序列上的均值
avg_results = pd.DataFrame(columns=["Low", "2", "3", "4", "5", "6", "7", "8", "9", "High"], index=factors)

for factor in factors:
    for decile in range(1, 11):  # Decile group 1 to 10
        # 计算每个 decile_mfd 分组在时间序列上的均值
        avg_results.loc[factor, str(decile)] = data.loc[data['decile_mfd'] == decile, factor].mean()

# 保存均值结果为新的 Excel 文件
avg_results.to_excel(avg_output_path)

print(f"H-L 数据已保存到 {hl_output_path}")
print(f"因子均值数据已保存到 {avg_output_path}")
