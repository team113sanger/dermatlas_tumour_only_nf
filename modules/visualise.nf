process CATEGORISE_VARIANTS {
    publishDir "${params.outdir}/release_${params.release_verion}/qc_tier${tier}", mode: 'copy', pattern: "*"

    input: 
    tuple val(meta), path(filtered_maf)
    each(tier)

    output:
    tuple val(meta), val(tier), path("${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf"), emit: tier_maf

    script:
    """

    # Find column number for Flagging_Tier
    colnum=\$(head -n1 ${filtered_maf} | awk -v RS='\t' '/Flagging_Tier/{print NR; exit}')

    # Filter MAF file based on tier
    cat ${filtered_maf} | awk -v col=\$colnum -v tier=${tier} 'BEGIN{OFS=IFS="\t"}{if(/Hugo/ || \$col >= tier){print}}' > "${meta.sample_id}_unmatched_keep_annotated.tier${tier}.maf"
    """
}

process PLOT_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/maf"
    publishDir "${params.outdir}/release_${params.release_verion}/qc_tier${tier}", mode: 'copy', pattern: "*"

    input:
    tuple val(meta), val(tier), path(tier_maf), path(sample_list)

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
}