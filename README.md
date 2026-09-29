# dermatlas_tumour_only_calling_nf
[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.04.5-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

`dermatlas_tumour_only_calling_nf` is a bioinformatics pipeline written in [Nextflow](http://www.nextflow.io) for identifying somatic variants from unmatched FFPE tumor samples within the Dermatlas project.

## Pipeline summary

In brief, the pipeline takes cohort(s) of tumour samples that have been pre-processed with `dermatlas_somatic_qc_nf` and

- Collates variants from matched normal-tumour samples in the cohort(s) for filtering recurrent technical artefacts and germline variants.
- Annotates common SNPs from the unmatched tumour samples using dbSNP.
- Counts germline variants in the matched normal samples for the cohort(s), so that they can be annotated in the unmatched tumour samples.
- Validates MNV variant calls in the unmatched tumour samples.
- Flags and filters variants in the unmatched tumour samples using the normal and matched tumour sample, dbSNP and germline counts.
- Annotates filtered variants in the unmatched tumour samples using a custom Dermatlas tiering system - which ranks variants based on their likely clinical significance and the strength of evidence supporting their veracity.
- Generates summary plots and reports for the unmatched tumour samples.


## Inputs 

- `germline_vcfs`: path to a list of germline VCFs from matched normal samples in the cohort (one VCF per line)
- `unmatched_somatic_vcfs`: path to a list of somatic VCFs from unmatched tumour samples in the cohort (one VCF per line).
- `matched_somatic_vcfs`: path to a list of somatic VCFs from unmatched tumour samples in the cohort (one VCF per line).
- `unmatched_maf`: path to a MAF file collated from the unmatched tumour samples in the cohort generated using `dermatlas_somatic_qc_nf`.
- `transcripts`:  path to a file containing Ensembl transcripts where we wish to modify the canonical transcript for accurate variant reporting.
- `transcript_info`:  path to a GTF file containing transcript information (exon locations used in fitering processed pseudogenes)
- `cgc_file`: path to a Cosmic Cancer Gene Census file for annotating variants
- `oncokb_file`: path to an  Onkokb file for annotating variants
- `hotspot_file`: path to a cancer hotspots file for annotating variants
- `dbsnp_file`: dbSNP VCF file for annotating common SNPs and its index file
- `release_version`: results release version (e.g. `1.0`)
- `cohorts`: a map of cohort name to sample list; each list's first column holds the tumour sample IDs to retain in that cohort's MAF and plot outputs (e.g. `["all_samples": "/path/to/one_tumour_per_patient_unmatched.tsv"]`)
- `outdir`: path to the directory where results will be written

## Usage

Whether launched via the integrated website or manually, the pipeline is submitted the same way: `run_tumour_only.sh` is piped into `bsub` as the
job script.

```bash
bsub -o "<stdout_log>" -e "<stderr_log>" \
     -g "<lsf_job_group>" -J "<job_name>" \
     < <dir>/run_tumour_only.sh
```

Queue, resource group and memory come from the `#BSUB` directives inside the wrapper, so `bsub` adds only the job
name, job group and log paths. It is an ordinary bash script, so `bash run_tumour_only.sh` also runs it in the
foreground on any farm node - the `#BSUB` lines are inert comments; `bsub` only makes it a batch job. Either way
it sources `./source_me.sh` relative to the directory it was started from.

Nearly all runs are triggered from the [Dermatlas cohorts page](https://team113.sanger.ac.uk/dermatlas/cohorts/),
which issues that command remotely against a project directory it has already provisioned - `source_me.sh`,
`run_tumour_only.sh` and `tumour_only.config` are all written for you. There is nothing to do by hand.

### Without the website

Clone the repo and supply what the website otherwise provisions: a project directory, the pipeline's
environment, and a couple of edits to the wrapper.

The config reads its inputs from `${ANALYSIS_DIR}/unmatched/` - the VCF lists and collated MAF prepared as in
the [analysis SOP](docs/source/user_docs/analysis_sop.md) - and its cohort sample list (tumour ids in the first
column) from `DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED`. See [Inputs](#inputs) for the formats.

```
<project_dir>/                                   # PROJECT_DIR
├── metadata/
│   └── 6740_3016-one_tumour_per_patient_unmatched.tsv   # cohort sample list
├── analysis/                                    # ANALYSIS_DIR
│   ├── unmatched/                               # inputs, prepared by hand
│   │   ├── germline_variant_files.tsv
│   │   ├── matched_somatic_vcfs.tsv
│   │   ├── unmatched_somatic_vcfs.tsv
│   │   └── combined_cohorts_keep_unmatched.maf
│   └── unmatched_variant_calling/               # results land here
└── unmatched_variants_pipe/                     # created by the wrapper, not by you
    ├── .lock                                    # see Reclaiming disk space
    ├── .completed_successfully                  #   "
    ├── work/                                    # deleted after a successful run
    └── tmp/
```

The environment itself can come from a `source_me.sh` or from the wrapper directly. Both are supported; pick one.

<details>
<summary><strong>With a <code>source_me.sh</code></strong> - reusable across runs, and the shape the website generates</summary>

1. Write `source_me.sh` beside the wrapper in `assets/`, which is where the wrapper looks by default. With
   reporting opted out, these six exports are the whole contract:

   ```bash
   export PROJECT_DIR="/lustre/.../6740_3016_MY_COHORT_WES"
   export COMMANDS_DIR="${PROJECT_DIR}/commands"
   export ANALYSIS_DIR="${PROJECT_DIR}/analysis"
   export STUDY="6740"          # part of the run id
   export PROJECT="3016"        # part of the run id
   export DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED="${PROJECT_DIR}/metadata/6740_3016-one_tumour_per_patient_unmatched.tsv"
   ```

2. In the wrapper, under **OPT-IN REPORTING** set `DERMATLAS_WEBSITE_LOGGING` and
   `DERMATLAS_SLACK_NOTIFICATIONS` to `"false"`, and under **RUN CONFIGURATION** point `CONFIG` at your
   `tumour_only.config` and set `REVISION` to the release tag to run.

3. Submit from the directory holding `source_me.sh`:

   ```bash
   cd dermatlas_tumour_only_nf/assets
   bsub -o run.out -e run.err -J "tumour-only-<cohort>" < run_tumour_only.sh
   ```

To override a single value without regenerating the file, uncomment just that variable in the wrapper's
**MANUAL ENVIRONMENT OVERRIDES** block - it is read after `source_me.sh`, so it wins.

</details>

<details>
<summary><strong>By editing <code>run_tumour_only.sh</code> directly</strong> - self-contained, nothing to track outside the script</summary>

1. Under **ENVIRONMENT SETUP**, set `SOURCE_ME="none"` so the wrapper skips sourcing anything.

2. Under **MANUAL ENVIRONMENT OVERRIDES**, uncomment and fill in the pipeline-essential exports. With reporting
   opted out, these six are the whole contract:

   ```bash
   export PROJECT_DIR="/lustre/.../6740_3016_MY_COHORT_WES"
   export COMMANDS_DIR="${PROJECT_DIR}/commands"
   export ANALYSIS_DIR="${PROJECT_DIR}/analysis"
   export STUDY="6740"          # part of the run id
   export PROJECT="3016"        # part of the run id
   export DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED="${PROJECT_DIR}/metadata/6740_3016-one_tumour_per_patient_unmatched.tsv"
   ```

3. Under **OPT-IN REPORTING** set `DERMATLAS_WEBSITE_LOGGING` and `DERMATLAS_SLACK_NOTIFICATIONS` to
   `"false"`, and under **RUN CONFIGURATION** point `CONFIG` at your `tumour_only.config` and set `REVISION`
   to the release tag to run.

4. Submit from anywhere - with `SOURCE_ME="none"` there is no `source_me.sh` to be beside:

   ```bash
   bsub -o run.out -e run.err -J "tumour-only-<cohort>" < dermatlas_tumour_only_nf/assets/run_tumour_only.sh
   ```

The same block is the annotated master list for either route - every variable with its purpose and an example
value, including the website- and Slack-only ones you would add if you opted back in.

</details>

`tumour_only.config` reads these same variables, so it needs no editing unless you want different `cohorts`
or reference files. `REVISION` is fetched from GitHub, so your clone supplies the wrapper and config, not the
pipeline code - local edits to the workflow are not picked up until released.

The header of [`assets/run_tumour_only.sh`](assets/run_tumour_only.sh) maps every section and marks the
`[edit]` blocks, which are the only places you should need to touch.

### Toggles

| Variable | Default | Effect when `false` |
| --- | --- | --- |
| `DERMATLAS_WEBSITE_LOGGING` | `true` | no analysis-log record is written to the Dermatlas website |
| `DERMATLAS_SLACK_NOTIFICATIONS` | `true` | no Slack message on completion or failed launch |
| `DERMATLAS_CLEANUP_WORK_DIR` | `true` | this run's work directory is kept instead of deleted |

Work-directory cleanup only ever happens after a **successful** run; a failed one always keeps its work
directory, and so does one stopped by `bkill` or an LSF limit - `DERMATLAS_CLEANUP_WORK_DIR` is not consulted
unless the run succeeded. Cleanup relies on `params.publish_dir_mode = 'copy'`, and only ever removes the `work/` directory
the wrapper itself created.

None are required. Each is resolved from the environment, most specific first - a shell export beats
`source_me.sh`, which beats the default under **OPT-IN REPORTING** - so a single run can opt out without
editing anything:

```bash
export DERMATLAS_CLEANUP_WORK_DIR=false
bsub -o run.out -e run.err -J "tumour-only-<cohort>" < run_tumour_only.sh
```

`true/false`, `yes/no`, `on/off` and `1/0` are all accepted in any case; anything else fails the launch
immediately rather than part-way through.

### Reclaiming disk space

`work/` and `tmp/` are the bulk of a cohort's disk and inode use, and are usually deleted by a separate clean-up
script you run yourself rather than by the wrapper. So the wrapper leaves three dot-files in
`${PROJECT_DIR}/<pipeline_slug>/` that let such a script tell a live run from a finished one - **including a run
started by a different user, with no LSF tools involved**.

<details>
<summary><strong>The artefacts, and how to delete safely around them</strong></summary>

| Artefact | Meaning |
| --- | --- |
| `.lock` | created once and **never removed**. Its presence says only that this directory uses the scheme. It never means a run is live. |
| `.completed_successfully` | the last run finished successfully |
| `.completed_with_error` | the last run reached a conclusion and failed - `bkill` and LSF limit kills included |

Liveness is not a file. It is an exclusive `flock` held on `.lock` for as long as the wrapper owns the directory,
and the kernel releases it when the process dies by any means, including `kill -9` and a node crash. So there is
never a stale lock to clear - and `.lock` must never be deleted, because unlinking it lets the next run lock a
fresh inode and exclude nobody.

Both sentinels are cleared when a run starts and exactly one is written when it ends, so their absence is a
truthful "no verdict for what is on disk right now".

A second submission of a cohort while one is already running fails immediately with exit 75, naming the holder.
That is deliberate: both runs would otherwise share one `work/`, and the first to finish would delete it under
the second.

#### Reading the state

| State | `flock -n` | `.completed_successfully` | `.completed_with_error` |
| --- | --- | --- | --- |
| running now | busy | - | - |
| succeeded | free | yes | - |
| failed, incl. `bkill`ed | free | - | yes |
| died mid-run (`kill -9`, node crash) | free | - | - |

`flock -n <file> <command>` takes the lock, runs the command, and releases it - or, if something else already
holds the lock, runs nothing at all and exits with the code given to `-E`. So a check and a deletion are the same
one-liner with a different command on the end:

```bash
p="${PROJECT_DIR}/unmatched_variants_pipe"

# 1. Is a run using this directory? `true` does nothing, so this only reports.
if flock -n -E 75 "$p/.lock" true; then
    echo "free - nothing is using $p"
else
    echo "RUNNING - held by:"; cat "$p/.lock"
fi

# 2. Move the work directory, but only if nothing is using it. The lock is held
#    for as long as the mv takes, so a run cannot start underneath it.
flock -n -E 75 "$p/.lock" mv "$p/work" /path/to/to_delete/
echo $?   # 0 = moved.  75 = a run owns it, and nothing was touched.
```

Testing the lock needs only **read** permission on `.lock`, so this works against another user's running
pipeline. Moving their `work/` afterwards still needs write permission on their pipeline directory.

#### Writing the clean-up statement

Take the lock across both the decision and the move, never test-then-move, and require `.lock` to exist first:
on a directory that pre-dates this scheme `flock` would create one and report a live run as idle.

```bash
cd "${PROJECT_DIR}/.."
mkdir -p to_delete

find . -type d \( -name '*_pipe' -o -name '*_pipeline' \) -print0 |
while IFS= read -r -d '' p; do
    [[ -e "$p/.lock" ]] || { echo "SKIP (no .lock) $p"; continue; }

    flock -n -E 75 "$p/.lock" bash -c '
        p="$1"
        # --- the policy: pick one ---------------------------------------
        [[ -e "$p/.completed_successfully" ]] || exit 3    # succeeded only
        # [[ -e "$p/.completed_with_error" ]] || exit 3    # failed only
        # ! [[ -e "$p/.completed_successfully" || -e "$p/.completed_with_error" ]] || exit 3   # died mid-run
        # (no test at all)                                 # anything not running
        # ----------------------------------------------------------------
        for d in work tmp; do
            [[ -d "$p/$d" ]] || continue
            # ${p#./} first: a leading "./" would turn into "._" and hide the result
            mv -v "$p/$d" "to_delete/$(echo "${p#./}" | tr / _)_${d}"
        done
    ' _ "$p"

    case $? in
      0)  ;;
      75) echo "SKIP (RUNNING)  $p" ;;
      3)  echo "SKIP (policy)   $p" ;;
      *)  echo "ERROR           $p" ;;
    esac
done
# rm -rf to_delete/
```

Rules that keep this safe: **neither sentinel present means "died mid-run", never "succeeded"**; never unlink or
replace `.lock`; and if the pipeline directory is on a filesystem not mounted with `flock` (Lustre `localflock`,
NFS `local_lock=`) the lock is node-local and a sweep running elsewhere will not see it - the wrapper warns about
this at launch, but a script that deletes data should check `findmnt -T "$p" -no FSTYPE,OPTIONS` itself and refuse.

A lock that looks stale is a live file descriptor, not a leftover file: `lsof "$p/.lock"` names the process
holding it. `nextflow run` inherits the descriptor, so an orphaned nextflow keeps its directory protected even
after the wrapper is gone - which is the intended behaviour.

</details>

### Container registry

When running the pipeline for the first time on the farm you will need to provide credentials to pull singularity containers from the team113 sanger gitlab. You should be able to do this by running
```
module load singularity/3.11.4 
singularity remote login --username $(whoami) docker://gitlab-registry.internal.sanger.ac.uk
```

The pipeline can configured to run on either Sanger OpenStack secure-lustre instances or farm22 by changing the profile speicified:
`-profile secure_lustre` or `-profile farm22`. 

## Pipeline visualisation
Created using nextflow's in-built visualitation features.
```
nextflow run main.nf -preview -with-dag flowchart.mmd -params-file tests/testdata/test_params.json -profile secure_lustre
```


```mermaid
flowchart TB
    subgraph " "
    v0["Channel.fromPath"]
    v12["Channel.fromPath"]
    v24["Channel.fromPath"]
    v43["transcripts"]
    v45["transcripts"]
    v49["Channel.of"]
    v51["dbsnp_files"]
    v54["cgc_file"]
    v55["oncokb_file"]
    v56["hotspot_file"]
    v57["transcript_info"]
    v59["cgc_file"]
    v60["oncokb_file"]
    v61["hotspot_file"]
    v62["transcript_info"]
    v65["Channel.fromList"]
    v67["Channel.of"]
    end
    subgraph " "
    v11[" "]
    v23[" "]
    v35[" "]
    v48[" "]
    v53[" "]
    v64[" "]
    v70[" "]
    end
    v42([COUNT_NON_REF_GTS])
    v44([SUBSET_MATCHED])
    v46([SUBSET_UNMATCHED])
    v47([CHECK_SOMATIC_MNV_CALLS])
    v52([FIND_SNP_POSITIONS])
    v58([GENERATE_CONFIG_FILE])
    v63([FILTER_AND_FLAG_VARIANTS])
    v68([CATEGORISE_VARIANTS])
    v69([PLOT_VARIANTS])
    v1(( ))
    v13(( ))
    v50(( ))
    v66(( ))
    v0 --> v1
    v1 --> v11
    v12 --> v13
    v13 --> v23
    v24 --> v13
    v13 --> v35
    v1 --> v42
    v42 --> v58
    v42 --> v63
    v43 --> v44
    v13 --> v44
    v44 --> v58
    v44 --> v63
    v45 --> v46
    v13 --> v46
    v46 --> v58
    v46 --> v63
    v13 --> v47
    v47 --> v58
    v47 --> v48
    v47 --> v63
    v49 --> v50
    v51 --> v52
    v50 --> v52
    v52 --> v53
    v52 --> v58
    v52 --> v63
    v54 --> v58
    v55 --> v58
    v56 --> v58
    v57 --> v58
    v50 --> v58
    v58 --> v63
    v59 --> v63
    v60 --> v63
    v61 --> v63
    v62 --> v63
    v50 --> v63
    v63 --> v64
    v63 --> v66
    v65 --> v66
    v67 --> v68
    v66 --> v68
    v68 --> v69
    v69 --> v70

```

## Testing

This pipeline has been developed with the [nf-test](http://nf-test.com) testing framework. Unit tests and small test data are provided within the pipeline `test` subdirectory. A snapshot has been taken of the outputs of most steps in the pipeline to help detect regressions when editing. You can run all tests on openstack with:

```
nf-test test 
```
and individual tests with:
```
nf-test test tests/modules/ascat_exomes.nf.test
```

For faster testing of the flow of data through the pipeline **without running any of the tools involved**, stubs have been provided to mock the results of each succesful step.
```
nextflow run main.nf \
-params-file params.json \
-c tests/nextflow.config \
--stub-run
```

## Cutting a release

Cutting a new release requires a new semantic version tag, a changelog entry and
a commit of the updated version in every file that records it.

### One-off setup, per clone

Releases go through `git hf` (HubFlow). If it is not on your `PATH`, `module load git`.
In a fresh clone, enable it once:

```bash
git hf init   # writes this clone's hubflow branch/prefix config; the defaults are correct
```

That is the only setup required.

### Steps

1. `git hf release start <version>`
2. `./.update-version.sh <version>` — sets the semantic version in every file that
   records it (`assets/run_tumour_only.sh`, `docs/source/conf.py`, `nextflow.config`).
   Run `./.update-version.sh --help` for details. Commit the changes.
3. Update `CHANGELOG.md` and commit it.
4. `git hf release finish <version>`

## Asset release bundles

`assets/` is published to GitHub Releases as `projectify_asset_bundle.tar.gz` (plus a
`.sha256` of it) by `.github/workflows/publish-assets.yml`, so `dermanager projectify` can
fetch the files straight from the release CDN - no API call, no token, no rate limit:

```
https://github.com/team113sanger/dermatlas_tumour_only_nf/releases/download/<ref>/projectify_asset_bundle.tar.gz
```

| `<ref>` | Bundle contents | Updated |
| --- | --- | --- |
| `X.Y.Z` | `assets/` at that release tag | once, then immutable |
| `main-latest` | `assets/` at the head of `main`, i.e. the latest released state | every push to `main` |
| `develop-latest` | `assets/` at the head of `develop` | every push to `develop` |

The two `-latest` refs are fixed tags on pre-releases. Each push replaces the bundle attached
to the tag, so the download URL never changes and always serves that branch's current assets.
`releases/latest/download/...` is deliberately not used - it resolves only to the newest
non-pre-release, so it cannot address the rolling channels.

This repository is GitHub-primary. To publish a bundle for a
ref that predates the workflow, run it by hand from the GitHub Actions tab (*Publish
projectify asset bundle* -> *Run workflow*) with `ref` set to the tag or branch to build from.
