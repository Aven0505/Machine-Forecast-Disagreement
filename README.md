# Machine-Forecast-Disagreement
本文复刻了Turan G.Bali等人提出的《Machine Forecast Disagreement》一文，通过中国A股市场2002至2024年的股票特征数据，验证机器预测分歧（MFD）对未来股票回报的预测能力。我们使用国泰安（CSMAR）数据库和中国债券信息网获取数据，并基于LightGBM算法构建MFD指标。研究内容包括数据处理、描述性统计、单变量分组分析、双变量投资组合分析以及Fama-MacBeth横截面回归分析。结果表明，MFD与未来股票回报存在显著负相关性在中国市场依然成立，且在控制传统因子后依然稳健，进一步验证了MFD作为衡量投资者信念分歧的新指标的有效性。

请用stata打开code.do文件，里面是主要的code。其中有一些表格的code用的语言不是stata而是python，在do文件里有注释说明.
构建MFD.py文件是使用LightGBM模型跑出MFD的代码，里面设置多核运行（数值为10），请自行修改。
