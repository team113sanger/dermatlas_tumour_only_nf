process GENERATE_CONFIG_FILE {
    input:
    path(varcounts)
    path(dbsnp_positions)
    path(mnv_check)
    path(matched_maf)
    path(unmatched_maf)

    output:
    tuple val(meta), path("config.yaml"), emit: config

    script:
    """
    cat > dynamic_config.R << 'EOF'
    # Input a MAF file with DERMATLAS-filtered variant calls from unmatched tumours
    maf_file <- "${params.maf_file}"
    # Output file name  
    out_file <- "${params.out_file}"
    maf_dir <- "${params.maf_dir}"
    # Shared external data sources
    cgc_file <- "${params.cgc_file}"
    oncokb_file <- "${params.oncokb_file}"
    hotspot_file <- "${params.hotspot_file}"
    # Cohort-specific data (must be generated per cohort/study)
    unfiltered_matched_maf <- "${params.unfiltered_matched_maf}"
    unfiltered_unmatched_maf <- "${params.unfiltered_unmatched_maf}"
    germline_file <- "${varcounts}"
    snp_file <- "${params.snp_file}"
    mnv_file <- "${mnv_check}"
    EOF
    """
}

process CATEGORISE_AND_PLOT_VARIANTS {
    container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
    publishDir "${params.outdir}/plots", mode: 'copy', pattern: "*.png"

    input:
    tuple val(meta), path(filtered_maf), each(tier)

    output:
    path("*.png"), emit: plots

    script:
    """
    h="${meta.cohort}"
    colnum=`head -n1 $filtered_maf | awk -v RS='\t' '/Flagging_Tier/{print NR; exit}'`
    cat $filtered_maf | awk -v col=$colnum -v tier=$tier 'BEGIN{OFS=IFS="\t"}{if(/Hugo/ || $col >= tier){print}}' > ${h}_unmatched_keep_annotated.tier${tier}.maf

    sample_col=`head -n1 ${maf_file} | sed 's/\t/\n/g' | grep -n Barcode | cut -f 1 -d ":"`
    plot_height=`cat $sample_list | wc -l`
    check=$(echo $plot_height / 5 | bc -l | perl -ne 's/\S+\.(\S+)/$1/;print')

    if [[ "$plot_height" -le 5 ]]; then
    	plot_height=1
    elif [[ "$check" -gt 0 ]]; then
    	let plot_height=1+$(echo $plot_height / 5 | bc)
    else
    	let plot_height=$plot_height/5
    fi
    plot_height=$(echo $plot_height*1.5 | bc -l)

    Rscript /opt/repo/plot_vaf_vs_depth_from_maf.R --file  ${h}_unmatched_keep_annotated.tier${tier}.maf --samplefile $sample_list --width 10 --height $plot_height -ncol
    cut -f 3 top_recurrently_mutated_genes.tsv |sort -u | grep -v Hugo_ > top_genes.list
    Rscript /opt/repo/maketileplot_from_maf.R -a  ${h}_unmatched_keep_annotated.tier${tier}.maf -s $sample_list  -g top_genes.list --sortbyfrequency -w 8 -t 5 
    echo "Rscript /opt/repo/maketileplot_from_maf.R -a  ${h}_unmatched_keep_annotated.tier${tier}.maf -s $sample_list -g top_genes.list --sortbyfrequency -w 8 -t 5"
    """
}