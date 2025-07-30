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

workflow {
    // include { FILTER_MAF } from './modules/filter_maf.nf' as FILTER_MATCHED
    // include { FILTER_MAF } from './modules/filter_maf.nf' as FILTER_UNMATCHED
    

    germline_vcfs = Channel.fromPath(params.germline_vcfs, checkIfExists: true)
        .splitText()
        .map { it.trim() }
        .filter { it != "" }
    
    basenames_channel = germline_vcfs
        .map { file(it).name }
        .collectFile(name: 'basenames.txt', newLine: true)
    
    files_list_channel = germline_vcfs
        .map { file(it) }
        .collect()
    
    basenames_channel.view { "Basenames file: $it" }
    files_list_channel.view { "Files list: $it" }

    germline_vcfs = basenames_channel.combine(files_list_channel)

    // COUNT_NON_REF_GTS(germline_vcfs)

    matched_somatics_vcfs = Channel.fromPath(params.matched_somatic, checkIfExists: true)
    .splitText()
    .map { it.trim() }
    .filter { it != "" }
    matched_channel = matched_somatics_vcfs
    .map { file(it).name }
    .collectFile(name: 'matched_basenames.txt', newLine: true)

    matched_samples = matched_somatics_vcfs
    .map { file(it).name.split('\\.')[0] }
    .unique()
    .collectFile(name: 'matched_sample_ids.txt', newLine: true)
    
    matched_files_list_channel = matched_somatics_vcfs
        .map { file(it) }
        .collect()
    
    unmatched_somatics_vcfs = Channel.fromPath(params.unmatched_somatic, checkIfExists: true)
    .splitText()
    .map { it.trim() }
    .filter { it != "" }
    unmatched_channel = unmatched_somatics_vcfs
    .map { file(it).name }
    .collectFile(name: 'unmatched_basenames.txt', newLine: true)

    unmatched_files_list_channel = unmatched_somatics_vcfs
    .map { file(it) }
    .collect()


    unmatched_samples = unmatched_somatics_vcfs
    .map { file(it).name.split('\\.')[0] }
    .unique()
    .collectFile(name: 'unmatched_sample_ids.txt', newLine: true)

    unmatched_samples.view { "Unmatched samples: $it" }
    matched_samples.view { "Matched samples: $it" }
    
    
    


    // FILTER_MATCHED()

}