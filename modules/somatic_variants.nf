
process FILTER_MAF {
    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    path(transcripts)
    
    output:
        path("${meta.analysis_type}.canonical.coding.maf"), emit: maf
    script:
    """
    /opt/repo/reformat_vcf2maf.pl \
    --build GRCh38 \
    --keep_multi \
    --transcripts $transcripts  \
    --vcflist $file_list \
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