# Nextflow: Tumour-Only Variant Filtering Pipeline

Variant call filtering and annotation for unmatched tumour samples in DERMATLAS can be run with a Nextflow pipeline in a largely "set-and-forget" manner. This document contains an SOP for configuring and running the pipeline, which replicates the [steps detailed in the manual process](https://confluence.sanger.ac.uk/spaces/CAS/pages/156434665/DERMATLAS+Unmatched+tumour+variant+call+filtering). For a more detailed explanation of the pipeline, inputs, steps and requirements can be found within the pipeline project [README](https://github.com/team113sanger/dermatlas_tumour_only_nf/blob/develop/README.md)

## Purpose (Mirrored from [manual](https://confluence.sanger.ac.uk/spaces/CAS/pages/156434665/DERMATLAS+Unmatched+tumour+variant+call+filtering))
 
In DERMATLAS we have collected many samples that do not have matched normal tissue, or, the matched normal sample was collected but failed sequencing or QC requirements. We therefore perform variant calling using the tumour BAM and an *in-silico* BAM for CaVEMan and Pindel. As such, the variant calls from unmatched tumour samples will have germline variants and artefacts that would normally be filtered out when using a matched normal BAM. Additionally since our samples are obtained from FFPE tissue, the starting DNA tends to be degraded, and can have abundant C>T artefacts. 

Because of these issues we have developed a tiered filtering-based method that attempts to exclude germline variants and artefacts by sharing info across the cohort. We then identify somatic variants with varying degrees of confidence, with an emphasis on identifying variants that may be driver mutations.

For this, the pipeline uses resources from Cancer Hotspots, ClinVar, COSMIC, OncoKB, dbSNP to weight the likelihood that a variant is genuine.

When identifying germline variants and artefacts, we leverage any available (unfiltered, flagged) germline variant calls from the entire cohort, and unfiltered (but flagged) somatic variants (matched and unmatched tumours). The aim of using the unfiltered variants is to identify those that may have passed QC in the unmatched tumour, but failed QC in several other samples, which is an indication that the variant is likely an artefact or a germline variant.

:::{note}
**Tumour Mutation Rate Estimation**

Estimates of tumour mutation rate using unmatched tumours are unlikely to give an accurate result.
:::

For further details on the filtering rationale see [DERMATLAS_tumour-only_filtering-070725-kw10.pdf](https://drive.google.com/file/d/1n1cf2WudFrU4NlMw_XD9lWYVomk-DUMR/view)

## Workflow Overview

1. Preparing input files
   - Create VCF file lists for germline variants
   - Create VCF file lists for matched somatic variants
   - Create VCF file lists for unmatched somatic variants
   - Generate input MAF file from unmatched tumours
2. Generating the pipeline config file
3. Running the pipeline
4. Reviewing the outputs

## Workflow Steps

### 1. Preparing input files

The Nextflow pipeline requires several input files to be prepared beforehand. These input files will be specified in the pipeline configuration file (see Step 2).

:::{important}
**Prerequisites**

The variant call files used as inputs are generated when following the SOPs for somatic and germline variant calling:
- [Nextflow: Somatic variant calling pipeline](https://confluence.sanger.ac.uk/spaces/CAS/pages/150209099/Nextflow+Somatic+variant+calling+pipeline) or DERMATLAS - Post-processing CaVEMan and Pindel calls
- [Nextflow: Germline variant calling pipeline](https://dermatlas-germlinepost-nf-dermatlas-analysis-met-51a10bf1e7a767.pages.internal.sanger.ac.uk) or DERMATLAS - Germline calling with GATK for WES
:::

#### Setup working directory

Typically, we perform this analysis on a multi-cohort or PU level. To do run for a PU, first, set up your working directory as the top level PU directory and define key variables:

```bash
# Set your PU number and PUDIR path
PU=7
PUDIR=/lustre/scratch127/casm/projects/dermatlas/projects/dermatlas_pu${PU}_project_dir/
cd ${PUDIR}

# Your release number
i=1

# Create working directory
mkdir -p ${PUDIR}/analysis/unmatched/release_v${i}
cd ${PUDIR}/analysis/unmatched/release_v${i}
```

#### 1.1 Create germline VCF file list

Create a file containing the full paths to unfiltered germline VCF files from matched normal samples across all cohorts. These VCFs will be processed by the pipeline to count non-reference genotypes for flagging germline variants.

```bash
# Working directory
cd ${PUDIR}/analysis/unmatched/release_v${i}

# Create a list of unfiltered (but flagged) germline VCFs
# There should be a VCF for snps and another for indels for each cohort
# List all cohort study directories that contain WES data
ls -1 $PUDIR | grep WES > studies.list

# Generate the germline VCF list
for f in `cat studies.list`; do
  dir $PUDIR/$f/analysis/germline/vcf/Final_joint_call/*.marked.vcf.gz
done > germline_unfiltered/germline_vcfs.list

# Your germline_variant_files.tsv should have the full path to files
# for snps (eg. 6937_cohort_snp.marked.vcf.gz) and another
# for indels (6937_cohort_indel.marked.vcf.gz) for each tumour type
```

#### 1.2 Create somatic VCF file lists

Create file lists for both matched and unmatched tumour somatic variant calls. The pipeline will use these to create references for filtering artefacts and germline variants.

The `*smartphase.vep.vcf.gz` (CaVEMan SNVs) and `*pindel.vep.vcf.gz` (Pindel indels) files are used.

```bash
# Working directory
cd ${PUDIR}/analysis/unmatched/release_v${i}

# Matched tumour VCF list
for f in `cat studies.list`; do
  for g in ${PUDIR}/$f/metadata/*one_tumour_per_patient_matched_tum.txt; do
    cat $g | grep -v ${PUDIR}/${f}/metadata/rejected_DNA_samples.list > matched_unfiltered/${f}-samples.list
    dir ${PUDIR}/$f/analysis/caveman_files/*/*smartphase.vep.vcf.gz $PUDIR/$f/analysis/pindel_files/*/*pindel.vep.vcf.gz |
      grep -f matched_unfiltered/${f}-samples.list
  done
done > matched_unfiltered/matched_vcfs.list

# Unmatched tumour VCF list
for f in `cat studies.list`; do
  for g in $PUDIR/$f/metadata/*one_tumour_per_patient_unmatched_tum.txt; do
    cat $g | grep -v $PUDIR/$f/metadata/rejected_DNA_samples.list > unmatched_unfiltered/${f}-samples.list
    dir $PUDIR/$f/analysis/caveman_files/*/*smartphase.vep.vcf.gz $PUDIR/$f/analysis/pindel_files/*/*pindel.vep.vcf.gz |
      grep -f unmatched_unfiltered/${f}-samples.list
  done
done > unmatched_unfiltered/unmatched_vcfs.list
```

#### 1.3 Generate the input MAF file

Variant calls for the unmatched tumours are in the `all_samples` subdirectory in each cohort's variants **release** directory. Because the files contain calls from matched and unmatched tumours, we need to parse out the variants from the unmatched samples.

The files used are from your somatic variant release, which should have been generated from your CaVEMan/Pindel analysis.

```bash
# Working directory
# cd  ${PUDIR}/combined_analysis/unmatched_tumours/release_v${i}

# Define the somatic variant release version to use
varrel=1

# Copy the MAF header from the first cohort
for f in `cat studies.list | head -n1`; do
  head -n1 $PUDIR/$f/analysis/variants_combined/release_v${varrel}/all_tumours/all_samples/*filtered_mutations_all_allTum_keep.maf \
    > mafs/combined_cohorts_keep_unmatched.maf
done

# Get the lines from unmatched tumours
for f in `cat studies.list`; do
  grep -hwf unmatched_unfiltered/${f}-samples.list $PUDIR/$f/analysis/variants_combined/release_v${varrel}/all_tumours/all_samples/*filtered_mutations_all_allTum_keep.maf
done >> mafs/combined_cohorts_keep_unmatched.maf

```


### 2. Generating the pipeline config file

The Nextflow pipeline's config file encodes all of the input files and options to pass to the pipeline. The configuration file is provided in the pipeline repository at `assets/tumour_only.config`; for a project provisioned from the [Dermatlas cohorts page](https://team113.sanger.ac.uk/dermatlas/cohorts/) it is already in place at `commands/unmatched_variants_pipe/tumour_only.config`, and reads every location from the project's `source_me.sh` (`ANALYSIS_DIR`, and the cohort sample list `DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED`). If you place the step 1 files at the paths below, it needs no editing.

For most pipeline runs there are **7 parameters** that you need to specify:

| Parameter | Description | Example |
|:----------|:-----------|:--------|
| `germline_vcfs` | Path to germline VCF list created in step 1.1 | `"${ANALYSIS_DIR}/unmatched/germline_variant_files.tsv"` |
| `matched_somatic_vcfs` | Path to matched somatic VCF list created in step 1.2 | `"${ANALYSIS_DIR}/unmatched/matched_somatic_vcfs.tsv"` |
| `unmatched_somatic_vcfs` | Path to unmatched somatic VCF list created in step 1.2 | `"${ANALYSIS_DIR}/unmatched/unmatched_somatic_vcfs.tsv"` |
| `unmatched_maf` | Path to combined unmatched MAF created in step 1.3 | `"${ANALYSIS_DIR}/unmatched/combined_cohorts_keep_unmatched.maf"` |
| `release_version` | Release version identifier | `"v1"` |
| `outdir` | Output directory for results | `"${ANALYSIS_DIR}/unmatched_variant_calling"` |
| `cohorts` | Map of cohort names to sample list files | See example below |

There are additional parameters specified within the config file (paths to resource files like COSMIC, OncoKB, dbSNP), but these won't normally need changing as they are configured per-profile (farm22 vs secure_lustre).

**Example configuration file (tumour_only.config):**

```groovy
params {
    // Input files (created in Step 1)
    germline_vcfs = "${ANALYSIS_DIR}/unmatched/germline_variant_files.tsv"
    unmatched_somatic_vcfs = "${ANALYSIS_DIR}/unmatched/unmatched_somatic_vcfs.tsv"
    matched_somatic_vcfs = "${ANALYSIS_DIR}/unmatched/matched_somatic_vcfs.tsv"
    unmatched_maf = "${ANALYSIS_DIR}/unmatched/combined_cohorts_keep_unmatched.maf"

    // Release information
    outdir = "${ANALYSIS_DIR}/unmatched_variant_calling"
    release_version = "v1"

    transcripts = "/lustre/scratch127/casm/projects/dermatlas/resources/ensembl/dermatlas_noncanonical_transcripts_ens103.v2.tsv"
    cgc_file = "/lustre/scratch127/casm/projects/dermatlas/resources/tumour-only/cgc_genes.list"
    oncokb_file = "/lustre/scratch127/casm/projects/dermatlas/resources/oncokb/cancerGeneList.list"
    hotspot_file = "/lustre/scratch127/casm/projects/dermatlas/resources/tumour-only/cancerhotspots_metadata.GRCh38.v2.tsv"
    dbsnp_file = "/lustre/scratch127/casm/projects/dermatlas/resources/tumour-only/dbSNP155.GRCh38.GCF_000001405.39_AFS.WES5.tsv.gz{,.tbi}"
    transcript_info = "/lustre/scratch127/casm/projects/dermatlas/resources/ensembl/Homo_sapiens.GRCh38.103.chr.gtf.gz"

    // Define cohorts with their sample lists for QC plotting
    // Each cohort name will be used as a subdirectory in the output
    cohorts = [
        "all_samples": "${DNA_PAIR_LIST_ONE_TUMOUR_PER_PATIENT_UNMATCHED}",
        // Add more cohorts as needed:
        // "cohort2": "${PROJECT_DIR}/metadata/cohort2_samples.tsv",
    ]
}
```

:::{important}
**Resource Files**

The pipeline automatically uses DERMATLAS resource files (COSMIC, OncoKB, Cancer Hotspots, dbSNP) that are pre-configured in the farm22 and secure_lustre profiles. These paths are maintained centrally and typically don't need to be changed.
:::

### 3. Running the pipeline

When all input files have been prepared and the configuration file is set up, you can run the pipeline. The recommended way is to use a wrapper script that submits Nextflow as a job.

#### Launching the pipeline

The pipeline is launched with the wrapper script `assets/run_tumour_only.sh`. For a project provisioned from the [Dermatlas cohorts page](https://team113.sanger.ac.uk/dermatlas/cohorts/) it is already in place at `commands/unmatched_variants_pipe/run_tumour_only.sh`, and needs no editing: it sources the project's `source_me.sh`, checks the environment, and runs the release named by its `REVISION` with `commands/unmatched_variants_pipe/tumour_only.config`.

Submit it from the project directory:

```bash
cd ${PROJECT_DIR}
bsub -e logs/tumour_only.e -o logs/tumour_only.o < commands/unmatched_variants_pipe/run_tumour_only.sh
```

To run without a dermanager `source_me.sh`, or to opt out of website logging, Slack notifications or work-directory cleanup, see "Without the website" and "Toggles" in the pipeline [README](https://github.com/team113sanger/dermatlas_tumour_only_nf/blob/develop/README.md).

The bsub magic at the start of the wrapper script will send a Nextflow "master job" to the queue named in its `#BSUB -q` line, which looks after all other jobs. Nextflow will shortly start submitting jobs on your behalf to the relevant queues.

:::{note}
**Monitoring the Pipeline**

You can monitor the pipeline progress by checking:
- The master job log: `logs/tumour_only.o`
- The Nextflow log: `unmatched_variants_pipe/logs/nextflow-run-<RUN_ID>.log`
- Individual process logs in the Nextflow work directories under `unmatched_variants_pipe/work/`
:::

#### Troubleshooting problem runs

There are several reasons the pipeline might fail including bugs in the pipeline, issues with LSF, or misconfiguration. In most cases (especially when you suspect a farm/LSF failure), simply re-submitting the pipeline will trigger the Nextflow `-resume` directive and the pipeline will pick up where it left off:

```bash
bsub -e logs/tumour_only_retry.e -o logs/tumour_only_retry.o < commands/unmatched_variants_pipe/run_tumour_only.sh
```

When jobs fail, Nextflow will provide the path to the directory a failed job was run in. Inspect the files with:

```bash
ls -la /path/to/work/directory
cat /path/to/work/directory/.command.err
cat /path/to/work/directory/.command.out
cat /path/to/work/directory/.command.sh
```

### 4. Pipeline outputs

The pipeline generates filtered variant calls with tiered annotations and QC plots for each cohort and filtering tier.

#### Main output directory structure

```
${PROJECT_DIR}/analysis/unmatched_variant_calling/release_v${i}/
├── germline_counts/
│   └── germline_varcounts.tsv                      # Germline variant counts
├── matched_somatic/
│   └── matched_somatic.canonical.coding.maf        # Matched tumour variants (PON)
├── unmatched_somatic/
│   └── unmatched_somatic.canonical.coding.maf      # Unmatched tumour variants (PON)
├── mnv_check/
│   └── mnv_check.tsv                                # MNV quality check results
├── dbsnp_annotation/
│   └── dbsnp_positions.tsv                          # dbSNP annotations
├── filtered_variants/
│   └── combined_cohorts_keep_unmatched.annotated.maf  # Main output: filtered and annotated variants
└── qc_plots/
    └── [cohort_name]/
        └── tier_[2-10]/
            ├── [cohort]_tier[N].maf                 # Variants filtered at tier N
            ├── AF_vs_depth_recurrent_genes.pdf
            ├── AF_vs_depth_recurrent_sites.pdf
            ├── AF_vs_depth_snv_samples.pdf
            ├── gene_tileplot.pdf
            ├── mutation_types_barplot_samples.pdf
            ├── top_recurrently_mutated_genes.tsv
            └── top_recurrently_mutated_sites.tsv
```

#### Understanding the outputs

**Filtered Variants MAF:**

The main output is `filtered_variants/combined_cohorts_keep_unmatched.annotated.maf`, which contains all variants from the input MAF with additional annotation columns:

- **Flagging_Tier**: Integer from 1-10 indicating confidence level (higher = more confident somatic variant)
- Additional columns for germline counts, PON frequencies, cancer gene annotations, etc.

:::{important}
**Flagging Tiers Explained**

An explanation of the flagging tier system can be found in DERMATLAS_tumour-only_filtering-140325-kw10.pdf. Generally:
- **Tiers 8-10**: High confidence somatic variants
- **Tiers 5-7**: Moderate confidence
- **Tiers 2-4**: Lower confidence, may include artefacts
:::

**QC Plots:**

For each cohort and tier threshold (2-10), the pipeline generates:

- **Gene tile plots**: Show recurrently mutated genes across samples
- **AF vs depth plots**: Visualize allele frequency vs read depth for different variant categories
- **Mutation type barplots**: Show distribution of substitution types per sample

These plots help determine the appropriate tier threshold for your analysis. Typically, tiers 5-8 provide a good balance between sensitivity and specificity.

**Example QC output for a single cohort and tier:**

```
qc_plots/7136_Malignant_proliferating_pilar_tumour/tier_5/
├── 7136_tier5.maf
├── AF_vs_depth_recurrent_genes.pdf
├── AF_vs_depth_recurrent_sites.pdf
├── AF_vs_depth_snv_samples.pdf
├── gene_tileplot.pdf
├── gene_tileplot_gene_order.txt
├── gene_tileplot_sample_order.txt
├── gene_tileplot.tsv
├── mutation_types_barplot_proportion_samples.pdf
├── mutation_types_barplot_samples.pdf
├── top_genes.list
├── top_recurrently_mutated_genes.tsv
└── top_recurrently_mutated_sites.tsv
```
