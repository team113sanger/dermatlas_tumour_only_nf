#!/bin/bash
#BSUB -q normal
#BSUB -G team113-grp
#BSUB -R "select[mem>8000] rusage[mem=8000] span[hosts=1]"
#BSUB -M 8000


# Load module dependencies
module load nextflow-23.10.0
module load /software/modules/ISG/singularity/3.11.4

REVISION="0.2.0"
CONFIG="${PROJECT_DIR}/commands/tumour_only.config"

# Create a nextflow job that will spawn other jobs
nextflow run "https://gitlab.internal.sanger.ac.uk/DERMATLAS/analysis-methods/dermatlas_tumour_only_calling_nf" \
-r ${REVISION} \
-c ${CONFIG} \
-profile farm22 