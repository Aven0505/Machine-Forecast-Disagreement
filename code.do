clear all
set more off

** Preparation
**************************************************************************
global data "D:\第四组-Machine Forecast Disagreement\data" 
global path "D:\第四组-Machine Forecast Disagreement\results" 
use "$data\sample data.dta", clear
ssc install estout
ssc install outreg2
ssc install egenmore

** Table 1 描述性统计
**************************************************************************
* 见code\table1.ipynb


** Table 2 相关系数矩阵
**************************************************************************
* 见code\table2.ipynb



** Table 3 等权及流动市值加权单变量分组回归
**************************************************************************
**************等权单变量分组***
use "$data\sample data.dta", clear

drop if excess_ret==.
bysort time: drop if _N<100
xtset stock time

drop if mfd==.
egen mfd_decile = xtile(mfd), by(time) n(10)

sort time mfd_decile

* 按时间和分组计算平均回报
collapse (mean) excess_ret mkt smb hml umd rmw cma, by(time mfd_decile)
* 转换为 wide 格式
reshape wide excess_ret, i(time) j(mfd_decile)

gen id = _n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	newey excess_ret`i', lag(12)
    outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(Excess Return, Decile `i')
}

foreach i of numlist 1/10 {
	* CAPM 模型回归
	newey excess_ret`i' rm, lag(12)
    outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CAPM, Decile `i')
}

foreach i of numlist 1/10 {
	* FF3 因子回归
    newey excess_ret`i' mkt smb hml, lag(12)
    outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF3 alpha, Decile `i')
}

foreach i of numlist 1/10 {
	* FF4 因子回归：在 FF3 基础上加入 UMD 因子
    newey excess_ret`i' mkt smb hml umd, lag(12)
    outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CH4 alpha, Decile `i')
}

foreach i of numlist 1/10 {
	 * FF5 因子回归：在 FF4 基础上删去UMD因子，加入 RMW 和 CMA 因子
    newey excess_ret`i' mkt smb hml rmw cma, lag(12)
    outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}


* 5. 计算 mfd_decile=10 和 mfd_decile=1 的等权超额收益差异
gen dexret = excess_ret10 - excess_ret1
newey dexret, lag(12)
outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(uni h-l)
newey dexret rm, lag(12)
outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CAPM alpha)
newey dexret mkt smb hml, lag(12)
outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF3 alpha)
newey dexret mkt smb hml umd, lag(12)
outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CH4 alpha)
newey dexret mkt smb hml rmw cma, lag(12)
outreg2 using "$path\Table3_equal.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF5 alpha)


**************流动市值加权单变量分组***
use "$data\sample data.dta", clear

drop if excess_ret==.
bysort time: drop if _N<100
xtset stock time

drop if mfd==.
egen mfd_decile = xtile(mfd), by(time) n(10)

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
bysort time mfd_decile: egen weight_sum = total(size) 
gen weight = size/weight_sum 

sort stock time
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}

* 2. 计算市值加权超额收益
bysort time mfd_decile: gen weighted_excess_ret = weight_lag * excess_ret
bysort time mfd_decile: egen exret_vw = total(weighted_excess_ret) 
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma, by(time mfd_decile)
* 转换为 wide 格式
reshape wide exret_vw, i(time) j(mfd_decile)

gen id = _n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	newey exret_vw`i', lag(12)
    outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(Excess Return, Decile `i')
}

foreach i of numlist 1/10 {
	* CAPM 模型回归
	newey exret_vw`i' rm, lag(12)
    outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CAPM, Decile `i')
}

foreach i of numlist 1/10 {
	* FF3 因子回归
    newey exret_vw`i' mkt smb hml, lag(12)
    outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF3 alpha, Decile `i')
}

foreach i of numlist 1/10 {
	* FF4 因子回归：在 FF3 基础上加入 UMD 因子
    newey exret_vw`i' mkt smb hml umd, lag(12)
    outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CH4 alpha, Decile `i')
}

foreach i of numlist 1/10 {
	 * FF5 因子回归：在 FF4 基础上删去UMD因子，加入 RMW 和 CMA 因子
    newey exret_vw`i' mkt smb hml rmw cma, lag(12)
    outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF5 alpha, Decile `i')
}


* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
newey dexret_vw, lag(12)
outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(uni h-l)
newey dexret_vw rm, lag(12)
outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CAPM alpha)
newey dexret_vw mkt smb hml, lag(12)
outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF3 alpha)
newey dexret_vw mkt smb hml umd, lag(12)
outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(CH4 alpha)
newey dexret_vw mkt smb hml rmw cma, lag(12)
outreg2 using "$path\Table3_valuedweighted.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(2) bdec(2) append ctitle(FF5 alpha)



** Table 4 转移矩阵
**************************************************************************
use "$data\sample data.dta", clear
xtset stock time
egen decile_t = xtile(mfd), by(time) nq(10)
sort stock time
* 生成 decile_t12 变量，包含后12个月的 decile_t 值
gen decile_t12 = .
* 通过 forval 循环将每个 stock 下的 decile_t向下移动12行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace decile_t12 = decile_t[_n-12] if stock == `s'
	}
}

