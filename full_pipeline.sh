#!/bin/bash
# =============================================================================
# run_full_pipeline.sh — Complete bacterial genome assembly pipeline
# Part of: bacterial-genome-assembly-pipeline
#
# Runs all steps in sequence:
#   FastQC → Trimmomatic → SPAdes → QUAST + CheckM → Prokka → ABRicate → PGPg
#
# Usage:
#   bash scripts/run_full_pipeline.sh \
#     --forward  data/raw/sample_1.fq \
#     --reverse  data/raw/sample_2.fq \
#     --sample   my_sample \
#     --outdir   results \
#     [--adapters /path/to/NexteraPE-PE.fa] \
#     [--threads 8]
#
# Output structure:
#   results/
#   ├── fastqc/
#   ├── trimmed/
#   ├── assembly/
#   ├── quality/
#   └── annotation/
# =============================================================================

set -euo pipefail

# ── DEFAULTS ──────────────────────────────────────────────────────────────────
FORWARD=""
REVERSE=""
SAMPLE=""
OUTDIR="results"
ADAPTERS=""
THREADS=8
SKIP_PGPG=false

# ── PARSE ARGUMENTS ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --forward)   FORWARD="$2";   shift 2 ;;
    --reverse)   REVERSE="$2";   shift 2 ;;
    --sample)    SAMPLE="$2";    shift 2 ;;
    --outdir)    OUTDIR="$2";    shift 2 ;;
    --adapters)  ADAPTERS="$2";  shift 2 ;;
    --threads)   THREADS="$2";   shift 2 ;;
    --skip-pgpg) SKIP_PGPG=true; shift ;;
    --help|-h)
      sed -n '3,22p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

# ── VALIDATE ──────────────────────────────────────────────────────────────────
for var in FORWARD REVERSE SAMPLE; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: --${var,,} is required."
    echo "Run with --help for usage."
    exit 1
  fi
done

if [[ ! -f "$FORWARD" ]]; then echo "ERROR: Forward reads not found: $FORWARD"; exit 1; fi
if [[ ! -f "$REVERSE" ]]; then echo "ERROR: Reverse reads not found: $REVERSE"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── DIRECTORY SETUP ───────────────────────────────────────────────────────────
mkdir -p \
  "$OUTDIR/fastqc" \
  "$OUTDIR/trimmed" \
  "$OUTDIR/assembly/$SAMPLE" \
  "$OUTDIR/quality/$SAMPLE" \
  "$OUTDIR/annotation/$SAMPLE"

LOG="$OUTDIR/pipeline_${SAMPLE}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

# ── START ─────────────────────────────────────────────────────────────────────
START_TIME=$(date +%s)

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Bacterial Genome Assembly Pipeline     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Sample  : $SAMPLE"
echo "  Forward : $FORWARD"
echo "  Reverse : $REVERSE"
echo "  Output  : $OUTDIR"
echo "  Threads : $THREADS"
echo "  Log     : $LOG"
echo ""
echo "  Steps: FastQC → Trimmomatic → SPAdes → QUAST/CheckM → Prokka → ABRicate → PGPg"
echo ""

# ── STEP 1: FASTQC ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [1/6] FastQC — Raw read quality control"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/run_fastqc.sh" \
  "$(dirname "$FORWARD")" \
  "$OUTDIR/fastqc"

# ── STEP 2: TRIMMOMATIC ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [2/6] Trimmomatic — Quality filtering"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/run_trimmomatic.sh" \
  "$FORWARD" \
  "$REVERSE" \
  "$OUTDIR/trimmed" \
  "$ADAPTERS"

FWD_PAIRED="$OUTDIR/trimmed/${SAMPLE}_1_paired.fq"
REV_PAIRED="$OUTDIR/trimmed/${SAMPLE}_2_paired.fq"

# ── STEP 3: SPADES ────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [3/6] SPAdes — De novo assembly"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/run_spades.sh" \
  "$FWD_PAIRED" \
  "$REV_PAIRED" \
  "$OUTDIR/assembly/$SAMPLE" \
  "$THREADS"

CONTIGS="$OUTDIR/assembly/$SAMPLE/contigs.fasta"

# ── STEP 4: QUALITY ───────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [4/6] QUAST + CheckM — Quality assessment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/run_quality.sh" \
  "$CONTIGS" \
  "$OUTDIR/quality/$SAMPLE" \
  "$THREADS"

# ── STEP 5 & 6: ANNOTATION ───────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [5+6/6] Prokka + ABRicate + PGPg Finder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPT_DIR/run_annotation.sh" \
  "$CONTIGS" \
  "$OUTDIR/annotation/$SAMPLE" \
  "$SAMPLE"

# ── DONE ──────────────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS=$(( ELAPSED % 60 ))

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Pipeline complete ✓                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Sample    : $SAMPLE"
echo "  Duration  : ${MINUTES}m ${SECONDS}s"
echo "  Full log  : $LOG"
echo ""
echo "  Results:"
echo "  ├── $OUTDIR/fastqc/           ← QC reports (.html)"
echo "  ├── $OUTDIR/trimmed/          ← clean reads (.fq)"
echo "  ├── $OUTDIR/assembly/$SAMPLE/ ← contigs.fasta, scaffolds.fasta"
echo "  ├── $OUTDIR/quality/$SAMPLE/  ← QUAST report, CheckM summary"
echo "  └── $OUTDIR/annotation/$SAMPLE/"
echo "      ├── prokka/               ← .gff, .gbk, .faa"
echo "      ├── abricate/             ← virulence genes (.tsv)"
echo "      └── pgpg_finder/          ← PGP traits, heatmaps"
echo ""
echo "  Taxonomic classification (TYGS/MiGA) must be run online:"
echo "     TYGS : https://tygs.dsmz.de/"
echo "     MiGA : https://uibk.microbial-genomes.org/"
echo ""
echo "  Reference-guided scaffolding (RagTag) requires a reference genome."
echo "     Run manually after taxonomic classification:"
echo "     bash scripts/run_ragtag.sh <reference.fasta> $CONTIGS $OUTDIR/scaffolded/$SAMPLE"
echo ""
