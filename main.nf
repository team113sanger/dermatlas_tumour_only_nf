#!/usr/bin/env nextflow
nextflow.enable.dsl = 2
include { COUNT_NON_REF_GTS } from "./modules/germline_variants.nf"
include { SUBSET_MAF as SUBSET_MATCHED } from "./modules/somatic_variants.nf" 
include { SUBSET_MAF as SUBSET_UNMATCHED } from "./modules/somatic_variants.nf" 
include { CHECK_SOMATIC_MNV_CALLS; FIND_SNP_POSITIONS} from "./modules/somatic_variants.nf"
include { GENERATE_CONFIG_FILE; FILTER_AND_FLAG_VARIANTS } from "./modules/variant_filtering.nf"
include { CATEGORISE_VARIANTS; PLOT_VARIANTS } from "./modules/categorise_variants.nf"

// Every input is a file of VCF paths, one per line. Each VCF list is turned into
// three things the downstream processes need: a basenames file (the list the perl
// tools read, rewritten to the staged filenames), the files themselves (so
// Nextflow stages them next to that list), and the sample ids. The basenames file
// and the file list must always be derived from the SAME `vcf_param` - staging one
// cohort's VCFs against another cohort's basenames leaves the named files absent
// from the work directory, which the perl tools report on stderr but do not exit
// non-zero for, so the run "succeeds" with empty output.
def processVcfChannel(vcf_param, prefix) {
    def vcfs = Channel.fromPath(vcf_param, checkIfExists: true)
        .splitText()
        .map { it.trim() }
        .filter { it != "" }
    
    def basenames = vcfs
        .map { file(it).name }
        .collectFile(name: "${prefix}_basenames.txt", newLine: true)
    
    def files_list = vcfs
        .map { file(it) }
        .collect()
    
    def samples = vcfs
        .map { file(it).name.split('\\.')[0] }
        .unique()
        .collectFile(name: "${prefix}_sample_ids.txt", newLine: true)
    
    return [basenames, files_list, samples]
}

// Pair a cohort's basenames file with its own staged VCFs, tagged with the
// analysis type used for output naming and publish paths.
def pairListWithVcfs(basenames, files_list, analysis_type) {
    return basenames
        .merge(files_list) { list, vcfs -> tuple(list, vcfs) }
        .map { list, vcfs -> tuple(["analysis_type": analysis_type], list, vcfs) }
}

