# Bacterial Genome Assembly Pipeline — Illumina Short Reads

**A step-by-step protocol for assembling, evaluating, annotating, and functionally characterizing bacterial genomes from Illumina paired-end sequencing data.**

Developed at [LABEM — Laboratory of Biotechnology and Microbial Ecology](http://www.labem.microbiologia.ufrj.br/), Instituto de Microbiologia Paulo de Góes, Universidade Federal do Rio de Janeiro (UFRJ), in collaboration with the Universidad Nacional de Colombia.

> **Authors:** Mariana Trujillo¹, Douglas A. Monteiro², Caio Rachid²  
> ¹Universidad Nacional de Colombia, Medellín · ²LABEM/UFRJ, Rio de Janeiro  

---

## Overview

This protocol covers the complete workflow for bacterial genome assembly from raw Illumina reads, including:

1. Quality control of raw sequencing data
2. Adapter trimming and low-quality read removal
3. *De novo* genome assembly
4. Assembly quality assessment (completeness, contamination, fragmentation)
5. Taxonomic classification
6. Reference-guided scaffolding
7. Genome annotation
8. Virulence gene screening
9. Plant growth-promoting gene identification

The pipeline was developed and validated during microbial genomics research projects at LABEM/UFRJ involving environmental bacterial isolates from recycled aggregates, *Eucalyptus*-associated bacteria, and endophytic bacteria from *Atriplex nummularia*.

---

## Table of Contents

- [Requirements](#requirements)
- [Server Connection Setup](#server-connection-setup)
- [Linux Basics](#linux-basics)
- [Tool Installation](#tool-installation)
- [Pipeline](#pipeline)
  - [Step 1 — Quality Control with FastQC](#step-1--quality-control-with-fastqc)
  - [Step 2 — Trimming with Trimmomatic](#step-2--trimming-with-trimmomatic)
  - [Step 3 — Genome Assembly with SPAdes](#step-3--genome-assembly-with-spades)
  - [Step 4 — Assembly Quality Assessment](#step-4--assembly-quality-assessment)
  - [Step 5 — Taxonomic Classification](#step-5--taxonomic-classification)
  - [Step 6 — Reference-Guided Scaffolding with RagTag](#step-6--reference-guided-scaffolding-with-ragtag)
  - [Step 7 — Genome Annotation with Prokka](#step-7--genome-annotation-with-prokka)
  - [Step 8 — Virulence Gene Screening with ABRicate](#step-8--virulence-gene-screening-with-abricate)
  - [Step 9 — Plant Growth-Promoting Genes with PGPg Finder](#step-9--plant-growth-promoting-genes-with-pgpg-finder)
- [Expected Outputs](#expected-outputs)
- [References](#references)

---

## Requirements

### Software (installed on Linux server)

| Tool | Version | Purpose |
|------|---------|---------|
| FastQC | 0.12.1 | Raw read quality control |
| Trimmomatic | 0.39 | Adapter trimming and quality filtering |
| SPAdes | 4.2.0 | *De novo* genome assembly |
| QUAST | 5.3.0 | Assembly quality metrics |
| CheckM | latest | Genome completeness and contamination |
| RagTag | latest | Reference-guided scaffolding |
| Prokka | 1.14.6 | Rapid genome annotation |
| ABRicate | latest | Virulence and resistance gene screening |
| PGPg Finder | latest | Plant growth-promoting gene annotation |
| Conda / Mamba | latest | Environment management |

### Client-side tools (Windows)

- **PuTTY** — SSH client for server access → [Download](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
- **WinSCP** — File transfer between local machine and server → [Download](https://winscp.net/eng/download.php)

> **Linux/macOS users:** Use your native terminal for SSH (`ssh user@IP -p PORT`) and `scp` or `rsync` for file transfer. WinSCP and PuTTY are not required.

---

## Server Connection Setup

### PuTTY (SSH client)

PuTTY allows interactive command-line sessions on a remote Linux server via SSH (Tatham, 2024).

After installation, configure the connection using the appropriate IP and port.

Save both in PuTTY to avoid re-entering credentials. Upon connection, you will see a prompt like `[your_user@localhost ~]$`.

### WinSCP (file transfer)

WinSCP transfers files between your local Windows machine and the server using the same SSH/SFTP protocol (Boze, 2002). Use the same IP, port, username, and password as configured in PuTTY.

**Recommended interface:** Norton Commander (dual-panel). Left panel = local files; right panel = server files. Drag and drop between panels to transfer files.

---

## Linux Basics

A quick reference for navigating the server during the pipeline.

```bash
# Navigation
cd folder_name          # enter a folder
cd ..                   # go back one level
cd ~                    # go to home directory
pwd                     # print current directory path
ls                      # list files
ls -l                   # list with details
mkdir folder_name       # create a new folder

# File operations
cp /path/source /path/dest    # copy a file
mv /path/source /path/dest    # move or rename a file
rm filename                   # delete a file
rm -r folder_name             # delete a folder and its contents

# Viewing files
less filename           # view file (scroll with arrows, q to quit)
head filename           # show first 5 lines

# Compression / decompression
unzip file.zip
tar -xvzf file.tar.gz

# Text editors
nano filename.txt       # open or create a text file
# Ctrl + O = save | Ctrl + X = exit

# Make a script executable
chmod +x script.sh
./script.sh             # run it

# Terminal keyboard shortcuts
Ctrl + C                # interrupt current command
Ctrl + L                # clear the screen
history                 # show previous commands
# Select text to copy | Shift + Insert to paste (in PuTTY)
```

### Tmux — persistent sessions

Tmux keeps your processes running even if the connection drops or the computer shuts down.

```bash
tmux new-session -s my_session    # start a named session
tmux attach-session -t my_session # reconnect to a session
tmux ls                           # list open sessions
# Ctrl + B + D = detach (leave session running in background)
exit                              # end the session
```

---

## Tool Installation

There are three main ways to install tools on a Linux server: binary code, source code, or Conda environments. This pipeline uses all three depending on the tool.

### FastQC

```bash
wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip
unzip fastqc_v0.12.1.zip
cd FastQC/
pwd                      # copy this path — you'll need it later
./fastqc --help          # confirm installation
```

### Trimmomatic

```bash
wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip
unzip Trimmomatic-0.39.zip
cd Trimmomatic-0.39/
pwd                      # copy path to trimmomatic-0.39.jar
java -jar trimmomatic-0.39.jar --version
```

### SPAdes

```bash
wget https://github.com/ablab/spades/releases/download/v4.2.0/SPAdes-4.2.0-Linux.tar.gz
tar -xzf SPAdes-4.2.0-Linux.tar.gz
cd SPAdes-4.2.0-Linux/bin/
pwd                      # copy path to spades.py
./spades.py --version
```

### QUAST

```bash
wget https://github.com/ablab/quast/releases/download/quast_5.3.0/quast-5.3.0.tar.gz
tar -xzf quast-5.3.0.tar.gz
cd quast-5.3.0/
pwd                      # copy path to quast.py
./quast.py --help
```

### CheckM (Conda)

```bash
conda create -n checkm python=3.9
conda activate checkm
conda install -c bioconda numpy matplotlib pysam
conda install -c bioconda hmmer prodigal pplacer
pip3 install checkm-genome

# Download reference data
wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
tar -xvzf checkm_data_2015_01_16.tar.gz

# Set the data path (choose one option)
export CHECKM_DATA_PATH='/path/to/extracted/data/'
# OR
checkm data setRoot /path/to/extracted/data/

# Verify installation
checkm test ~/checkm_test_results
```

### RagTag (Conda + Mamba)

```bash
conda create -n ragtag_env python=3.10
conda activate ragtag_env
conda install -c conda-forge mamba -y
mamba install -c conda-forge -c bioconda ragtag
ragtag.py --help
```

### Prokka (Conda + Mamba)

```bash
conda create -n prokka_env python=3.8
conda activate prokka_env
conda install -c conda-forge mamba
mamba install -c bioconda -c conda-forge prokka=1.14.6
```

### ABRicate (Conda + Mamba)

```bash
conda create -n abricate_env python=3.10
conda activate abricate_env
conda install -c conda-forge mamba -y
mamba install -c conda-forge -c bioconda -c defaults abricate -y
abricate --version
```

### PGPg Finder (Conda + source)

```bash
# Create environment and install dependencies
conda create -n PGPg_finder python=3.8
conda activate PGPg_finder
conda install -c conda-forge mamba -y
mamba install -c conda-forge -c bioconda -c defaults PGPg_finder -y
mamba install -c bioconda blast biopython pandas seaborn matplotlib -y
conda install -c bioconda prodigal diamond megahit bowtie2 samtools gawk pear trimmomatic -y

# Clone source code
git clone https://github.com/tpellegrinetti/PGPg_finder.git
cd PGPg_finder
chmod +x PGPg_finder.py

# Download and prepare the reference database
wget https://plabase.cs.unituebingen.de/pb/tools/PGPTblhm/data/factors/PGPT_BASE_nr_Aug2021n_ul_1.fasta.gz
gzip -d *.gz
diamond makedb --in PGPT_BASE_nr_Aug2021n_ul_1.fasta --db genome
```

---

## Pipeline

### Input data

This pipeline expects **paired-end Illumina reads** in FASTQ format:
- `sample_1.fq` — forward reads (5'→3')
- `sample_2.fq` — reverse reads (3'→5')

Paired-end sequencing is strongly recommended: it provides significantly higher assembly quality at a modest additional cost compared to single-end sequencing.

---

### Step 1 — Quality Control with FastQC

FastQC evaluates the quality of raw sequencing data and generates a comprehensive HTML report (Andrews, 2010). This includes per-base quality scores, GC content, adapter content, N content, and sequence duplication levels.

```bash
/path/to/fastqc /path/to/input/sample.fq -o /path/to/output/folder/
```

Transfer the resulting `.html` report to your local machine using WinSCP and open it in a browser.

**Key metrics to check before proceeding:**
- **Adapter Content:** Note which adapter types are present (e.g., Nextera Transposase) — required for the next step.
- **Per Base N Content:** Note if undetermined bases ("N") are present at any position.
- **Per Base Sequence Quality:** Scores below 20 at the ends are common and will be addressed in trimming.

Official interpretation guide: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/

---

### Step 2 — Trimming with Trimmomatic

Trimmomatic removes adapter sequences and low-quality bases from paired-end reads (Bolger et al., 2014). The command below is appropriate for high-coverage paired-end data with no detected adapter contamination and no N content:

```bash
java -jar /path/to/trimmomatic-0.39.jar PE -phred33 \
  /path/to/input/sample_1.fq \
  /path/to/input/sample_2.fq \
  /path/to/output/forward_paired.fq \
  /path/to/output/forward_unpaired.fq \
  /path/to/output/reverse_paired.fq \
  /path/to/output/reverse_unpaired.fq \
  SLIDINGWINDOW:4:20 MINLEN:75
```

**If adapters were detected** (e.g., Nextera Transposase Sequence), add:
```
ILLUMINACLIP:/path/to/trimmomatic/adapters/NexteraPE-PE.fa:2:30:10
```

**If undetermined bases (N) were detected**, add:
```
LEADING:3 TRAILING:3
```

After trimming, use the `forward_paired.fq` and `reverse_paired.fq` files in the next steps. Unpaired files are generally excluded when coverage is high, which produces a cleaner assembly.

Full parameter documentation: http://www.usadellab.org/cms/?page=trimmomatic

---

### Step 3 — Genome Assembly with SPAdes

SPAdes performs *de novo* assembly — reconstructing the genome without a reference — and is optimized for bacterial isolates, metagenomic data, and Illumina reads (Prjibelski et al., 2020).

```bash
/path/to/spades.py \
  -1 /path/to/forward_paired.fq \
  -2 /path/to/reverse_paired.fq \
  -o /path/to/output/folder/
```

**Key output files:**
- `contigs.fasta` — assembled contigs, sorted by length (longest first)
- `scaffolds.fasta` — contigs joined with gap-filling (runs of "N") based on paired-read information

> **Which file to use?** For downstream analyses, `contigs.fasta` is preferred when minimizing undefined regions ("N") is a priority. If your organism has large repetitive regions, `scaffolds.fasta` may provide more complete sequence.

Full parameter reference: https://ablab.github.io/spades/running.html

---

### Step 4 — Assembly Quality Assessment

#### 4a. QUAST — fragmentation metrics

QUAST calculates standard assembly statistics including number of contigs, N50, largest contig, total assembly length, GC content, and N count per 100 kbp (Mikheenko et al., 2018).

```bash
/path/to/quast.py /path/to/contigs.fasta -o /path/to/output/folder/
```

Transfer `report.html` to your local machine for interactive visualization.

> **Tip:** Run QUAST on both `contigs.fasta` and `scaffolds.fasta` and compare results before deciding which to use downstream.

**Interpreting the GC content plot:**  
A single peak indicates a pure bacterial culture. Two or more peaks suggest contamination with a second organism. If this occurs, investigate the source before proceeding.

Full manual: https://quast.sourceforge.net/docs/manual.html

#### 4b. CheckM — completeness and contamination

CheckM uses lineage-specific sets of ubiquitous single-copy marker genes to estimate genome completeness and contamination (Parks et al., 2015).

```bash
conda activate checkm
checkm lineage_wf -t 8 -x fasta /path/to/assembly/folder/ /path/to/output/folder/
```

**Quality thresholds (Parks et al., 2015):**
- ✅ **High quality:** Completeness ≥ 95%, Contamination ≤ 5%
- ⚠️ **Acceptable:** Completeness ≥ 70%, Contamination ≤ 10%
- ❌ **Problematic:** Below these thresholds — investigate before publishing

Full documentation: https://github.com/Ecogenomics/CheckM/wiki/Overview

---

### Step 5 — Taxonomic Classification

#### Option A — TYGS (online, most thorough)

TYGS (Type Strain Genome Server) infers whole-genome phylogenies and species/subspecies boundaries using DDH (Digital DNA-DNA Hybridization), GC content, 16S rRNA, and MLSA (Meier-Kolthoff & Göker, 2019).

1. Go to: https://tygs.dsmz.de/
2. Click **"Submit your query"**
3. Upload your assembled FASTA file
4. Optionally add up to 10 reference type strains for comparison (or let the server select them automatically)
5. Enter your email and submit

**Results include:** 16S rRNA and WGS phylogenetic trees, species assignment, DDH values against database genomes, pairwise comparison tables.

> ⚠️ **Download your results.** TYGS deletes results after a storage period. If the genome does not match any database entry (very low DDH values), it may represent a novel species.

> ⚠️ **Note on processing time:** TYGS can take days to weeks depending on queue. For faster results, use MiGA.

#### Option B — MiGA (online, faster)

MiGA (Microbial Genomes Atlas) classifies genomes against all available typed taxa using Average Nucleotide Identity (ANI) and Amino Acid Identity (AAI) (Rodriguez-R & Konstantinidis, 2020).

1. Go to: https://uibk.microbial-genomes.org/
2. Select **"TypeMat"** → **"Upload genome"**
3. Upload your FASTA file and submit (default settings are appropriate for most cases)

**Results include:** ribosomal RNA and tRNA gene counts, taxonomic classification with p-values per clade, ANI/AAI to closest species, quality report based on essential genes, and assembly statistics.

---

### Step 6 — Reference-Guided Scaffolding with RagTag

RagTag orders and orients contigs from the assembly relative to a closely related reference genome, inserting gap sequences ("N"s) between adjacent contigs to indicate unknown regions (Alonge et al., 2022). This step does not alter sequences — it only reorganizes them.

**First, obtain a reference genome:**
1. Go to https://www.ncbi.nlm.nih.gov/datasets/genome/
2. Search for the closest species identified in Step 5
3. Filter for **"Reference genome"** status
4. Download the **"Genome sequences (FASTA)"**
5. Transfer the file to the server using WinSCP

**Then run RagTag:**

```bash
conda activate ragtag_env
ragtag.py scaffold \
  /path/to/reference_genome.fasta \
  /path/to/contigs.fasta \
  -o /path/to/output/folder/
```

Full documentation: https://github.com/malonge/RagTag/wiki/scaffold

---

### Step 7 — Genome Annotation with Prokka

Prokka rapidly annotates bacterial genomes by predicting and classifying genes, proteins, rRNAs, tRNAs, and other genomic features (Seemann, 2014). It integrates Prodigal, RNAmmer, Aragorn, SignalP, and Infernal internally.

```bash
conda activate prokka_env
prokka \
  --outdir /path/to/output/folder/ \
  --prefix sample_name \
  /path/to/scaffolded_genome.fasta
```

**Key output files:**

| File | Description |
|------|-------------|
| `.gff` | Annotation in GFF3 format (compatible with genome browsers) |
| `.gbk` | GenBank format (compatible with NCBI submission) |
| `.faa` | Predicted protein sequences (FASTA) |
| `.ffn` | Predicted gene sequences (FASTA) |
| `.tbl` | Feature table for NCBI submission |
| `.txt` | Summary statistics |

Full documentation: https://github.com/tseemann/prokka

---

### Step 8 — Virulence Gene Screening with ABRicate

ABRicate screens assembled contigs against curated databases of antimicrobial resistance and virulence genes (Seemann, n.d.). For virulence characterization, the VFDB (Virulence Factor Database) is recommended as a first approach (Chen et al., 2016).

```bash
conda activate abricate_env
abricate --db vfdb /path/to/genome.fasta > /path/to/output/results.tsv
```

**Available databases:** `ncbi`, `card`, `resfinder`, `arg-annot`, `megares`, `ecoh`, `plasmidfinder`, `vfdb`, `ecoli_vf`

> Choose the database based on your research objectives. Custom databases can also be created from FASTA sequence files. Full documentation: https://github.com/tseemann/abricate

---

### Step 9 — Plant Growth-Promoting Genes with PGPg Finder

PGPg Finder annotates plant growth-promoting traits (PGPTs) in bacterial genomes and metagenomes using the curated PLaBAse database (Pellegrinetti et al., 2024; Patz et al., 2021).

```bash
conda activate PGPg_finder
/path/to/PGPg_finder.py \
  -w genome_wf \
  -i /path/to/genome.fasta \
  -o /path/to/output/folder/

# View all available options
PGPg_finder -h
```

**Output files include:**
- Annotated gene tables per PGPT category
- Heatmaps showing gene counts per functional category
- Results organized at three hierarchical levels (summary, Lv3, Lv4)
- `non-normalized` (normalized by genome size — recommended for cross-genome comparisons) and `normalized` (absolute counts) variants

PLaBAse database: https://plabase.cs.uni-tuebingen.de/

---

## Expected Outputs

A successful run of the complete pipeline produces the following for each bacterial isolate:

| Stage | Key output | Format |
|-------|-----------|--------|
| QC | Quality report | `.html` |
| Trimming | Clean paired reads | `.fq` |
| Assembly | Contigs / scaffolds | `.fasta` |
| QUAST | Assembly statistics | `.html`, `.tsv` |
| CheckM | Completeness/contamination | `.tsv` |
| TYGS/MiGA | Species classification | online report |
| RagTag | Ordered scaffolds | `.fasta` |
| Prokka | Annotated genome | `.gff`, `.gbk`, `.faa` |
| ABRicate | Virulence gene table | `.tsv` |
| PGPg Finder | PGPT heatmaps and tables | `.png`, `.tsv` |

---

## References

Alonge, M., Wang, X., Benoit, M., Soyk, S., Pereira, L., Zhang, L., ... & Lippman, Z. B. (2022). Automated assembly scaffolding elevates a new tomato system for high-throughput genome editing. *Genome Biology*, 23(1), 151. https://doi.org/10.1186/s13059-022-02823-7

Anaconda Inc. (2016). *Anaconda software distribution* (Version 2–2.4.0). https://docs.conda.io

Andrews, S. (2010). *FastQC: A quality control tool for high throughput sequence data*. https://www.bioinformatics.babraham.ac.uk/projects/fastqc

Bolger, A. M., Lohse, M., & Usadel, B. (2014). Trimmomatic: A flexible trimmer for Illumina Sequence Data. *Bioinformatics*, btu170.

Boze, A. (2002). WinSCP 2.0 Beta. *Information Technology and Libraries*, 21(4), 190.

Chen, L., Zheng, D., Liu, B., Yang, J., & Jin, Q. (2016). VFDB 2016: hierarchical and refined dataset for big data analysis — 10 years on. *Nucleic Acids Research*, 44(D1), D694–D697. https://doi.org/10.1093/nar/gkv1239

Meier-Kolthoff, J. P., & Göker, M. (2019). TYGS is an automated high-throughput platform for state-of-the-art genome-based taxonomy. *Nature Communications*, 10, 2182. https://doi.org/10.1038/s41467-019-10210-3

Mikheenko, A., Prjibelski, A., Saveliev, V., Antipov, D., & Gurevich, A. (2018). Versatile genome assembly evaluation with QUAST-LG. *Bioinformatics*, 34(13), i142–i150.

Parks, D. H., Imelfort, M., Skennerton, C. T., Hugenholtz, P., & Tyson, G. W. (2015). CheckM: Assessing the quality of microbial genomes recovered from isolates, single cells, and metagenomes. *Genome Research*, 25(7), 1043–1055. https://doi.org/10.1101/gr.186072.114

Patz, S., Gautam, A., Becker, M., Ruppel, S., Rodríguez-Palenzuela, P., & Huson, D. H. (2021). PLaBAse: A comprehensive web resource for analyzing the plant growth-promoting potential of plant-associated bacteria [preprint].

Pellegrinetti, T. A., Monteiro, G., Lemos, L. N., Santos, R. A. C., Barros, A., & Mendes, L. (2024). PGPg_finder: A comprehensive and user-friendly pipeline for identifying plant growth-promoting genes in genomic and metagenomic data. *Rhizosphere*.

Prjibelski, A., Antipov, D., Meleshko, D., Lapidus, A., & Korobeynikov, A. (2020). Using SPAdes de novo assembler. *Current Protocols in Bioinformatics*, 70(1), e102.

QuantStack. (2020). *Mamba: The fast cross-platform package manager*. GitHub. https://github.com/mamba-org/mamba

Rodriguez-R, L. M., & Konstantinidis, K. T. (2020). Classifying prokaryotic genomes using the Microbial Genomes Atlas (MiGA) webserver. In *Bergey's Manual of Systematics of Archaea and Bacteria*. https://doi.org/10.1002/9781118960608.ch4m

Seemann, T. (2014). Prokka: Rapid prokaryotic genome annotation. *Bioinformatics*, 30(14), 2068–2069. https://doi.org/10.1093/bioinformatics/btu153

Seemann, T. (n.d.). *ABRicate* [Software]. GitHub. https://github.com/tseemann/abricate

Tatham, S. (2024). *PuTTY: A free SSH and Telnet client* (Version 0.79). https://www.chiark.greenend.org.uk/~sgtatham/putty/

---

## Citation

If you use this protocol in your research, please cite the original tools listed above and acknowledge the LABEM/UFRJ and Universidad Nacional de Colombia teams.

---

*Protocol developed at LABEM — Laboratory of Biotechnology and Microbial Ecology, UFRJ, Brazil. August 2025.*
