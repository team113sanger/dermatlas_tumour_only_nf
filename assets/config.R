# Input a MAF file with DERMATLAS-filtered variant calls from unmatched tumours
 
maf_file <- paste0("combined_cohorts_keep_unmatched.maf")
 
# Output file name
 
out_file <- paste0("combined_cohorts_keep_unmatched.annotated.maf")
maf_dir <- paste0("intermediate_files")
 
# Shared external data sources
 
cgc_file <-     paste0("cgc_genes.list")
oncokb_file <-  paste0("cancerGeneList.list")
hotspot_file <- paste0("cancerhotspots_metadata.GRCh38.tsv")
 
# Cohort-specific data (must be generated per cohort/study)
 
unfiltered_matched_maf <- paste0("one_tumour_per_patient_matched_unfilt.canonical.coding.maf")
unfiltered_unmatched_maf <- paste0("one_tumour_per_patient_unmatched_unfilt.canonical.coding.maf")
germline_file <- paste0("germline_varcounts.tsv")
snp_file <- paste0("combined_cohorts_keep_unmatched.dbsnp.tsv")
mnv_file <- paste0("mnv_check.tsv")