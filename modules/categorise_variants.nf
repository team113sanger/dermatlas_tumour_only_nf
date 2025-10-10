process CATEGORISE_VARIANTS {
    publishDir path: { "${params.outdir}/release_${params.release_version}/QC_keep/qc_tier${tier}_${cohort}" }, mode: 'copy', pattern: "*"

    input:
    tuple val(meta), path(filtered_maf)
    each cohort_set
    each tier

    output:
    tuple val(meta), val(tier), val(cohort), path("${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf"), path(sample_list), emit: tier_maf

    script:
    cohort = cohort_set[0]
    sample_list = cohort_set[1]
    """

    # Find column numbers for Flagging_Tier and Tumor_Sample_Barcode
    tier_col=\$(head -n1 ${filtered_maf} | awk -v RS='\t' '/Flagging_Tier/{print NR; exit}')
    sample_col=\$(head -n1 ${filtered_maf} | awk -v RS='\t' '/Tumor_Sample_Barcode/{print NR; exit}')

    # Filter MAF file based on tier and sample list
    awk -v tier_col=\$tier_col -v sample_col=\$sample_col -v tier=${tier} '
        BEGIN {
            OFS=IFS="\t"
            # Load sample list into associative array
            while ((getline < "${sample_list}") > 0) {
                samples[\$1] = 1
            }
            close("${sample_list}")
        }
        # Keep header line or rows that match tier and are in sample list
        /^Hugo/ || (\$tier_col >= tier && \$sample_col in samples)
    ' ${filtered_maf} > "${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf"
    """

    stub:
    cohort = cohort_set[0]
    sample_list = cohort_set[1]
    """
    echo -e "Hugo_Symbol\tEntrez_Gene_Id\tCenter\tBarcode\tFlagging_Tier" > ${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf
    echo -e "TP53\t7157\ttest_center\tsample1\t${tier}" >> ${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf
    """
}

process PLOT_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/maf"
    publishDir path: { "${params.outdir}/release_${params.release_version}/QC_keep/qc_tier${tier}_${cohort}" }, mode: 'copy', pattern: "*"

    input:
    tuple val(meta), val(tier), val(cohort), path(tier_maf), path(sample_list)

    output:
    path("*"), emit: plots

    script:
    """
    # Find sample column number
    sample_col=\$(head -n1 ${tier_maf} | tr '\t' '\n' | grep -n Barcode | cut -f 1 -d ":")
    
    # Calculate plot height based on number of samples
    plot_height=\$(cat ${sample_list} | wc -l)
    check=\$(echo \$plot_height / 5 | bc -l | perl -ne 's/\\S+\\.(\\S+)/\$1/;print')
    
    if [[ "\$plot_height" -le 5 ]]; then
        plot_height=1
    elif [[ "\$check" -gt 0 ]]; then
        plot_height=\$((\$(echo \$plot_height / 5 | bc) + 1))
    else
        plot_height=\$((\$plot_height / 5))
    fi
    
    plot_height=\$(echo \$plot_height*1.5 | bc -l)
    
    # Generate VAF vs depth plot
    Rscript /opt/repo/plot_vaf_vs_depth_from_maf.R --file ${tier_maf} --samplefile ${sample_list} --width 10 --height \$plot_height -ncol 5
    
    # Extract top genes and create tile plot
    cut -f 3 top_recurrently_mutated_genes.tsv | sort -u | grep -v Hugo_ > top_genes.list
    
    Rscript /opt/repo/maketileplot_from_maf.R -a ${tier_maf} -s ${sample_list} -g top_genes.list --sortbyfrequency -w 8 -t 5
    
    echo "Rscript /opt/repo/maketileplot_from_maf.R -a ${tier_maf} -s ${sample_list} -g top_genes.list --sortbyfrequency -w 8 -t 5"
    """

    stub:
    """
    echo "stub" > vaf_depth_plot.pdf
    echo "stub" > tile_plot.pdf
    echo "stub" > top_recurrently_mutated_genes.tsv
    echo "TP53" > top_genes.list
    """
}