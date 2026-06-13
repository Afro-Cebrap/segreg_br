# Project Refactoring Standard: Data Science & Research Pipelines

This document defines a standard organizational structure for research and data science repositories. It is designed to be followed by agents or developers to ensure consistency, reproducibility, and clarity across different projects.

## 1. Directory Structure

Any repository following this standard must be reorganized into the following layout:

```text
src/                    # Core logic and execution pipelines
├── utils/              # Reusable functions and helpers (e.g., DB connections, formulas)
├── 01_download.R       # Data ingestion/loading scripts (numbered sequentially)
├── 02_cleaning.R       # Data cleaning and transformation
└── 03_analysis.R       # Final analysis or index calculation
sandbox/                # Non-production code, drafts, and local experiments
reports/                # Documentation, Quarto/Markdown reports, and publications
config/                 # Environment variables, parameters, and schemas (no secrets)
tests/                  # Automated unit and integration tests
data/                   # Tiered data storage (ignored by git, except metadata)
├── 1_bronze/           # Raw, untouched original data
├── 2_silver/           # Cleaned, standardized, and validated data
├── 3_gold/             # Final aggregates and production-ready outputs
└── metadata/           # Data dictionaries and schema definitions
makefile                # Pipeline orchestrator
README.md               # Setup and usage instructions
LICENSE.md              # Project license
```

## 2. Data Tiering Logic

*   **1_bronze (Raw):** The source of truth. Data here is never modified. If data is downloaded via script, it goes here.
*   **2_silver (Clean):** Intermediate data. Standardized column names, types fixed, and rows filtered. This is the "join-ready" layer.
*   **3_gold (Output):** High-value data. Final indices, statistical summaries, and tables ready for visualization or dashboards.

## 3. Implementation Rules for Agents

When refactoring a repository to this standard, follow these steps:

### Phase 1: Preparation
1.  **Create Directories:** Ensure all directories in the structure above exist.
2.  **Move Scripts:** 
    *   Move core analysis scripts to `src/`.
    *   Move utility functions/helpers to `src/utils/`.
    *   Move experimental/test scripts to `sandbox/`.
3.  **Move Data:**
    *   Relocate raw data files to `data/1_bronze/`.
    *   Relocate output/processed files to `data/3_gold/`.

### Phase 2: Code Adjustment
1.  **Path Resolution:** Update all file paths in scripts. Use relative path management (like the `here` library in R or `pathlib` in Python).
    *   *Input paths:* Update to point to `data/1_bronze/` or `data/2_silver/`.
    *   *Output paths:* Update to point to `data/3_gold/`.
2.  **Dependency Updates:** Update `source()` calls (R) or `import` statements (Python) to reflect the new `src/utils/` location.
3.  **Setup Script:** Create or update a `setup` script (e.g., `src/utils/setup.R`) that verifies/creates the directory structure and installs dependencies.

### Phase 3: Documentation & Orchestration
1.  **Makefile:** Create a `makefile` with at least three targets: `setup`, `all` (running the full pipeline), and `clean`.
2.  **README.md:** Update the "Project Structure" section to match the new layout and provide clear execution steps.
3.  **LICENSE:** Ensure the license is named `LICENSE.md`.

## 4. Verification Checklist
- [ ] No scripts are left in the root directory.
- [ ] Raw data is strictly separated from processed data.
- [ ] All scripts run successfully from the new locations.
- [ ] `README.md` reflects the current state of the repository.