tabulate decile_t decile_t12, matcell(P)

matrix list P
local rows = rowsof(P)
local cols = colsof(P)

forval i = 1/`rows' {
    local row_sum = 0
    forval j = 1/`cols' {
        local row_sum = `row_sum' + P[`i', `j']
    }
    forval j = 1/`cols' {
        matrix P[`i', `j'] = P[`i', `j'] / `row_sum' * 100
    }
}

matrix list P

putexcel set "$path\table4.xls", replace
putexcel A1 = matrix(P)



** Table 5 MFD分组股票特征
**************************************************************************
use "$data\sample data.dta", clear
xtset stock time
* 1. 按月计算 MFD 的十分位分组
egen decile_mfd = xtile(mfd), by(time) nq(10)

* 2. 计算每个变量的横截面中位数
egen mfd_median = median(mfd), by(time decile_mfd)
egen sue_median = median(sue), by(time decile_mfd)
egen ag_median = median(ag), by(time decile_mfd)
egen mom_median = median(mom), by(time decile_mfd)
egen illiq_median = median(illiq), by(time decile_mfd)
egen op_median = median(op), by(time decile_mfd)
egen ivol_median = median(ivol), by(time decile_mfd)
egen beta_median = median(beta), by(time decile_mfd)
egen size_median = median(size), by(time decile_mfd)
egen bm_median = median(bm), by(time decile_mfd)
egen max_median = median(max), by(time decile_mfd)
egen turn_median = median(turn), by(time decile_mfd)
egen str_median = median(str), by(time decile_mfd)

* 保存中位数数据为 table5_median.dta
*  计算每组中位数的均值并保存为 table61.dta
collapse(mean) mfd_median sue_median ag_median mom_median illiq_median op_median ///
    ivol_median beta_median size_median bm_median max_median turn_median ///
    str_median,by(time decile_mfd)
save "$data\table5_median.dta", replace
*接下来把table5_median.dta里的数据手动粘贴到table5_median.xlsx中用python代码计算H-L、计算median时间序列上的均值
*见table5.py文件，分别生成avg.xlsx储存均值，生成table5_t.xlsx储存H-L
*把table5_t.xlsx里的数据手动粘贴到table5_t.dta中，用来计算t值，看显著性
*算t值看显著性
* 1. 读取时间序列数据
use "$data\table5_t.dta", clear

gen id = _n  // 创建顺序编号
tsset id  // 使用 id 来设定面板数据结构

* 2. 定义需要回归的变量列表
local vars mfd_hl sue_hl ag_hl mom_hl illiq_hl op_hl ivol_hl beta_hl size_hl bm_hl max_hl turn_hl str_hl

* 3. 创建一个新的数据集存储结果
gen Variable = ""
gen Coef = .
gen t_stat = .
gen Sig = ""

