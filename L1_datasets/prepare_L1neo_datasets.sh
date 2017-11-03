#!/bin/bash

##### insertion datasets used to generate final figures of Sultana et al. article on L1 insertion site preference

# define folders
BIOINFO="$HOME"
WORKING_DIR=$( pwd )
REF_GENOME_DIR="$BIOINFO/references/human"
REF_GENOME="hg19"
MRC_SCRIPT="${WORKING_DIR}/l1_mrc_generator.sh"

# set global variables
DATASET_FILE="R01-R09.insertions.true.bed"
DATASET_DIR="${WORKING_DIR}"
INS_NAME="l1neo.ins_helas3.soni.hg19"
LOC_NAME="l1neo.loc_helas3.soni.hg19"
DUKE_FILTER="${BIOINFO}/annotations/hg19/other/hg19.wgEncodeDukeMapabilityRegionsExcludable.bed"
ENCODE_FILTER="${BIOINFO}/annotations/hg19/other/hg19.wgEncodeDacMapabilityConsensusExcludable.bed"
GAPLESS_GENOME="${BIOINFO}/annotations/hg19/other/hg19.helaGapLessGenome.bed"

BOOTSTRAP=10 # number of random or control dataset to generate
GC_WINDOW=10 # window of matching base composition around insertion site

# move to working directory
cd ${WORKING_DIR}

#################################################################################
# Reformat L1 insertion data files												#
#################################################################################

echo -ne "Reformat data files..."

######### L1 target loci
# adjust the length of interval spanning each insertion to exactly 2bp

sort -k1,1 -k2,2n "${DATASET_DIR}/${DATASET_FILE}" \
| awk 'BEGIN {i=1} ($1!~/^#/) {printf $1 "\t" $2-1 "\t" $3+1 "\tl1neo|helas3|soni|loc|%04d\t" $5 "\t" $6 "\n", i; i++}' \
> "${LOC_NAME}.bed"
# NB_LOCI=$( awk '$1!~/^#/' "${DATASET_DIR}/${LOC_NAME}.bed" | wc -l )

# adjust the length of interval spanning each insertion to the size of GC_WINDOW
length=$( echo ${GC_WINDOW} | awk '{print int(($1/2)+0.5)-1}' )
bedtools slop -b ${length} -i "${LOC_NAME}.bed" -g "${REF_GENOME_DIR}/${REF_GENOME}.genome" \
> "${LOC_NAME}.${GC_WINDOW}bp.bed"

######### L1 de novo insertions
# adjust the length of interval spanning each insertion to exactly 2bp
# expand the lines representing multiple insertions at the same position

sort -k1,1 -k2,2n "${DATASET_DIR}/${DATASET_FILE}" \
| awk '($1!~/^#/) {while ($5--) {print $0}}' \
| awk 'BEGIN {i=1} {printf $1 "\t" $2-1 "\t" $3+1 "\tl1neo|helas3|soni|ins|%04d\t1\t" $6 "\n", i; i++}' \
> "${INS_NAME}.bed"
# NB_INSERTIONS=$( awk '$1!~/^#/' "${DATASET_DIR}/${INS_NAME}.bed" | wc -l )

# adjust the length of interval spanning each insertion to the size of GC_WINDOW
length=$( echo ${GC_WINDOW} | awk '{print int(($1/2)+0.5)-1}' )
bedtools slop -b ${length} -i "${DATASET_NAME}.bed" -g "${REF_GENOME_DIR}/${REF_GENOME}.genome" \
> "${DATASET_NAME}.${GC_WINDOW}bp.bed"

echo -e "Done"

#################################################################################
# Generate random dataset for ins and loc										#
#################################################################################

echo -ne "Generate random dataset..."

# create an adjusted genome space removing gaps and blacklisted regions as for experimental insertions
bedtools subtract -a ${GAPLESS_GENOME} -b ${DUKE_FILTER} \
| bedtools subtract -a - -b ${ENCODE_FILTER} \
| sort -k1,1 -k2,2n \
> allowed_genome_space.bed

