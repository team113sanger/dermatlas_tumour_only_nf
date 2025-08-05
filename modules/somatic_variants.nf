
process SUBSET_MAF {
    publishDir "${params.outdir}/${meta.analysis_type}", mode: 'copy', pattern: "*.maf"
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/maf:latest"
    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    path(transcripts)
    
    output:
    tuple val(meta), path("${meta.analysis_type}.canonical.coding.maf"), emit: maf
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
    cat $file_list | xargs -i zcat {} | /opt/repo/mnv_flagcheck.pl > mnv_check.tsv 2>mnv_check.log
    """
}

// process GENERATE_UNMATCHED_MAF {
//     container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
//     publishDir "${params.outdir}/mafs", mode: 'copy', pattern: "*.maf"

//     input:
//         tuple val(meta), path(input_maf)
//     output:
//         tuple val(meta), path("unmatched.maf"), emit: unmatched_maf
//     script:
//     """
//     head -n1 $input_maf > unmatched.maf
//     grep -hwf $sample_list $input_maf >> unmatched.maf
//     """
// }   

process FIND_SNP_POSITIONS {
    container "quay.io/biocontainers/tabix:1.11--hdfd78af_0"
    publishDir "${params.outdir}/snp_check", mode: 'copy', pattern: "*.tsv"

    input:
    tuple val(meta), path(unmatched_maf)
    path(dbsnp_files)

    output:
    path("*.positions"), emit: snp_positions
    path("*.dbsnp.tsv"), emit: dbsnp_positions

    script:
     def dbsnp_file = dbsnp_files[0].name.split(".gz")[0]
    """
    cut -f 4,13 $unmatched_maf | grep -v Chromo > ${meta.sample_id}.positions
    tabix "${dbsnp_file}.gz" -R ${meta.sample_id}.positions > ${meta.sample_id}.dbsnp.tsv
    """
}
process FILTER_AND_FLAG_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/filtered/combined", mode: 'copy', pattern: "*.maf"

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
    path(config_file)

    output:
    tuple val(meta), path("${meta.sample_id}.annotated.maf"), emit: filtered_maf

    script:
    """
    Rscript /opt/repo/unmatched_tumour_filter.R ${config_file}
    """
}

process GENERATE_CONFIG_FILE {
    input:
    tuple val(meta), path(input_maf)
    path(varcounts)
    path(dbsnp_positions)
    path(mnv_check)
    path(matched_maf)
    path(unmatched_maf)
    path(cgc_file)
    path(oncokb_file)
    path(hotspot_file)

    output:
    tuple val(meta), path("config.R"), emit: config

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
    EOF
    """
}