* 4. 回归每个变量并提取结果
local row = 1
foreach var of local vars {
    newey `var', lag(1)
    
    * 提取系数和 t 值
    scalar coef = _b[_cons]
    scalar tstat = _b[_cons] / _se[_cons]
        * 计算 p 值
    scalar pval = 2 * ttail(e(df_r), abs(tstat))
    
    * 动态生成显著性符号
    local sig = ""  // 初始化 sig
    if (pval < 0.01) {
        local sig = "***"
    }
    else if (pval < 0.05) {
        local sig = "**"
    }
    else if (pval < 0.1) {
        local sig = "*"
    }
    * 将结果填入新数据集
    replace Variable = "`var'" in `row'
    replace Coef = coef in `row'
    replace t_stat = tstat in `row'
	replace Sig = "`sig'" in `row'  // 确保这里是字符串变量
    
    * 更新行号
    local ++row

}

* 6. 保存结果到 dta 文件
save "$path\table5_result.dta", replace



** Table 6 双变量投资组合分析
**************************************************************************
**************等权双变量分组————AG**********
use "$data\sample data.dta", clear

drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen ag_quintile = xtile(ag_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time ag_quintile) n(10)
drop if ag_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11AG.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12AG.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13AG.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————beta**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen beta_quintile = xtile(beta_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time beta_quintile) n(10)
drop if beta_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11BETA.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12BETA.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13BETA.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————BM**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen bm_quintile = xtile(bm_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time bm_quintile) n(10)
drop if bm_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————ILLIQ**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen illiq_quintile = xtile(illiq_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time illiq_quintile) n(10)
drop if illiq_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11ILLIQ.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12ILLIQ.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13ILLIQ.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————IVOL**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen ivol_quintile = xtile(ivol_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time ivol_quintile) n(10)
drop if ivol_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11IVOL.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12IVOL.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13IVOL.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————MAX**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen max_quintile = xtile(max_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time max_quintile) n(10)
drop if max_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————MOM**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen mom_quintile = xtile(mom_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time mom_quintile) n(10)
drop if mom_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————OP**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen op_quintile = xtile(op), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time op_quintile) n(10)
drop if op_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11OP.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12OP.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13OP.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————SIZE**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen size_quintile = xtile(size_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time size_quintile) n(10)
drop if size_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11SIZE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12SIZE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13SIZE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————STR**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen str_quintile = xtile(str_std), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time str_quintile) n(10)
drop if str_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————SUE**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen sue_quintile = xtile(op), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time sue_quintile) n(10)
drop if sue_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11SUE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12SUE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13SUE.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************等权双变量分组————TURN**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

generate excess_retnew=excess_ret/10

egen turn_quintile = xtile(op), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time turn_quintile) n(10)
drop if turn_quintile==.

* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}

* 按时间和分组计算平均回报
collapse (mean) excess_retnew mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile

* 执行 reshape wide命令
reshape wide excess_retnew ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)

gen id=_n
tsset id

* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey excess_retnew`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_11TURN.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}

* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = excess_retnew10 - excess_retnew1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_12TURN.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_13TURN.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————AG**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen ag_quintile = xtile(ag), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time ag_quintile) n(10)
drop if ag_quintile==.
bysort time ag_quintile mfd_decile: egen weight_sum = total(size)
bysort time ag_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time ag_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21ag.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22ag.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23ag.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————BM**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen bm_quintile = xtile(bm), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time bm_quintile) n(10)
drop if bm_quintile==.
bysort time bm_quintile mfd_decile: egen weight_sum = total(size)
bysort time bm_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time bm_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23bm.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————ILLIQ**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen illiq_quintile = xtile(illiq), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time illiq_quintile) n(10)
drop if illiq_quintile==.
bysort time illiq_quintile mfd_decile: egen weight_sum = total(size)
bysort time illiq_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time illiq_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21illiq.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22illiq.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23illiq.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————SIZE**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen size_quintile = xtile(size), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time size_quintile) n(10)
drop if size_quintile==.
bysort time size_quintile mfd_decile: egen weight_sum = total(size)
bysort time size_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time size_quintile mfd_decile: gen exret_vw = weight_lag * excess_retnew
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21size.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22size.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23size.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————BETA**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen beta_quintile = xtile(beta), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time beta_quintile) n(10)
drop if beta_quintile==.
bysort time beta_quintile mfd_decile: egen weight_sum = total(size)
bysort time beta_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time beta_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21beta.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22beta.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23beta.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————IVOL**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen ivol_quintile = xtile(ivol), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time ivol_quintile) n(10)
drop if ivol_quintile==.
bysort time ivol_quintile mfd_decile: egen weight_sum = total(size)
bysort time ivol_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time ivol_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21ivol.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22ivol.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23ivol.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————MAX**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time
* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen max_quintile = xtile(max), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time max_quintile) n(10)
drop if max_quintile==.
bysort time max_quintile mfd_decile: egen weight_sum = total(size)
bysort time max_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time max_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23max.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————MOM**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen mom_quintile = xtile(mom), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time mom_quintile) n(10)
drop if mom_quintile==.
bysort time mom_quintile mfd_decile: egen weight_sum = total(size)
bysort time mom_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time mom_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23mom.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————OP**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time
*********SUE********
* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen op_quintile = xtile(op), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time op_quintile) n(10)
drop if op_quintile==.
bysort time op_quintile mfd_decile: egen weight_sum = total(size)
bysort time op_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time op_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21op.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22op.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23op.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————STR**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time
* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen str_quintile = xtile(str), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time str_quintile) n(10)
drop if str_quintile==.
bysort time str_quintile mfd_decile: egen weight_sum = total(size)
bysort time str_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time str_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23str.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————SUE**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time
* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen sue_quintile = xtile(sue), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time sue_quintile) n(10)
drop if sue_quintile==.
bysort time sue_quintile mfd_decile: egen weight_sum = total(size)
bysort time sue_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
* 创建 lagged weight，并使用 forval 循环将每个 mfd_decile 下的 weight向上移动一行
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time sue_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21sue.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22sue.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23sue.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)

