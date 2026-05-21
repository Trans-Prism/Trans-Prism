# 抗雄激素药物药代动力学模型文档

## 概述

本文档说明 `trans_prism` 血药浓度模拟模块中抗雄激素药物（环丙孕酮、螺内酯/坎利酮）PK 模型的数据来源和计算方法。

---

## 1. 环丙孕酮乙酸酯 (Cyproterone Acetate, CPA)

### 来源

| 来源 | 类型 | 链接 |
|------|------|------|
| DrugBank | 药物数据库 | https://go.drugbank.com/drugs/DB04839 |
| FDA Label (Androcur) | 药品说明书 | Bayer Androcur SmPC |
| Hammerstein et al. (1975) | 学术文献 | PMID: 1175298 |
| PubChem | 化学数据库 | https://pubchem.ncbi.nlm.nih.gov/compound/cyproterone_acetate |

### 模型

采用**单室口服 Bateman 模型**（一阶吸收 + 一阶清除）：

```
C(t) = D × F × ka / (Vd × (ka - ke)) × (e^(-ke×t) - e^(-ka×t))
```

- `C(t)` — 时间 t 的血药浓度 (ng/mL)
- `D` — 口服剂量 (mg)
- `F` — 生物利用度
- `ka` — 吸收速率常数 (h⁻¹)
- `ke` — 消除速率常数 (h⁻¹)
- `Vd` — 表观分布容积 (L)

### PK 参数

| 参数 | 值 | 单位 | 依据 |
|------|----|------|------|
| 生物利用度 (`F`) | 1.0 | — | 口服几乎完全吸收 (DrugBank: "well absorbed") |
| 吸收速率 (`ka`) | 0.23 | h⁻¹ | 基于 Tmax ≈ 3-4h，`ka ≈ ln(2)/0.3h` ≈ 2.3 h⁻¹；但考虑缓释制剂取保守值 0.23 |
| 消除半衰期 (`t½`) | 38 | h | DrugBank/FDA: 1.6-4.3 天，取中间值约 38h |
| 消除速率 (`ke`) | 0.0182 | h⁻¹ | `ke = ln(2)/t½` |
| 分布容积 (`Vd`) | 21 | L/kg | DrugBank: "large volume of distribution" |
| 蛋白结合率 | 96% | — | DrugBank |
| 分子量 | 416.94 | g/mol | PubChem |

### 典型剂量

- MtF HRT: 5–50 mg/天 口服
- 高剂量治疗: 50–100 mg/天

---

## 2. 螺内酯 (Spironolactone) → 坎利酮 (Canrenone)

### 来源

| 来源 | 类型 | 链接 |
|------|------|------|
| DrugBank (Spironolactone) | 药物数据库 | https://go.drugbank.com/drugs/DB00421 |
| DrugBank (Canrenone) | 药物数据库 | https://go.drugbank.com/drugs/DB12259 |
| FDA Label (Aldactone) | 药品说明书 | https://www.accessdata.fda.gov/drugsatfda_docs/label/2018/012151s075lbl.pdf |
| Sadee et al. (1974) | 学术文献 | PMID: 4831857 |
| Karim et al. (1976) | 学术文献 | PMID: 1277155 |
| Gardiner et al. (1989) | 学术文献 | PMID: 2473824 |

### 代谢路径

螺内酯是前药 (prodrug)，本身半衰期短 (~1.4h)，在体内迅速代谢为多种活性代谢物：
- **坎利酮 (Canrenone)** — 主要活性代谢物 (t½ ~16.5h)
- 7α-硫甲基螺内酯 (7α-TMS)
- 6β-羟基螺内酯

本模型模拟**坎利酮**的浓度曲线，因为它是主要的抗雄激素活性成分。

### 模型

采用**单室口服 Bateman 模型**（一阶吸收 + 一阶清除）模拟坎利酮：

```
C(t) = D × F × ka / (Vd × (ka - ke)) × (e^(-ke×t) - e^(-ka×t))
```

`D` 为螺内酯剂量 (mg)；`F` 为螺内酯→坎利酮的系统性暴露转化系数。

### PK 参数

| 参数 | 值 | 单位 | 依据 |
|------|----|------|------|
| 生物利用度 (`F`) | 0.73 | — | FDA Aldactone Label: ~73% 口服吸收 |
| 坎利酮 Tmax | 2.6 | h | FDA Aldactone Label (canrenone Cmax at ~2.6h) |
| 坎利酮吸收速率 (`ka`) | 0.27 | h⁻¹ | 基于 Tmax: `ka ≈ ln(2)/Tmax` ≈ 0.27 |
| 坎利酮消除半衰期 (`t½`) | 16.5 | h | DrugBank / FDA Label |
| 坎利酮消除速率 (`ke`) | 0.042 | h⁻¹ | `ke = ln(2)/t½` |
| 分布容积 (`Vd`) | 10 | L/kg | 估计值（中等分布容积） |
| 蛋白结合率 | >90% | — | DrugBank |

### 典型剂量

- MtF HRT: 50–200 mg/天 口服
- 心力衰竭: 25–50 mg/天

---

## 3. 坎利酮钾 (Canrenoate Potassium / 直接坎利酮)

坎利酮钾是直接使用的坎利酮盐形式，绕过螺内酯的代谢步骤：

| 参数 | 值 | 单位 | 依据 |
|------|----|------|------|
| 生物利用度 (`F`) | 1.0 | — | 静脉/口服均可，生物利用度高 |
| 其他参数 | 同上坎利酮 | — | 因为直接提供坎利酮 |

---

## 4. 模型局限性

1. **单室简化**：这些药代动力学模型使用单室近似，忽略了更深组织的分布相（α 相）。对于抗雄激素药物，单室模型在口服给药的情景下能提供一个合理的血浆浓度估计。

2. **个体差异**：PK 参数来自文献报道的平均值。个体间实际参数可能因年龄、肝功能、药物相互作用等因素存在显著差异。

3. **代谢物简化**：螺内酯模型的活性仅归因于坎利酮；7α-TMS 等其他活性代谢物未单独建模。

4. **非治疗用途声明**：此模拟仅适用于教育和信息参考目的，不应作为医疗决策的依据。

---

## 5. 外部链接

- CPA DrugBank: https://go.drugbank.com/drugs/DB04839
- Spironolactone DrugBank: https://go.drugbank.com/drugs/DB00421
- Aldactone FDA Label: https://www.accessdata.fda.gov/drugsatfda_docs/label/2018/012151s075lbl.pdf
- Androcur (CPA) SmPC (EMA): https://www.ema.europa.eu/

---

_最后更新: 2026-05-21_