# randomly pick loci
mkdir -p random_loc
for i in $( seq 1 ${BOOTSTRAP});
do
	TAG=$( printf "${WORKING_DIR}/random/l1neo.random_loc_%04d.soni.hg19.bed" $i )
	bedtools shuffle \
		-incl "allowed_genome_space.bed" \
		-noOverlapping \
		-i "l1neo.loc_helas3.soni.hg19.bed" \
		-g "${REF_GENOME_DIR}/${REF_GENOME}.genome" \
	| sort -k1,1 -k2,2n \
	| awk -v OFS="\t" 'BEGIN{j=1} ($1!~/^#/) {printf $1 "\t" $2 "\t" $3 "\tl1neo|insilico|soni|random_loc|%04d\t1\t" $6 "\n", j; j++}' \
	> "${TAG}"
done

# randomly pick ins
mkdir -p random_ins
for i in $( seq 1 ${BOOTSTRAP});
do
	TAG=$( printf "${WORKING_DIR}/random/l1neo.random_ins_%04d.soni.hg19.bed" $i )
	bedtools shuffle \
		-incl "allowed_genome_space.bed" \
		-noOverlapping \
		-i "l1neo.ins_helas3.soni.hg19.bed" \
		-g "${REF_GENOME_DIR}/${REF_GENOME}.genome" \
	| sort -k1,1 -k2,2n \
	| awk -v OFS="\t" 'BEGIN{j=1} ($1!~/^#/) {printf $1 "\t" $2 "\t" $3 "\tl1neo|insilico|soni|random_ins|%04d\t1\t" $6 "\n", j; j++}' \
	> "${TAG}"
done

echo -e "Done"

#################################################################################
# Generate l1 matched random control (mrc) dataset for ins and loc				#
# Base composition in a window of GC_WINDOW bp around ins is conserved			#
#################################################################################

# run external script to generate mrc using parallelization for loc
mkdir -p mrc_loc/
script_start="parallel "${MRC_SCRIPT}" -i "${LOC_NAME}.${GC_WINDOW}bp.bed" -g "${REF_GENOME_DIR}/${REF_GENOME}.fa" -o "${WORKING_DIR}/mrc_loc/l1neo.mrc_loc_{}.soni.hg19.${GC_WINDOW}bp.bed" ::: $( printf "{%04d..%04d}" 1 ${BOOTSTRAP} )"
eval ${script_start}

# modify coordinates of bmc to span only 2nt-intervals
for file in mrc_loc/*.${GC_WINDOW}bp.bed;
do
	name=$(basename "${file}" .${GC_WINDOW}bp.bed)
	awk -v OFS="\t" -v l=${length} 'BEGIN{i=1} ($1!~/^#/) {printf $1 "\t" $2+l "\t" $2+l+2 "\tl1neo|insilico|soni|mrc_loc|%04d\t1\t" $6 "\n", i; i++}' $file \
	> "mrc_loc/${name}.bed"
done

# run external script to generate mrc using parallelization for ins
mkdir -p mrc_ins/
script_start="parallel "${MRC_SCRIPT}" -i "${INS_NAME}.${GC_WINDOW}bp.bed" -g "${REF_GENOME_DIR}/${REF_GENOME}.fa" -o "${WORKING_DIR}/mrc_ins/l1neo.mrc_ins_{}.soni.hg19.${GC_WINDOW}bp.bed" ::: $( printf "{%04d..%04d}" 1 ${BOOTSTRAP} )"
eval ${script_start}

# modify coordinates of bmc to span only 2nt-intervals
for file in mrc_ins/*.${GC_WINDOW}bp.bed;
do
	name=$(basename "${file}" .${GC_WINDOW}bp.bed)
	awk -v OFS="\t" -v l=${length} 'BEGIN{i=1} ($1!~/^#/) {printf $1 "\t" $2+l "\t" $2+l+2 "\tl1neo|insilico|soni|mrc_ins|%04d\t1\t" $6 "\n", i; i++}' $file \
	> "mrc_ins/${name}.bed"
done

# repeat bmc script for some never-ending iterations:
# script_start="parallel "${BMC_SCRIPT}" -i "${DATASET_NAME}.10bp.bed" -g "${REF_GENOME_DIR}/${REF_GENOME}.fa" -o "${WORKING_DIR}/base_comp_matched/l1neo.mrc_loc_{}.soni.hg19.${GC_WINDOW}bp.bed" ::: 0001 0004 0005 0008"
# eval ${script_start}

# to get the average GC content at the insertion sites
#awk 'BEGIN{total=0; mean=0; n=0} {total+=$7; n++} END{mean=total/n; print mean}' l1neo.is_helas3.soni.hg19.10bp.withGCcontent.bed
