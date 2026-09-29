# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Keywords

As of the release following 0.2.0 the following *keywords* are used at the start of each
changelog entry to indicate the impact of the change:

- **REPRODUCIBILITY** - a change to the pipeline's scientific processing that
  may cause the same input data to produce different scientific outputs or
  results, including changes to algorithms, tolerances, randomisation,
  scientific functionality, or output formats.
- **ROBUSTNESS** - a fix or improvement to the pipeline's scientific
  functionality that improves correctness, reliability, or the range of inputs
  that can be processed, without intentionally changing the scientific results
  of an equivalent successful analysis.
- **INTEGRATION** - a change to how the pipeline integrates with other systems
  or infrastructure, without changing its scientific processing or results.

## [Unreleased]
### Added
- **INTEGRATION** - run reporting. `lib/Utils.groovy` (shared verbatim with the other
  Dermatlas pipelines) is wired in by `workflow.onComplete { Utils.reportRun(workflow, params) }`
  and records each run in the Dermatlas website's analysis log (via `dermatlas-http`, >= 0.6.1)
  and/or posts a Slack message. Both are explicit opt-ins, gated by the
  `DERMATLAS_WEBSITE_LOGGING` / `DERMATLAS_SLACK_NOTIFICATIONS` environment toggles, and
  never fire on stub runs. `nextflow.config` gains `is_stub`,
  `analysis_pipeline_slug = 'unmatched_variants_pipe'` and `trace_file`.
- **INTEGRATION** - `nextflow.config` gains a `trace {}` block. The execution trace and
  report are named `execution_trace-<RUN_ID>.txt` / `execution_report-<RUN_ID>.html`
  under the launcher's `TRACE_DIR`, from the `RUN_ID` the launcher exports (a bare
  timestamp for a direct `nextflow run`). The stray top-level `tracedir` is removed.
- **INTEGRATION** - `assets/run_tumour_only.sh` is rebuilt from the reference Dermatlas
  launcher (`dermatlas_rnafusions_nf`): it sources the project `source_me.sh`
  (`SOURCE_ME`, `"none"` to skip), validates the environment before launch, reports a
  failed launch to stderr and (opt-in) Slack, holds an exclusive `flock` on
  `${PROJECT_DIR}/unmatched_variants_pipe/.lock` (a concurrent submission exits 75), writes a
  `.completed_successfully` / `.completed_with_error` sentinel, one log per nextflow
  command (`logs/nextflow-{pull,run}-<RUN_ID>.log`), per-revision `NXF_ASSETS` clones, a
  pinned `NXF_SINGULARITY_CACHEDIR`, and on success writes
  `stats/resource-stats-<RUN_ID>.txt`, reports the work-dir usage to the website
  (`dermatlas-http cohort analysis-workdir-stats`, >= 0.6.2, module-loaded via
  `DERMATLAS_HTTP_MODULE`) and deletes the work directory (`DERMATLAS_CLEANUP_WORK_DIR`).
  See "Without the website", "Toggles" and "Reclaiming disk space" in the README.
- **INTEGRATION** - `.github/workflows/publish-assets.yml` publishes `assets/` as a
  `projectify_asset_bundle.tar.gz` release bundle (`X.Y.Z`, `main-latest`,
  `develop-latest`) for `dermanager projectify`. See "Asset release bundles" in the README.
- **INTEGRATION** - `.update-version.sh` sets the release version in every file that
  records it; "Cutting a release" in the README now uses it.

### Changed
- **INTEGRATION** - **Breaking:** the launcher no longer reads its environment from the
  submitting shell; it sources `./source_me.sh` from the submission directory and fails
  at launch, naming the variables, unless it exports `PROJECT_DIR COMMANDS_DIR ANALYSIS_DIR
  STUDY PROJECT DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED` (plus the website/Slack
  variables when those toggles are on).
- **INTEGRATION** - **Breaking:** `assets/tumour_only.config` takes the cohort sample list
  from `${DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED}`, the variable dermanager exports
  for it, instead of rebuilding its path from a filename convention, and its inputs and
  `outdir` from `${ANALYSIS_DIR}` instead of `${PROJECT_DIR}/analysis`. Inputs are read
  from, and outputs land in, the same place for a dermanager project.
- **INTEGRATION** - **Breaking:** the config moves from `commands/tumour_only.config` to
  `commands/unmatched_variants_pipe/tumour_only.config`, matching the slug dermanager
  unpacks the asset bundle under, and the run's work, logs and traces move under
  `${PROJECT_DIR}/unmatched_variants_pipe/`. A run started from the old launch directory
  cannot `-resume` in the new one.
- **INTEGRATION** - **Breaking:** a run killed by `bkill` or an LSF limit now exits
  `128+n` and writes `.completed_with_error` rather than looking successful.
- **INTEGRATION** - the pipeline is pulled from GitHub
  (`team113sanger/dermatlas_tumour_only_nf`) rather than GitLab; `manifest.homePage`
  (which pointed at the germline pipeline), the README and the docs no longer point at
  GitLab. The GitLab container registry is unchanged.

## [0.2.0] - 2025-10-22
### Added
- Farm22 support
- Multi-cohort analysis 
- Documentation page and user info

### Changed
- Output cleanup and redirection

## [0.1.0] - 2025-10-01
### Added
- Initial version with all steps configured for OS
