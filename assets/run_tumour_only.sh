!/bin/bash
#BSUB -q normal
#BSUB -G team113-grp
#BSUB -R "select[mem>8000] rusage[mem=8000] span[hosts=1]"
#BSUB -M 8000

# Load module dependencies
module load nextflow-23.10.0
module load /software/modules/ISG/singularity/3.11.4


# Create a nextflow job that will spawn other jobs

nextflow run "TBC"
-r $REVISION \
-c ${CONFIG} \
-profile farm22 