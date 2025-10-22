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
- `sample_list`: path to a file containing sample IDs to retain in MAF and plot outputs (one ID per line)
- `outdir`: path to the directory where results will be written

## Usage 

The recommended way to launch this pipeline is using a wrapper script (e.g. `bsub < my_wrapper.sh`) that submits nextflow as a job and records the version (**e.g.** `-r 0.1.1`)  and the `.json` parameter file supplied for a run.

An example wrapper script is included in the `assets` directory (`assets/run_tumour_only.sh`)

When running the pipeline for the first time on the farm you will need to provide credentials to pull singularity containers from the team113 sanger gitlab. You should be able to do this by running

```module load singularity/3.11.4 
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



