# Zyndio: Scientific References & Citations

This document provides the clinical and scientific foundations for the algorithms, optimal ranges, and health metrics used within the Zyndio application.

## 1. Wearable Performance Algorithms

The performance scores (Strain, Recovery, Stress, and Energy) are derived from raw sensor data (HR, HRV, Sleep) using established physiological modeling.

| Metric | Scientific Basis / Reference | Key Methodology |
| :--- | :--- | :--- |
| **Strain** | [Banister EW (1991)](https://pubmed.ncbi.nlm.nih.gov/1816431/). *Modeling elite athletic performance*. | Based on the **TRIMP** (Training Impulse) formula using exercise-specific heart rate average and duration. |
| **Recovery** | [Buchheit M (2014)](https://pubmed.ncbi.nlm.nih.gov/24578692/). *Monitoring training status with HR measures*. | Composite score of HRV deviation from 7-day personal baseline (40%), RHR deviation (35%), and Sleep (25%). |
| **Stress** | [Kim HG et al. (2018)](https://pubmed.ncbi.nlm.nih.gov/29486547/). *Stress and HRV*. [Schumann AY et al. (2017)](https://doi.org/10.3389/fphys.2021.670265). *HR vs HRV*. | Dual-component model: Parasympathetic (RMSSD vs baseline) and Sympathetic (HR vs RHR reserve). |
| **Cardio Load** | [Coggan AR & Allen H (2010)](https://scholar.google.com/scholar?q=Training+and+Racing+with+a+Power+Meter+Coggan+Allen). *Training and Racing with a Power Meter*. | HR-Proxy **TSS** (Training Stress Score) based on intensity factor (HR relative to lactate threshold) and duration. |
| **Body Battery** | [Dijk DJ & Czeisler CA (1995)](https://www.jneurosci.org/content/15/5/3526). *NREM/REM homeostatic interaction*. | Circadian rhythm modeling using the **Two-Process Model** (Process S + Process C) to simulate energy decay through the day. |
| **Sleep Quality** | [Hirshkowitz et al. (2015)](https://doi.org/10.1016/j.sleh.2014.12.010). *NSF recommendations*. [Buysse DJ et al. (1989)](https://pubmed.ncbi.nlm.nih.gov/2748771/), *PSQI*. | Weighted scoring: 70% Duration (optimal 7–9h) and 30% Efficiency (calculated from awake stage data). |

## 2. Biomarker Optimal Ranges (Lab Reports)

Zyndio differentiates between "Normal" ranges (clinical standard) and "Optimal" ranges (longevity and performance standard).

| Biomarker | Optimal Range | Citation / Source |
| :--- | :--- | :--- |
| **HbA1c** | 4.8 – 5.2 % | [Levine et al. (2018)](https://pubmed.ncbi.nlm.nih.gov/29676998/); ADA Standards |
| **Vitamin D** | 40 – 80 ng/mL | [Holick MF, et al.](https://pubmed.ncbi.nlm.nih.gov/21646368/) (Endocrine Society Guidelines) |
| **hs-CRP** | 0.0 – 1.0 mg/L | [Ridker PM (2003)](https://pubmed.ncbi.nlm.nih.gov/12711671/), NEJM |
| **LDL** | < 70 mg/dL | [Ference BA, et al. (2017)](https://pubmed.ncbi.nlm.nih.gov/28444290/), EAS/ESC Guidelines |
| **HDL** | 60 – 90 mg/dL | [Sirtori CR (2006)](https://pubmed.ncbi.nlm.nih.gov/16843445/) |
| **Triglycerides** | < 100 mg/dL | [Nordestgaard BG (2016)](https://pubmed.ncbi.nlm.nih.gov/27918805/) |
| **TSH** | 1.0 – 2.5 mIU/L | [Garber JR, et al.](https://pubmed.ncbi.nlm.nih.gov/22961224/) (AACE/ETA Guidelines) |
| **Fasting Insulin** | 2.6 – 5.0 µIU/mL | [Centenarian Studies](https://pubmed.ncbi.nlm.nih.gov/12970313/) (PubMed 12970313) |
| **Fasting Glucose** | 70 – 85 mg/dL | [Tiinamaija T, et al. (2011)](https://pubmed.ncbi.nlm.nih.gov/21220444/) |
| **ALT / AST** | < 25 U/L | [NAFLD Research](https://pubmed.ncbi.nlm.nih.gov/25559336/) & [Clinical Chemistry (2004)](https://pubmed.ncbi.nlm.nih.gov/15613524/) |
| **ApoB** | < 60 mg/dL | [Sniderman AD, et al. (2019)](https://pubmed.ncbi.nlm.nih.gov/30584050/), JAMA Cardiology |
| **Homocysteine** | < 9.0 µmol/L | [Smith AD, et al. (2010)](https://pubmed.ncbi.nlm.nih.gov/20838622/) |
| **IGF-1** | 120 – 180 ng/mL | [Milman S, et al. (2014)](https://pubmed.ncbi.nlm.nih.gov/24719268/) |
| **Ferritin** | 70 – 150 ng/mL | [WHO Guidelines](https://www.who.int/publications/i/item/9789240000124) |

## 3. Specialized Health Metrics

| Metric | Scientific Basis / Reference |
| :--- | :--- |
| **BioAge** | [Levine et al., 2018](https://pubmed.ncbi.nlm.nih.gov/29676998/) (**PhenoAge**); [Klemera & Doubal, 2006](https://pubmed.ncbi.nlm.nih.gov/16413571/). |
| **VO2 Max (Cardio Fitness)** | **ACSM** (American College of Sports Medicine) classification tiers by age and gender. |
| **Max Heart Rate** | **Tanaka Formula**: $208 - (0.7 \times \text{age})$. More accurate than $220 - \text{age}$ for older populations. |
| **HRV Population Baseline** | [Koenig et al. (2016)](https://pubmed.ncbi.nlm.nih.gov/31717972/). *Adult population median RMSSD (42ms)*. |

## 4. Glossary & Methodology Notes

*   **Optimal vs. Normal**: Standard lab ranges are based on 95% of the population, including those with chronic conditions. Zyndio optimal ranges are derived from longevity studies and elite athletic performance standards.
*   **Personal Baselines**: Most wearable metrics (Recovery, Stress) use a rolling 7-day median to establish a personal baseline. Deviations from this baseline are weighted more heavily than deviations from population averages.
*   **Biological Age**: Calculated using a deviation-based model across 10+ key biomarkers including Glucose, HbA1c, HDL, LDL, Triglycerides, Creatinine, ALT, Hemoglobin, TSH, and Vitamin D.