**************市值加权双变量分组————TURN**********
use "$data\sample data.dta", clear
drop if excess_ret==.
bysort time: drop if _N<100
tsset stock time

* 1. 对每个时期和 mfd_decile 分组，并计算每组在 t期的市值总和（size）
egen turn_quintile = xtile(turn), by(time) n(5)
egen mfd_decile = xtile(mfd), by(time turn_quintile) n(10)
drop if turn_quintile==.
bysort time turn_quintile mfd_decile: egen weight_sum = total(size)
bysort time turn_quintile mfd_decile: gen weight = size/weight_sum
* 保存原始排序，以便后续恢复
gen original_order = _n
* 按公司（stock）和时间（time）排序，以确保每家公司按时间排序
sort stock time
gen weight_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace weight_lag = weight[_n+1] if stock == `s'
	}
}
* 2. 计算市值加权超额收益
bysort time turn_quintile mfd_decile: gen exret_vw = weight_lag * excess_ret
*  恢复原始排序
sort original_order
* 删除临时变量
drop original_order
* 填充缺失值为0（在collapse之前）
foreach var in ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std {
    replace `var' = 0 if `var' == .
}
* 按时间和分组计算平均回报
collapse (mean) exret_vw mkt smb hml umd rmw cma ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, by(time mfd_decile)
sort time mfd_decile
* 执行 reshape wide转换
reshape wide exret_vw ivol_std ag_std bm_std size_std turn_std str_std beta_std mom_std sue_std op_std illiq_std max_std, i(time) j(mfd_decile)
gen id=_n
tsset id
* 3. 循环进行回归分析并导出结果
foreach i of numlist 1/10 {
	* FF5 因子回归：在 FF4 基础上加入 RMW 和 CMA 因子
    newey exret_vw`i' ag_std`i' mom_std`i' illiq_std`i' op_std`i' ivol_std`i' beta_std`i' size_std`i' bm_std`i' max_std`i' str_std`i' sue_std`i',lag(12)
    outreg2 using "$path\table6_21turn.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha, Decile `i')
}
* 5. 计算 mfd_decile=10 和 mfd_decile=1 的市值加权超额收益差异
gen dexret_vw = exret_vw10 - exret_vw1
gen dexag_std = ag_std10-ag_std1
gen dexmom_std = mom_std10-mom_std1
gen dexilliq_std = illiq_std10-illiq_std1
gen dexop_std = op_std10-op_std1
gen dexivol_std = ivol_std10-ivol_std1
gen dexbeta_std = beta_std10-beta_std1
gen dexsize_std = size_std10-size_std1
gen dexbm_std = bm_std10-bm_std1
gen dexmax_std = max_std10-max_std1
gen dexstr_std = str_std10-str_std1
gen dexsue_std = sue_std10-sue_std1
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std,lag(12)
outreg2 using "$path\table6_22turn.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)
newey dexret_vw dexag_std dexmom_std dexilliq_std dexop_std dexivol_std dexbeta_std dexsize_std dexbm_std dexmax_std dexstr_std dexsue_std mkt smb hml rmw cma,lag(12)
outreg2 using "$path\table6_23turn.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF5 alpha)



** Table 7 Fama-MacBeth回归
**************************************************************************
use "$data\sample data.dta", clear
* 设置面板数据格式
xtset stock time
sort stock time
gen excess_ret_lag = .
* 通过 forval 循环将每个 stock 下的 weight向上移动一行
quietly levelsof stock, local(stocks)
foreach s of local stocks{
	quietly{
	bysort stock (time): replace excess_ret_lag = excess_ret[_n+1] if stock == `s'
	}
}
replace excess_ret_lag =excess_ret_lag/10

xtset stock time
eststo model1: asreg excess_ret_lag mfd beta_std size_std bm_std mom_std, fmb by(time)
eststo model2: asreg excess_ret_lag mfd beta_std size_std bm_std mom_std ag_std op_std, fmb by(time)
eststo model3: asreg excess_ret_lag mfd beta_std size_std bm_std mom_std ag_std op_std sue_std illiq_std ivol_std max_std turn_std str_std, fmb by(time)
using "$path\table7.rtf", replace ///
    title("{\qc Table 7: Fama-MacBeth Cross-Sectional Regressions}")  ///
    label
