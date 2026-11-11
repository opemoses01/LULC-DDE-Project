# LULC DDE Forecasting Project

MATLAB scripts and derived tables for a five-class land-use/land-cover (LULC) analysis using a delay differential equation (DDE) model.

## Workflow

1. `Step2_LULC_DDE.m` estimates the instantaneous and delayed interaction matrices from annual class proportions for 2017–2025.
2. `Step3_Solve_LULC_DDE.m` solves the fitted DDE and exports a 2026–2035 forecast.
3. `Step4_DDE_Validation.m` reports fit metrics and observed-versus-predicted changes for 2018–2025.
4. `Step4_DDE_ValidationMap.m` produces raster-based validation maps. It expects `observed/` and `predicted/` subfolders containing matching annual GeoTIFFs named with the prefixes configured at the top of the script. Those input folders are not included here.

The scripts resolve project files relative to their own location. Run them from MATLAB with the project folder as the current folder. The scripts were written for MATLAB R2019a; forecasting requires `dde23`.

## Data and outputs

The repository includes compact MATLAB input/model files, CSV tables, figures, and validation summaries. The nine classified GeoTIFFs and their overview files are excluded because they account for most of the source folder's size. Place `LULC17.tif` through `LULC25.tif` in this folder to run the map workflow. GeoTIFF sidecars (`.tfw`, `.aux.xml`, `.vat.dbf`, `.vat.cpg`) may also be needed to preserve georeferencing and class metadata.

The main CSVs include historical class percentages and pixel counts, model performance, annual forecasts, and 2025–2035 class changes. Validation outputs are in `Step4_DDE_Validation/`.

## Interpretation notes

The saved validation scores use the same 2017–2025 transitions used to fit the model, so they are in-sample fit metrics rather than an independent holdout assessment. The forecast script clips negative class values and renormalizes each annual row. This can force a class to zero; inspect the raw solution and assumptions before interpreting the 2031–2035 bare-land forecast.

## Repository contents

- `Step2_LULC_DDE.m` — model estimation
- `Step3_Solve_LULC_DDE.m` — forecast generation
- `Step4_DDE_Validation.m` — model fit validation
- `Step4_DDE_ValidationMap.m` — raster map validation workflow
- `*.csv`, `*.mat`, `*.png` — compact inputs and generated results
- `Step4_DDE_Validation/` — validation figures and summary metrics
