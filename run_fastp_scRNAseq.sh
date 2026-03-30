#!/bin/bash
#SBATCH --job-name=fastp
#SBATCH --output=/scratch/idiezs/logs/%x_%A_%a.out
#SBATCH --error=/scratch/idiezs/logs/%x_%A_%a.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00

set -euo pipefail
set -x

# ==========================================================
# fastp trimming (single-end) — SLURM ARRAY
#
# Each array task processes ONE FASTQ file
#
# Usage:
#   sbatch run_fastp.sh <input_fastq_dir> <output_dir>
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
if [ "$#" -ne 2 ]; then
    echo "Usage: sbatch $0 <input_fastq_dir> <output_dir>"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"

# -----------------------
# Load apptainer
# -----------------------
module load apptainer
echo "Using container: $CONTAINER"

# -----------------------
# Output directories
# -----------------------
FASTP_OUT="${OUTPUT_DIR}/01_qc_and_trimming/fastp_trimmed"
FASTP_REPORT="${OUTPUT_DIR}/01_qc_and_trimming/fastp_reports"

mkdir -p "$FASTP_OUT"
mkdir -p "$FASTP_REPORT"

# -----------------------
# Collect FASTQ files
# -----------------------
mapfile -t FILES < <(find "$INPUT_DIR" -type f -name "*.fastq" | sort)

NUM_FILES=${#FILES[@]}

if [ "$NUM_FILES" -eq 0 ]; then
    echo "ERROR: No FASTQ files found in $INPUT_DIR"
    exit 1
fi

# -----------------------
# Auto-submit array
# -----------------------
if [ -z "${SLURM_ARRAY_TASK_ID+x}" ]; then
    echo "Submitting fastp array with $NUM_FILES files..."
    sbatch --array=0-$(($NUM_FILES - 1))%50 "$0" "$INPUT_DIR" "$OUTPUT_DIR"
    exit 0
fi

# -----------------------
# Bounds check
# -----------------------
if [ "$SLURM_ARRAY_TASK_ID" -ge "$NUM_FILES" ]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID out of range"
    exit 1
fi

# -----------------------
# Select file
# -----------------------
INPUT_FASTQ="${FILES[$SLURM_ARRAY_TASK_ID]}"
BASE=$(basename "$INPUT_FASTQ" .fastq)

echo "========================================"
echo "Processing: $INPUT_FASTQ"
echo "========================================"

# -----------------------
# Run fastp
# -----------------------
apptainer exec \
    --bind /shares:/shares \
    --bind /scratch:/scratch \
    "$CONTAINER" fastp \
        -i "$INPUT_FASTQ" \
        -o "${FASTP_OUT}/${BASE}.trimmed.fastq" \
        --html "${FASTP_REPORT}/${BASE}.html" \
        --json "${FASTP_REPORT}/${BASE}.json" \
        --thread "$SLURM_CPUS_PER_TASK" \
        --trim_poly_x \
        --poly_x_min_len 10 \
        --cut_tail \
        --cut_tail_mean_quality 20 \
        --length_required 20

echo "========================================"
echo "Finished: $BASE"
echo "========================================"
