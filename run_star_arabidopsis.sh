#!/bin/bash
#SBATCH --job-name=STAR
#SBATCH --output=/scratch/idiezs/logs/%x_%A_%a.out
#SBATCH --error=/scratch/idiezs/logs/%x_%A_%a.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

set -euo pipefail
set -x

# ==========================================================
# STAR alignment (single-end, RNAseq) — SLURM ARRAY
#
# Each array task processes ONE FASTQ file
#
# Usage:
#   sbatch --array=0-(N-1) run_star.sh \
#     <star_index_prefix> \
#     <project_path> \
#     <fastq_dir>
# ==========================================================


# -----------------------
# Load configuration
# -----------------------
CONFIG_FILE="/shares/grossniklaus.botinst.uzh/idiezs/code/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# -----------------------
# Argument check
# -----------------------
if [ "$#" -ne 3 ]; then
    echo "Usage: sbatch $0 <STAR_index_dir> <project_path> <fastq_dir>"
    exit 1
fi

STAR_INDEX="$1"
PROJ_PATH="$2"
FASTQ_DIR="$3"

REF_NAME=$(basename "${STAR_INDEX}")

# -----------------------
# Load apptainer
# -----------------------
module load apptainer
echo "Using container: $CONTAINER"

# -----------------------
# Output directories
# -----------------------
ALIGN_BASE="${PROJ_PATH}/02_alignment/${REF_NAME}"

mkdir -p "${ALIGN_BASE}/bam"
mkdir -p "${ALIGN_BASE}/star_logs"

# -----------------------
# FASTQ collection (single-end)
# -----------------------
mapfile -t FILES < <(find "$FASTQ_DIR" -name "*.trimmed.fastq" | sort)

NUM_SAMPLES=${#FILES[@]}

if [ "$NUM_SAMPLES" -eq 0 ]; then
    echo "ERROR: No FASTQ files found"
    exit 1
fi

# -----------------------
# Auto-submit array
# -----------------------
if [ -z "${SLURM_ARRAY_TASK_ID+x}" ]; then
    echo "Submitting STAR array with $NUM_SAMPLES samples"
    sbatch --array=0-$(($NUM_SAMPLES - 1))%50 "$0" "$STAR_INDEX" "$PROJ_PATH" "$FASTQ_DIR"
    exit 0
fi

# -----------------------
# Select sample
# -----------------------
INPUT_FASTQ="${FILES[$SLURM_ARRAY_TASK_ID]}"
EXP_NAME=$(basename "$INPUT_FASTQ" .trimmed.fastq)

echo "========================================"
echo "Sample: $EXP_NAME"
echo "Threads: $SLURM_CPUS_PER_TASK"
echo "========================================"

# -----------------------
# Run STAR
# -----------------------
apptainer exec \
    "$CONTAINER" STAR \
    --genomeDir "$STAR_INDEX" \
    --readFilesIn "$INPUT_FASTQ" \
    --runThreadN "$SLURM_CPUS_PER_TASK" \
    --outFileNamePrefix "${ALIGN_BASE}/star_logs/${EXP_NAME}." \
    --outSAMtype BAM SortedByCoordinate \
    --outFilterMultimapNmax 5 \
    --outFilterMismatchNoverLmax 0.04 \
    --alignIntronMax 10000 \
    --quantMode GeneCounts

# -----------------------
# Move BAM to clean location
# -----------------------
mv "${ALIGN_BASE}/star_logs/*.bam" \
   "${ALIGN_BASE}/bam"

echo "========================================"
echo "Finished sample: $EXP_NAME"
echo "========================================"