workflow TUMOUR_ONLY_CALLING {

    // Fail fast on unset params rather than part way through the run. Several of
    // these flow into output paths and filenames, where an unset value would
    // silently produce e.g. a "release_null" directory.
    def required = [
        'germline_vcfs', 'matched_somatic_vcfs', 'unmatched_somatic_vcfs',
        'unmatched_maf', 'study_id', 'release_version', 'transcripts',
        'transcript_info', 'cgc_file', 'oncokb_file', 'hotspot_file', 'dbsnp_file',
    ]
    def missing = required.findAll { !params[it] }
    if (missing) {
        error "ERROR: the following required params are unset: ${missing.join(', ')}. " +
              "Set them in the run config passed with -c (see assets/tumour_only.config); " +
              "reference data paths are supplied by the -profile."
    }

    // Cohorts drive every tiering and plotting output. An empty map is not an
    // error Nextflow would raise - it just produces no downstream tasks at all.
    if (!params.cohorts || params.cohorts.isEmpty()) {
        error "ERROR: params.cohorts must be defined with at least one cohort. " +
              "Example: cohorts = ['cohort_name': '/path/to/sample_list.tsv']"
    }

    log.info("Processing cohorts: ${params.cohorts.keySet().join(', ')}")

    // Reference data, resolved once and checked up front so a mistyped path fails
    // at launch rather than after the first processes have run.
    transcripts     = file(params.transcripts, checkIfExists: true)
    transcript_info = file(params.transcript_info, checkIfExists: true)
    cgc_file        = file(params.cgc_file, checkIfExists: true)
    oncokb_file     = file(params.oncokb_file, checkIfExists: true)
    hotspot_file    = file(params.hotspot_file, checkIfExists: true)
    // files() not file(): the dbsnp param is a "...{,.tbi}" glob, and file() would
    // return a bare Path rather than a list if it ever matched only one of the
    // pair - which FIND_SNP_POSITIONS indexes into as dbsnp_files[0].
    dbsnp_files     = files(params.dbsnp_file, checkIfExists: true)

    def (germline_basenames, germline_files_list, _germline_samples) = processVcfChannel(params.germline_vcfs, 'germline')
    def (matched_basenames, matched_files_list, _matched_samples) = processVcfChannel(params.matched_somatic_vcfs, 'matched')
    def (unmatched_basenames, unmatched_files_list, _unmatched_samples) = processVcfChannel(params.unmatched_somatic_vcfs, 'unmatched')

    germline_vcfs_combined = germline_basenames
        .merge(germline_files_list) { list, vcfs -> tuple(list, vcfs) }
    matched_vcfs_combined = pairListWithVcfs(matched_basenames, matched_files_list, "matched")
    unmatched_vcfs_combined = pairListWithVcfs(unmatched_basenames, unmatched_files_list, "unmatched")

    COUNT_NON_REF_GTS(germline_vcfs_combined)
    SUBSET_MATCHED(matched_vcfs_combined, transcripts)
    SUBSET_UNMATCHED(unmatched_vcfs_combined, transcripts)
    
    CHECK_SOMATIC_MNV_CALLS(unmatched_vcfs_combined)

    maf_ch = Channel.of(file(params.unmatched_maf, checkIfExists: true))
    .map{ file ->
        def meta = ["sample_id": params.study_id]
        return tuple(meta, file)}

    FIND_SNP_POSITIONS(maf_ch, dbsnp_files)

      GENERATE_CONFIG_FILE(
        maf_ch,
        COUNT_NON_REF_GTS.out.varcounts,
        FIND_SNP_POSITIONS.out.dbsnp_positions,
        CHECK_SOMATIC_MNV_CALLS.out.mnv_check,
        SUBSET_MATCHED.out.maf,
        SUBSET_UNMATCHED.out.maf,
        cgc_file,
        oncokb_file,
        hotspot_file,
        transcript_info
    )

    FILTER_AND_FLAG_VARIANTS(
        maf_ch,
        COUNT_NON_REF_GTS.out.varcounts,
        FIND_SNP_POSITIONS.out.dbsnp_positions,
        CHECK_SOMATIC_MNV_CALLS.out.mnv_check,
        SUBSET_MATCHED.out.maf,
        SUBSET_UNMATCHED.out.maf,
        cgc_file,
        oncokb_file,
        hotspot_file,
        transcript_info,
        GENERATE_CONFIG_FILE.out.config
    )
    // Create channel of cohort-sample_list tuples
    // params.cohorts should be a map like: ["cohort1": "/path/to/list1.tsv", "cohort2": "/path/to/list2.tsv"]
    cohort_sample_sets = Channel.fromList(
        params.cohorts.collect { cohort, sample_list ->
            tuple(cohort, file(sample_list, checkIfExists: true))
        }
    )

    // Combine filtered_maf with each cohort_sample_set
    maf_with_cohorts = FILTER_AND_FLAG_VARIANTS.out.filtered_maf.combine(cohort_sample_sets)

    CATEGORISE_VARIANTS(
        maf_with_cohorts,
        Channel.of(2,3,4,5,6,7,8,9,10)
    )
    PLOT_VARIANTS(
        CATEGORISE_VARIANTS.out.tier_maf
    )



}

workflow {
    TUMOUR_ONLY_CALLING()
}

workflow.onComplete {
    // Runs on both success and failure, after all processes have finished.
    // All reporting (Slack + analysis-log) is handled in one reusable call.
    Utils.reportRun(workflow, params)
}
