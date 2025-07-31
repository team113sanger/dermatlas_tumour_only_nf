
process COUNT_NON_REF_GTS {
  container "gitlab-registry.internal.sanger.ac.uk/dermatlas/analysis-methods/var_filter"
  input:
  tuple path(file_list), path(vcf_files)
  
  output:
  tuple path("*germline_varcounts.tsv"), emit: varcounts

  script:
  """
  /opt/repo/count_nonref_gts.pl $file_list > germline_varcounts.tsv 2>germline_varcounts.log
  """
}

