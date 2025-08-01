
process SUBSET_MAF {
    publishDir "${params.outdir}/${meta.analysis_type}", mode: 'copy', pattern: "*.maf"
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/maf:latest"
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
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/snp_check", mode: 'copy', pattern: "*.maf"

    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    
    output:
    path("mnv_check.tsv"), emit: mnv_check
    
    script:
    """
    cat $file_list | xargs -i zcat {} | /opt/repo/mnv_flagcheck.pl > mnv_check.tsv \
    2>mnv_check.log
    """
}

prcoess GENERATE_UNMATCHED_MAF {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/mafs", mode: 'copy', pattern: "*.maf"

    input:
        tuple val(meta), path(input_maf)
    output:
        tuple val(meta), path("unmatched.maf"), emit: unmatched_maf
    script:
    """
    head -n1 $input_maf > unmatched.maf
    grep -hwf $sample_list $input_maf >> unmatched.maf
    """
}   

process FIND_SNP_POSITIONS {
    container "quay.io/biocontainers/tabix:1.11--hdfd78af_0"
    publishDir "${params.outdir}/snp_check", mode: 'copy', pattern: "*.tsv"

    input:
    tuple val(meta), path(unmatched_maf)
    path(dbsnp_file)

    output:
    path("*.positions"), emit: snp_positions
    path("*.dbsnp.tsv"), emit: dbsnp_positions

    script:
    """
    cut -f 4,13 $unmatched_maf | grep -v Chromo > ${meta.sample_id}.positions
    tabix $dbsnp_file -R ${meta.sample_id}.positions > ${meta.sample_id}.dbsnp.tsv
    """
}
process FILTER_AND_FLAG_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/filtered", mode: 'copy', pattern: "*.maf"

    input:
    path(varcounts), path(dbsnp_positions), path(mnv_check), path(matched_maf), path(unmatched_maf)

    output:
    tuple val(meta), path("filtered.maf"), emit: filtered_maf

    script:
    """
    Rscript /opt/repo/unmatched_tumour_filter.R ${baseDir}/assets/filter_config.R"
    """
}