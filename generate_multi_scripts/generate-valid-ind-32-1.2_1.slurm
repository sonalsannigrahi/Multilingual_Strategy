#!/bin/bash
#SBATCH --job-name=eval-bpe    # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=10       # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --partition=gpu          # Name of the partition
#SBATCH --gres=gpu:rtx8000:1     # GPU nodes are only available in gpu partition
#SBATCH --mem=20G                # Total memory allocated
#SBATCH --hint=multithread       # we get physical cores not logical
#SBATCH --time=20:00:00          # total run time limit (HH:MM:SS)
#SBATCH --output=eval%j.out   # output file name
#SBATCH --error=eval%j.out    # error file name

#echo "### Running $SLURM_JOB_NAME ###"

set -x
cd ${SLURM_SUBMIT_DIR}


if [ -n $SLURM_JOB_ID ];  then
    # check the original location through scontrol and $SLURM_JOB_ID
    thisscript=$(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}')
    thisdir=`dirname $thisscript`
else
    # otherwise: started with bash. Get the real location.
    thisdir=`realpath $(dirname $0)`
fi


# params
bpe=32000
temp=1.2
langpairs="ne-en,hi-en,gu-en"
type=bpe
seed=1

# get path to data by defining its location relative to the directory of the current script
maindir=`realpath $thisdir/../` # path to main directory to define all paths assuming that thisdir is in maindir/scripts

datadir=$maindir/data/bin
data=$datadir/${bpe}_gu_hi_ne_en_temp${temp}_$seed
langlist=$maindir/new-scripts/langs-en-gu-hi-ne.txt
modeldir=$maindir/models/joint-en-gu-hi-ne-${type}-${temp}-${bpe}-$seed
outputdir=$modeldir/valid_outputs

# outputs to be store in $modeldir/valid_outputs
[ -d $outputdir ] || mkdir $outputdir

# translate each of the model checkpoints
for model in `ls -tr $modeldir/checkpoint*.pt`; do
    checkpoint=`basename $model`
    for langpair in gu-en ne-en hi-en; do
	src=`echo $langpair | cut -f 1 -d'-'`
	trg=`echo $langpair | cut -f 2 -d'-'`
	# translate the valid set if it is not already translated
	if [ ! -s $outputdir/$checkpoint.output.$langpair ]; then
	    fairseq-generate $data --path $model --task translation_multi_simple_epoch \
		--gen-subset valid  --source-lang $src  --target-lang $trg  \
		--batch-size 32 --encoder-langtok tgt --lang-dict $langlist \
		--lang-pairs $langpairs \
		> $outputdir/$checkpoint.output.$langpair
	fi
	
	# postprocess data (customise this if you need to)
	if [ ! -s $outputdir/$checkpoint.postproc.$langpair ]; then
            cat $outputdir/$checkpoint.output.$langpair \
		| grep "H-" | perl -pe 's/^H-//' | \
		sort -n | cut -f3 | perl -pe 's/ //g;s/▁/ /g' \
		> $outputdir/$checkpoint.postproc.$langpair
	fi
    done
done
