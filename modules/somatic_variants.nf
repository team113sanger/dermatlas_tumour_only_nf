process SUBSET_MAF {
    publishDir "${params.outdir}/${meta.analysis_type}_unfiltered", mode: 'copy', pattern: "*.maf"
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/maf:latest"
    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    path(transcripts)
    
    output:
    tuple val(meta), path("${meta.analysis_type}.canonical.coding.maf"), emit: maf
    
    script:
    list = file_list[0]
    """
    /opt/repo/reformat_vcf2maf.pl \
    --build GRCh38 \
    --keep_multi \
    --transcripts $transcripts  \
    --vcflist $list \
    --canonical --exclude_noncoding > ${meta.analysis_type}.canonical.coding.maf
    """

    stub:
    """
    echo "stub" > ${meta.analysis_type}.canonical.coding.maf
    """
}

process CHECK_SOMATIC_MNV_CALLS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/mnv_check", mode: 'copy', pattern: "*"

    input: 
    tuple val(meta), path(file_list), path(vcf_files)
    
    output:
    path("mnv_check.tsv"), emit: mnv_check
    path("mnv_check.log"), emit: mnv_log


    script:
    list = file_list[0]
    """
    cat $list | xargs -i zcat {} | /opt/repo/mnv_flagcheck.pl > mnv_check.tsv 2>mnv_check.log
    """

    stub:
    """
    echo -e "Sample\tMNV_Count" > mnv_check.tsv
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
    publishDir "${params.outdir}/snp_check", mode: 'copy', pattern: "*"

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

    stub:
    """
    echo -e "chr1\t1000000" > ${meta.sample_id}.positions
    echo -e "chr1\t1000000\trs123456\tA\tG" > ${meta.sample_id}.dbsnp.tsv
    """
}
