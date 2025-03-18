# -*- coding: utf-8 -*-
"""
Created on Sat Nov 16 21:26:06 2024

@author: Lenovo
"""
# -*- coding: utf-8 -*-

import os
import numpy as np
import pandas as pd
import random
import warnings
import lightgbm as lgb
from concurrent.futures import ThreadPoolExecutor, as_completed

random.seed(42)
warnings.filterwarnings("ignore")

path = r'E:\大三上'
os.chdir(path)

# 确保保存结果的文件夹存在
output_path = os.path.join(path, 'mfd因子')
os.makedirs(output_path, exist_ok=True)

# 定义一个函数来随机选择50列
def extract_random_columns(dataframe, num_cols, num_iterations):
    all_columns = dataframe.columns.tolist()[3:]
    random_column_lists = []
    
    for _ in range(num_iterations):
        selected_columns = random.sample(all_columns, num_cols)
        random_column_lists.append(selected_columns)
    
    return random_column_lists

def train_model(params, lgb_train, select_feature, train_data):
    # 准备训练数据
    x_train = np.array(train_data[select_feature])  # 训练集 输入
    y_train = np.array(train_data['ret'])  # 训练集 输出
    lgb_train = lgb.Dataset(x_train, y_train)  # 创建LightGBM训练集
    
    # 训练模型
    model = lgb.train(params, lgb_train, valid_sets=[lgb_train], callbacks=[lgb.early_stopping(30)])
    return model

def calculate_mdf(ch, random_column_selections, trw, viw, tew, param=None):
    # 滑动窗口的月份列表
    month_list = sorted(list(set(ch['month'])))
    mfd_temp = []

    for i in range(len(month_list) - trw - viw):
        print(f"Processing month {i + 1}/{len(month_list) - trw - viw}")  # 当前处理的进度
        
        month_train_start = month_list[i]
        month_train_end = month_list[i + trw - 1]
        month_valid_start = month_list[i + trw]
        month_valid_end = month_list[i + trw + viw - 1]        
        month_test = month_list[i + trw + viw]
        
        # 划分训练集、验证集、测试集
        train_data = ch[(ch['month'] >= month_train_start) & (ch['month'] <= month_train_end)].iloc[:, 2:]
        test_data = ch[ch['month'] == month_test].iloc[:, 2:]
        
        stk_pool = ch[ch['month'] == month_test]['stkcd'].to_list()
        
        # 使用ThreadPoolExecutor并行化训练
        predict = []
        with ThreadPoolExecutor(max_workers=10) as executor:  # 根据CPU核心数调整max_workers
            futures = []
            for j in range(len(random_column_selections)):
                select_feature = random_column_selections[j]
                futures.append(executor.submit(train_model, param, None, select_feature, train_data))
            
            for future in as_completed(futures):
                model = future.result()
                y_pred = model.predict(np.array(test_data[random_column_selections[0]]))  # 预测
                predict.append(y_pred)
        
        # 计算每月的标准化因子
        y_pred = pd.DataFrame(predict, columns=stk_pool)
        y_pred_std = 1 / y_pred.std(axis=0)
        
        # 保存当前月份的 mfd 并输出
        mfd_temp.append(y_pred_std)
        print(f"Month {month_test} MFD:\n{y_pred_std.head()}")  # 输出每月 MFD 的前几行
        y_pred_std.to_csv(os.path.join(output_path, f'mfd_{month_test}.csv'))  # 保存到文件
        
    # 汇总所有月份的结果
    mfd_df = pd.concat(mfd_temp, axis=1).T
    mfd_df.index = month_list[trw + viw:]
    return mfd_df

# %% 启动程序
if __name__ == '__main__':
    start_month = 200001  # 回测开始年份
    end_month = 202409  # 回测结束年份

    # 读取数据
    ch = pd.read_parquet(os.path.join(path, 'char_clean.parquet'))
    ch = ch.sort_values(by=['month', 'stkcd'], ascending=True)
    ch = ch[(ch['month'] >= start_month) & (ch['month'] <= end_month)]

    # 随机选取特征
    feature_num = 25
    cycle_num = 100    
    random_feature = extract_random_columns(ch, feature_num, cycle_num)
    
    # 训练集、验证集、测试集的长度
    trw = 12
    viw = 0  # 暂时未考虑验证集
    tew = 1
    
    mfd_df_lgb = calculate_mdf(ch, random_feature, trw, viw, tew, param={'n_estimators': 1000, 'learning_rate': 0.001})
    mfd_df_lgb.to_parquet(os.path.join(output_path, 'mfd_lgb.parquet'))
    print('lgb finished')