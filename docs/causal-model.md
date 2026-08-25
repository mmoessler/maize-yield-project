# Causal model for precipitation and maize yield

## Purpose

This document records the causal question, estimand, assumptions, and
identification judgment used by the project's Explanatory Modeling stage. It
is written before interpreting regression estimates so that statistical
results cannot silently redefine the scientific question.

## Causal question

> Among the nine selected countries from 1990 through 2022, how would national
> maize yield differ if October-April precipitation were 100 mm higher than the
> reference exposure, all else represented according to the causal model?

This is a provisional question. The observed exposure is natural country-area
weather variation, not a controlled intervention.

## Target estimand

| Element | Definition |
| --- | --- |
| Target population | Country-years for the nine project countries, 1990–2022 |
| Unit | One country-year |
| Exposure | October-April country-area CHIRPS precipitation total |
| Contrast | 100 mm higher versus the reference exposure |
| Outcome | National FAOSTAT maize yield in tonnes per hectare |
| Time zero | Start of the October-April season |
| Follow-up | Yield reported for the corresponding ending year |
| Estimand | Average difference in potential national yield under the two exposure conditions |

In potential-outcomes notation, the provisional target is:

```text
E[Y(P + 100 mm) - Y(P)]
```

The estimand is difficult to interpret because an additional 100 mm can differ
in timing, intensity, spatial location, and mechanism. A seasonal total does
not define one unique treatment version.

## Causal diagram

The simplified diagram used for teaching is:

```text
seasonal weather ───► precipitation ───► maize yield
       │                                      ▲
       └──────────────────────────────────────┘

country/time context ─► precipitation
          │                    │
          └───────────────────►yield

irrigation, soils, inputs and management ────►yield
```

The intended direct path is from precipitation to maize yield. Backdoor paths
can arise through broader weather and country-time context. The broad nodes
are conceptual summaries, not claims that country indicators and a linear year
term measure every component.

## Variable inventory

| Concept | Plausible role | Timing | Project representation | Limitation |
| --- | --- | --- | --- | --- |
| Seasonal precipitation | Exposure | During season | CHIRPS country-area total | Timing, intensity, and crop-area exposure hidden |
| Maize yield | Outcome | End of season/year | FAOSTAT national yield | National aggregation and reporting error |
| Temperature and weather systems | Common causes | Before/during season | Unmeasured | Important time-varying confounding |
| Country context | Proxy for stable common causes | Before exposure | Country indicator | Does not measure changing conditions |
| Calendar time | Proxy for shared change | Before/indexing exposure | Centered linear year | One common trend is restrictive |
| Irrigation and water access | Confounder, modifier, or mediator depending on timing | Before/during season | Unmeasured | Role cannot be resolved from current data |
| Soils and crop location | Common cause or modifier | Predominantly pre-exposure | Unmeasured | Country-area rainfall may miss maize land |
| Inputs, varieties, and management | Outcome causes and possible time-varying common causes | Before/during season | Unmeasured | Likely related to country and time |
| Pests and disease | Outcome cause or mediator | During season | Unmeasured | Can respond to weather |
| Policy, markets, conflict, and reporting | Context and selection causes | Across period | Largely unmeasured | May affect production and recorded values |

Variables should not be added as controls solely because they are available.
Their causal role and timing determine whether adjustment blocks bias, removes
part of an effect, or opens a collider path.

## Identification assessment

| Requirement | Evidence | Judgment | Consequence |
| --- | --- | --- | --- |
| Consistency | Equal totals can have different timing, intensity, and location | Doubtful | The 100 mm contrast has multiple versions |
| Conditional exchangeability | Country and year are observed; key weather and agricultural causes are not | Not established | Adjusted estimates may remain confounded |
| Positivity | Each country has 33 years, but precipitation ranges differ | Partly assessable | Inspect support; some contrasts may extrapolate |
| No interference | Countries share weather systems, water, trade, and shocks | Uncertain | Country-years may not be isolated units |
| Measurement validity | National yield is paired with country-area precipitation | Limited | Exposure and outcome are imperfectly aligned |
| Selection and transport | Nine countries with complete teaching snapshots | Limited target | Do not generalize automatically |

## Adjustment strategy

The analysis compares:

1. an unadjusted precipitation association;
2. precipitation with country indicators;
3. precipitation with a common linear time trend;
4. precipitation with country indicators and time; and
5. a nonlinear precipitation sensitivity model with country and time.

Country and time terms are available proxies used to expose specification
sensitivity. They are not treated as a sufficient causal adjustment set.

## Identification judgment

The current national observational dataset does **not** identify the proposed
causal effect credibly. In particular:

- the exposure contrast is not a unique intervention;
- important time-varying common causes are unmeasured;
- national and country-area aggregation weakens exposure-outcome alignment;
- temporal and regional dependence challenge default uncertainty assumptions;
- continuous-exposure support is limited within some country-period contexts.

The regression results are therefore reported as adjusted associations. The
causal analysis remains useful because it documents why causal language is not
supported and which evidence would be needed to strengthen it.

## Evidence needed for stronger inference

Useful additions include:

- crop-area or field-level precipitation aligned to maize phenology;
- temperature, soil moisture, extreme-rainfall, and dry-spell measures;
- irrigation, inputs, varieties, management, and planted-area information;
- subnational outcomes and stable reporting definitions;
- an explicit intervention or defensible natural experiment;
- a larger panel supporting richer time and dependence structures; and
- sensitivity analyses calibrated to plausible unmeasured confounding.

## Maintenance rule

Revise this document before changing the causal adjustment strategy. If the
exposure, outcome, target population, or available measurements change, review
the estimand, every arrow, the identification assumptions, and the conclusion
before refitting models.
