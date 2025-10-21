process GENERATE_CONFIG_FILE {
    publishDir "${params.outdir}/release_${params.release_version}", mode: 'copy', pattern: "*.R"
    
    input:
    tuple val(meta), path(input_maf)
    path(varcounts)
    path(dbsnp_positions)
    path(mnv_check)
    tuple val(meta_m), path(matched_maf)
    tuple val(meta_u), path(unmatched_maf)
    path(cgc_file)
    path(oncokb_file)
    path(hotspot_file)
    path(transcript_info)

    output:
    path("config.R"), emit: config

    script:
    """
    cat > config.R << 'EOF'
    # Input a MAF file with DERMATLAS-filtered variant calls from unmatched tumours
    maf_file <- "${input_maf}"

    # Output file name  

    out_file <- "${meta.sample_id}.annotated.maf"
    maf_dir <- "intermediate_files"

    # Shared external data sources
    cgc_file <- "${cgc_file}"
    oncokb_file <- "${oncokb_file}"
    hotspot_file <- "${hotspot_file}"

    # Cohort-specific data (must be generated per cohort/study)
    unfiltered_matched_maf <- "${matched_maf}"
    unfiltered_unmatched_maf <- "${unmatched_maf}"
    germline_file <- "${varcounts}"
    snp_file <- "${dbsnp_positions}"
    mnv_file <- "${mnv_check}"
    gtf_file <- "${transcript_info}"
    EOF
    """

    stub:
    """
    echo 'stub' > config.R
    """
}

process FILTER_AND_FLAG_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter/feature/build_fix:35703fcc"
    publishDir "${params.outdir}/release_${params.release_version}/filtered/combined", mode: 'copy', pattern: "*.maf"
    publishDir "${params.outdir}/release_${params.release_version}/intermediate_files", mode: 'copy', pattern: "intermediate_files/*"

    input:
    tuple val(meta), path(input_maf)
    path(varcounts)
    path(dbsnp_positions)
    path(mnv_check)
    tuple val(meta_m), path(matched_maf)
    tuple val(meta_u), path(unmatched_maf)
    path(cgc_file)
    path(oncokb_file)
    path(hotspot_file)
    path(transcript_info)
    path(config_file)
    

    output:
    tuple val(meta), path("${meta.sample_id}.annotated.maf"), emit: filtered_maf
    path("intermediate_files/*"), emit: intermediate_files
    
    script:
    """
    Rscript /opt/repo/unmatched_tumour_filter.R ${config_file}
    """

    stub:
    """
    echo -e "Hugo_Symbol\tEntrez_Gene_Id\tCenter\tBarcode\tFlagging_Tier" > ${meta.sample_id}.annotated.maf
    echo -e "TP53\t7157\ttest_center\tsample1\t3" >> ${meta.sample_id}.annotated.maf
    echo -e "EGFR\t1956\ttest_center\tsample1\t5" >> ${meta.sample_id}.annotated.maf
    """
}
