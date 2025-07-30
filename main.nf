#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

process COUNT_NON_REF_GTS {
  container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
  input:
  tuple val(metadata), path(listfile), path(vcf_files)
  
  output:
  tuple val(metadata), path("*germline_varcounts.tsv"), emit: varcounts

  script:
  """
  /opt/repo/count_nonref_gts.pl $file_list > germline_varcounts.tsv
  """
}

process FILTER_MAF {
    input: 
    tuple val(meta), path(list_file), path(vcf_files)
    path(transcripts)
    
    output:
        path("${meta.analysis_type}.canonical.coding.maf"), emit: maf
    script:
    """
    /opt/repo/reformat_vcf2maf.pl \
    --build GRCh38 \
    --keep_multi \
    --transcripts $transcripts  \
    --vcflist $list_file \
    --canonical --exclude_noncoding > ${meta.analysis_type}.canonical.coding.maf
    """
}

process CHECK_SOMATIC_MNV_CALLS {
    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    output:
    path("mnv_check.tsv"), emit: mnv_check

    """
    cat $file_list | xargs -i zcat {} | /opt/repo/mnv_flagcheck.pl > mnv_check.tsv \
    2>mnv_check.log"
    """
}

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
    // include { FILTER_MAF } from './modules/filter_maf.nf' as FILTER_MATCHED
    // include { FILTER_MAF } from './modules/filter_maf.nf' as FILTER_UNMATCHED
    
    def (germline_basenames, germline_files_list, _) = processVcfChannel(params.germline_vcfs, 'germline')
    def (matched_basenames, matched_files_list, matched_samples) = processVcfChannel(params.matched_somatic, 'matched')
    def (unmatched_basenames, unmatched_files_list, unmatched_samples) = processVcfChannel(params.unmatched_somatic, 'unmatched')
    
    germline_basenames.view { "Germline basenames file: $it" }
    germline_files_list.view { "Germline files list: $it" }
    matched_samples.view { "Matched samples: $it" }
    unmatched_samples.view { "Unmatched samples: $it" }
    
    germline_vcfs_combined = germline_basenames.combine(germline_files_list)
    
    // COUNT_NON_REF_GTS(germline_vcfs_combined)
    // FILTER_MATCHED()

}