process COUNT_NON_REF_GTS {
  publishDir "${params.outdir}/germline_unfiltered", mode: 'copy', pattern: "*.tsv"
  container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
  input:
  tuple path(file_list), path(vcf_files)
  
  output:
  path("*germline_varcounts.tsv"), emit: varcounts

  script:
  """
  /opt/repo/count_nonref_gts.pl $file_list > germline_varcounts.tsv 2>germline_varcounts.log
  """

  stub:
  """
  echo -e "stub" > germline_varcounts.tsv
  """
}

