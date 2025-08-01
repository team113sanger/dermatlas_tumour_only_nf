#!/usr/bin/env nextflow
nextflow.enable.dsl = 2
include { COUNT_NON_REF_GTS } from "./modules/germline_variants.nf"
include { FILTER_MAF as FILTER_MATCHED } from "./modules/somatic_variants.nf" 
include { FILTER_MAF as FILTER_UNMATCHED } from "./modules/somatic_variants.nf" 
include { CHECK_SOMATIC_MNV_CALLS } from "./modules/somatic_variants.nf"

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

workflow {
    
    def (germline_basenames, germline_files_list, _) = processVcfChannel(params.germline_vcfs, 'germline')
    def (matched_basenames, matched_files_list, matched_samples) = processVcfChannel(params.matched_somatic, 'matched')
    def (unmatched_basenames, unmatched_files_list, unmatched_samples) = processVcfChannel(params.unmatched_somatic, 'unmatched')
    
    germline_basenames.view { "Germline basenames file: $it" }
    germline_files_list.view { "Germline files list: $it" }
    matched_samples.view { "Matched samples: $it" }
    unmatched_samples.view { "Unmatched samples: $it" }
    
    germline_vcfs_combined = germline_basenames
    .merge(germline_files_list) { a,b -> tuple(a,b)}
    matched_vcfs_combined = matched_basenames
    .merge(matched_files_list) { a,b -> tuple(a,b)}
    .map { files,list -> tuple(["analysis_type": "matched"], files,list) }

    unmatched_vcfs_combined = unmatched_basenames.combine(unmatched_files_list)
    .merge(matched_files_list) { a,b -> tuple(a,b)}
    .map { files,list -> tuple(["analysis_type": "unmatched"], files,list) }
    
    germline_vcfs_combined.view { "Germline combined: $it" }
    matched_vcfs_combined.view { "Matched combined: $it" }
    unmatched_vcfs_combined.view { "Unmatched combined: $it" }
    
    COUNT_NON_REF_GTS(germline_vcfs_combined)
    FILTER_MATCHED(matched_vcfs_combined, file(params.transcripts))
    FILTER_UNMATCHED(unmatched_vcfs_combined,file(params.transcripts))
    CHECK_SOMATIC_MNV_CALLS(matched_vcfs_combined)
}