# Causal model for public agricultural expenditure and maize yield

## Purpose

This document records the causal question, estimand, assumptions, and
identification judgment used by the project's Explanatory Analysis stage. It
is written before interpreting regression estimates so that statistical
results cannot silently redefine the scientific question.

## Causal question

> Among the observed project country-years, how would subsequent national
> maize yield differ if the prior-year share of government expenditure
> allocated to agriculture were one percentage point higher?

The expenditure share is a broad policy-related exposure. It is not a
randomized treatment, a particular agricultural programme, or expenditure on
maize alone.

## Target estimand

| Element | Definition |
| --- | --- |
| Target population | Observed project country-years with lagged expenditure and maize-yield data |
| Unit | One country-year |
| Exposure | Prior-year agriculture share of government expenditure |
| Contrast | One percentage point higher versus the reference exposure |
| Outcome | Subsequent national FAOSTAT maize yield in tonnes per hectare |
| Exposure time | Calendar year `t - 1` |
| Follow-up | Maize yield in calendar year `t` |
| Provisional estimand | Average difference in potential subsequent yield under the two expenditure-share conditions |

In potential-outcomes notation, the provisional target is:

```text
E[Y(G + 1 percentage point) - Y(G)]
```

The intervention is not fully defined. The same expenditure share can
represent different absolute budgets, sectors, programmes, implementation
quality, and government levels. The analysis therefore assesses whether the
observed data support this causal interpretation before estimating models.

## Temporal alignment

The implemented analysis links expenditure in `t - 1` to yield in `t`. The
one-year lag ensures that the recorded exposure precedes the outcome, but it
does not eliminate reverse causality: spending in `t - 1` may respond to yields
and agricultural conditions in earlier years.

The annual expenditure share is not a timestamped intervention. The maize
growing season begins in October of `t - 1`, so expenditure reporting and early
crop development can overlap within the same calendar year. The lag is a
transparent teaching convention, not proof of precise treatment timing.

The matched sample has 172 rows. Outcomes cover 2002–2022, while Zimbabwe
contributes only four exposure observations and corresponding outcomes. The
target population is therefore the observed unbalanced sample, not all nine
countries uniformly throughout the period.

## Causal diagram

The simplified teaching diagram is:

```text
prior agricultural conditions ─► expenditure share ─► productive capacity ─► maize yield
             │                         ▲                                      ▲
             └─────────────────────────┼──────────────────────────────────────┤
                                       │                                      │
politics, fiscal capacity and crises ──┘                                      │
                                                                              │
weather and precipitation ────────────────────────────────────────────────────┘
```

The intended path runs from expenditure orientation through productive
capacity to yield. Backdoor paths arise because prior agricultural conditions,
fiscal capacity, political priorities, crises, and other country-time
conditions can affect both expenditure and yield.

## Variable inventory

| Concept | Plausible role | Timing | Project representation | Limitation |
| --- | --- | --- | --- | --- |
| Agriculture expenditure share | Exposure | Year before outcome | FAOSTAT percentage | Broad category; content and effectiveness hidden |
| Maize yield | Outcome | Following year | FAOSTAT national yield | National aggregation and reporting error |
| Precipitation | Outcome cause and possible policy-response cause | Growing season and prior periods | CHIRPS country-area total for outcome year | Not crop-area weighted; one season cannot represent prior policy response |
| Country context | Proxy for stable common causes | Before exposure | Country indicators | Does not measure changing conditions |
| Calendar year | Proxy for common shocks and changes | Across period | Outcome-year indicators | Does not capture country-specific shocks |
| Prior yield and agricultural conditions | Confounders and policy triggers | Before exposure | Not included in the core model | Dynamic adjustment requires a separate estimand and stronger assumptions |
| Fiscal capacity and budget constraints | Common causes | Before exposure | Unmeasured | Expenditure share can change without higher absolute spending |
| Politics, crises, and food prices | Common causes | Before/around exposure | Largely unmeasured | Can trigger spending and affect production |
| Research, extension, infrastructure, and input support | Mediating mechanisms | After expenditure decisions | Unmeasured | Adjusting for them would remove part of a total effect |
| Government level | Measurement context | At exposure measurement | Retained category | Changes can create comparability breaks |

Variable roles depend on timing and the estimand. Variables should not be
added as controls merely because they are available.

## Identification assessment

| Requirement | Evidence | Judgment | Consequence |
| --- | --- | --- | --- |
| Consistency | Equal shares can fund different activities at different government levels | Doubtful | The one-point contrast has heterogeneous versions |
| Conditional exchangeability | Country, year, and outcome-year precipitation are observed; major policy and economic causes are not | Not established | Adjusted estimates may remain confounded |
| Positivity | Expenditure ranges differ substantially and Zimbabwe has four observations | Limited | Some comparisons depend on extrapolation or a few countries |
| No interference | Countries share markets, aid, policies, and regional shocks | Uncertain | Country-years may not be isolated units |
| Measurement validity | FAOSTAT reports estimated shares at the highest available government level | Limited | Level changes and broad categories affect comparability |
| Selection and transport | Only observed country-years enter the lagged sample | Limited target | Do not generalize to missing years or other countries automatically |

## Adjustment strategy

The planned sequence compares:

1. an unadjusted pooled expenditure-share association;
2. the association with country indicators;
3. the association with country and outcome-year indicators;
4. the association with country and outcome-year indicators plus
   growing-season precipitation; and
5. a quadratic expenditure sensitivity model with the same main adjustments.

Country and year indicators are proxies for stable country characteristics
and shared yearly shocks. Precipitation represents an important outcome cause.
These variables do not form a demonstrably sufficient adjustment set.

## Identification judgment

The current national observational data do **not** identify the proposed
causal policy effect credibly. In particular:

- expenditure can respond to previous agricultural performance;
- the broad exposure has heterogeneous versions and unknown implementation;
- important time-varying political, fiscal, market, and agricultural causes
  are unmeasured;
- reporting at changing government levels weakens comparability;
- the panel is short and unbalanced; and
- repeated country observations challenge default model uncertainty.

The fitted coefficients are therefore reported as adjusted associations. The
causal workflow remains useful because it makes the desired question,
necessary assumptions, and unsupported interpretations explicit.

## Evidence needed for stronger inference

Useful additions include:

- expenditure amounts and composition by programme and function;
- stable and comparable government-level coverage;
- policy eligibility, implementation intensity, and timing;
- prior outcomes, fiscal capacity, food prices, conflict, and other policy
  triggers;
- longer and more complete country coverage;
- subnational outcomes where expenditure varies subnationally;
- a specific policy intervention or defensible natural experiment; and
- sensitivity analysis for dynamic and unmeasured confounding.

## Maintenance rule

Revise this document before changing the exposure lag, estimand, adjustment
strategy, or sample. A statistically convenient model must not determine the
causal question after results are known.
