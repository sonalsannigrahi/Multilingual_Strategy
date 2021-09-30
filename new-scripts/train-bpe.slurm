#!/bin/bash
#SBATCH --job-name=bpe-multitok    # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=10       # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --partition=gpu          # Name of the partition
#SBATCH --gres=gpu:rtx6000:1     # GPU nodes are only available in gpu partition
#SBATCH --mem=20G                # Total memory allocated
#SBATCH --hint=multithread       # we get physical cores not logical
#SBATCH --time=20:00:00          # total run time limit (HH:MM:SS)
#SBATCH --output=gpu_bpe%j.out   # output file name
#SBATCH --error=gpu_bpe%j.out    # error file name

echo "### Running $SLURM_JOB_NAME ###"

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

module purge
module load gnu8 cuda

#thisdir=`realpath $(dirname $0)`
datadir=$thisdir/../data
modeldir=$thisdir/../models
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"

data=$databindir/joint-en-et-fi-gu-hi-ne-32000
model=$modeldir/joint-en-et-fi-gu-hi-ne-32000
langpairs="fi-en,ne-en,et-en,hi-en,gu-en"
langlist=$thisdir/langs-en-et-fi-gu-hi-ne.txt

[ -d $modeldir ] || mkdir $modeldir
[ -d $model ] || mkdir $model

fairseq-train $data \
   --encoder-normalize-before --decoder-normalize-before \
   --arch transformer --layernorm-embedding \
   --task translation_multi_simple_epoch \
   --sampling-method "temperature" \
   --sampling-temperature 1.5 \
   --encoder-langtok "tgt" \
   --lang-dict $langlist \
   --lang-pairs $langpairs \
   --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
   --optimizer adam --adam-eps 1e-06 --adam-betas '(0.9, 0.98)' \
   --lr-scheduler inverse_sqrt --lr 3e-05 --warmup-updates 2500 --max-update 40000 \
   --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0 \
   --max-tokens 2048 --update-freq 2 \
   --save-interval-updates 2500 --keep-interval-updates 20 \
   --save-dir $model \
   --seed 222 --log-format simple --log-interval 2 \
    --patience 10
