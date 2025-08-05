process CATEGORISE_VARIANTS {

    input: 
    tuple val(meta), path(filtered_maf)
    each(g)

    output:
    path("${meta.sample_id}_unmatched_keep_annotated.tier${g}.maf"), emit: tier_maf

    script:
    """

    # Find column number for Flagging_Tier
    colnum=\$(head -n1 ${filtered_maf} | awk -v RS='\t' '/Flagging_Tier/{print NR; exit}')

    # Filter MAF file based on tier
    cat ${filtered_maf} | awk -v col=\$colnum -v tier=${g} 'BEGIN{OFS=IFS="\t"}{if(/Hugo/ || \$col >= tier){print}}' > "${meta.sample_id}_unmatched_keep_annotated.tier${g}.maf"
    """
}

process PLOT_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/plots", mode: 'copy', pattern: "*.png"

    input:
    tuple val(meta), path(tier_maf)
    path(sample_list)

    output:
    path("*.png"), emit: plots

    script:
    """
    # Find sample column number
    sample_col=\$(head -n1 ${tier_maf} | sed 's/\t/\n/g' | grep -n Barcode | cut -f 1 -d ":")
    
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
    Rscript ${SCRIPTDIR}/plot_vaf_vs_depth_from_maf.R \\
        --file ${maf_file} \\
        --samplefile ${sample_list} \\
        --width 10 \\
        --height \$plot_height \\
        -ncol 5
    
    # Extract top genes and create tile plot
    cut -f 3 top_recurrently_mutated_genes.tsv | sort -u | grep -v Hugo_ > top_genes.list
    
    Rscript ${SCRIPTDIR}/maketileplot_from_maf.R \\
        -a ${maf_file} \\
        -s ${sample_list} \\
        -g top_genes.list \\
        --sortbyfrequency \\
        -w 8 \\
        -t 5
    
    echo "Rscript ${SCRIPTDIR}/maketileplot_from_maf.R -a ${maf_file} -s ${sample_list} -g top_genes.list --sortbyfrequency -w 8 -t 5"
    """
}