# Data-visualization implementation

This document explains how the standalone `maize-yield-project` implements
reproducible Data Visualization. It records the repository decisions behind
the figures; the parent learning module provides the broader concepts and
guided exercise.

## Place in the workflow

Visualization consumes, but does not modify, the outputs of preparation and
integration:

```text
prepared maize panel ───────────────┐
                                    ├──► visualization script
integrated maize-precipitation data ┘             │
                                                  ├──► exploratory figures
                                                  ├──► communication figure
                                                  └──► artifact-state registry
```

The script reveals distributions, trends, and associations that later
descriptive and modeled analyses can quantify. It does not calculate the
country summaries that belong to the next topic, and it does not fit a trend
or causal model.

## Inputs and contracts

`scripts/visualize-maize-data.R` reads:

| Input | Grain | Key | Primary visual role |
| --- | --- | --- | --- |
| `data/derived/maize-yield-panel.csv` | One selected country and year | `country + year` | Yield distributions and trends |
| `data/derived/maize-yield-with-precipitation.csv` | One project country and year | `project_country_id + year` | Precipitation and paired relationships |

Before plotting, the script records the current checksums of its direct inputs
and any existing figure outputs. After saving the figures, it records their
new checksums. Structural and semantic validation belongs to the preparation
and integration stages that created the analytical inputs.

## Figure set

The script produces five complementary artifacts:

| Figure | Role | Question | Mark or aggregate |
| --- | --- | --- | --- |
| `maize-yield-distribution.png` | Exploratory | How are annual maize-yield observations distributed? | Count of observations in a 0.25 t/ha bin |
| `maize-yield-trends.png` | Exploratory | How does yield change within and differ across countries? | One country-year point joined within a country |
| `growing-season-precipitation-trends.png` | Exploratory | How does seasonal precipitation change within countries over time? | One country-season point joined within a country |
| `yield-versus-precipitation.png` | Exploratory | How do yield and precipitation vary together? | One country-year point |
| `maize-yield-communication.png` | Communication | How do maize-yield trajectories differ across countries? | One country-year point joined within a country |

The exploratory set examines different structures. The communication figure
refines the common-scale maize trend plot into the retained teaching artifact.

## Visual decisions

### Observation grain

The time-series and relationship figures preserve the country-year grain. The
yield histogram applies explicit binning and labels its vertical axis as a
count. The precipitation figure describes country-area October-April
estimates, not rainfall measured at maize fields.

### Position and faceting

Quantitative comparisons use horizontal and vertical position. Countries are
faceted rather than encoded as nine similar colours. The yield panels use one
common yield scale and the precipitation panels use one common precipitation
scale, so levels remain comparable across countries. Yield and precipitation
remain in separate figures because their units and scales differ.

### Colour and access

Colour is fixed rather than used as the only country identifier. Country names
appear in facet labels, and the primary comparisons remain visible in
grayscale. The project palette uses dark blue for maize measures and green for
precipitation. Saved figures use explicit dimensions and readable base text.

### Binning and overplotting

The yield-histogram bin width is visible in code. The paired scatterplot uses
transparency to expose
overlapping points and facets to separate country contexts. Transparency does
not solve every density problem, so the figure remains exploratory.

### Temporal stability

The parallel yield and precipitation time-series figures make temporal order
visible at the same country-year grain. They support questions about changes
in level, changes in variability, unusual years, and similarity between
adjacent observations. In particular, persistent yield increases for some
countries warn against treating the complete series as identically
distributed over time.

Visual evidence can challenge a stationarity assumption but cannot establish
stationarity or identify the process that generated a trend. The following
descriptive-analysis stage combines these figures with predefined period
summaries and temporal-dependence diagnostics.

### Claims

The yield-precipitation figure describes paired observations. It does not
establish that precipitation causes yield changes. Country differences,
long-term trends, aggregation, measurement error, irrigation, temperature,
inputs, and omitted variables remain possible explanations.

## Reproducible execution

Run the upstream stages and visualization from the repository root:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/integrate-data.R
Rscript scripts/visualize-maize-data.R
```

Alternatively, run the complete offline workflow:

```bash
Rscript scripts/run-all.R
```

The script uses project-relative paths, the recorded package environment,
explicit dimensions, and version-controlled plotting code. The artifact
registry makes changes in the direct inputs and generated figures visible.

## Artifact state and review evidence

`metadata/artifacts.csv` records:

- artifact path and presence state;
- current SHA-256 checksum;
- most recent check time and checking script; and
- most recent detected change time and detecting script.

The registry is checked before the visualization operation and again after its
outputs are written. An unchanged checksum shows byte identity. It cannot
confirm that labels are readable, encodings are appropriate, or
interpretations are justified. Those properties require human review of the
saved artifact and its report.

Review each figure at its intended display size and ask:

- Does the question match the graphic?
- Can one mark or aggregate be described precisely?
- Are units, period, source, and limitations visible?
- Are fixed or free scales used intentionally?
- Are labels and contrast accessible?
- Does the interpretation remain descriptive?

The report `reports/data-visualization.qmd` presents this review context and
embeds the generated figures.

## Figure and version-control policy

The four exploratory PNG files are reproducible working artifacts and are
ignored by Git. Their script and artifact state are tracked.

`figures/maize-yield-communication.png` is tracked as the visible example
artifact. It lets learners inspect the intended result immediately and should
be regenerated deliberately whenever its data, code, environment, or design
changes.

Rendered HTML remains ignored. This policy avoids
storing every exploratory view while retaining one inspectable teaching figure.

## Relationship to adjacent topics

| Topic | Project responsibility |
| --- | --- |
| Data Preparation | Create documented country-year analytical artifacts |
| Data Visualization | Reveal and communicate patterns through reproducible figures |
| Descriptive Data Analysis | Quantify distributions, variation, and associations |
| Modeling | Formulate and evaluate explanatory or predictive relationships |

The visualization script therefore avoids country means, correlation
coefficients, fitted smooths, regression lines, and model-based uncertainty.
Those additions require their own definitions and assumptions in later topics.

## Maintenance checklist

When data, questions, or figure code change:

1. review input grain, keys, units, and limitations;
2. revise the figure contract before changing encodings;
3. rerun preparation and integration checks;
4. regenerate every figure and update the artifact registry through code;
5. inspect saved outputs at their intended dimensions;
6. review accessibility and claim boundaries;
7. render `reports/data-visualization.qmd`;
8. update this document if the output policy or visual questions change; and
9. stage only intended code, documentation, and the retained communication figure.
