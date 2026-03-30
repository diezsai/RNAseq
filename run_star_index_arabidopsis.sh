#!/bin/bash
#SBATCH --job-name=star_index
#SBATCH --output=/scratch/idiezs/logs/%x_%j.out
#SBATCH --error=/scratch/idiezs/logs/%x_%j.err
#SBATCH --cpus-per-task=15
#SBATCH --mem=80G
#SBATCH --time=12:00:00

set -euo pipefail

CONFIG_FILE="/shares/grossniklaus.botinst.uzh/idiezs/code/config.sh"
source "$CONFIG_FILE"

THREADS=$SLURM_CPUS_PER_TASK

module load apptainer

apptainer exec "$CONTAINER" STAR \
    --runThreadN $THREADS \
    --runMode genomeGenerate \
    --genomeDir /shares/grossniklaus.botinst.uzh/idiezs/references/star_index/TAIR10 \
    --genomeFastaFiles /shares/grossniklaus.botinst.uzh/idiezs/references/GCF_000001735.4_TAIR10.1_genomic.fna \
    --sjdbGTFfile /shares/grossniklaus.botinst.uzh/idiezs/references/GCF_000001735.4_TAIR10.1_genomic.gtf \
    --sjdbOverhang 99
