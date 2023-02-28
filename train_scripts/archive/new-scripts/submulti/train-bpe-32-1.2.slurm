#!/bin/bash
##SBATCH -C v100-32g
#SBATCH -A ncm@gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=2           # number of cores per task (with gpu_p2: 1/8 of the 8-GPUs node)  
#SBATCH --job-name=norm   # nom du job
#SBATCH --ntasks=1             # Nombre total de processus MPI
#SBATCH --ntasks-per-node=1    # Nombre de processus MPI par noeud
# Dans le vocabulaire Slurm "multithread" fait référence à l'hyperthreading.
#SBATCH --hint=nomultithread   # 1 processus MPI par coeur physique (pas d'hyperthreading)
#SBATCH --time=20:00:00        # Temps d’exécution maximum demande (HH:MM:SS)
#SBATCH --output=multitrain_%j.out  # Nom du fichier de sortie contenant l'ID et l'indice
#SBATCH --error=multitrain_%j.out   # Nom du fichier d'erreur (ici commun avec la sortie)

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

datadir=$thisdir/../../data
modeldir=$thisdir/../../models
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"


# params
bpe=32000
temp=1.2
langpairs="ne-en,hi-en,gu-en"
type=bpe
seed=222

data=$databindir/${bpe}_gu_hi_ne_en_temp${temp}_$seed
langlist=$thisdir/../langs-en-gu-hi-ne.txt

[ -d $thisdir/model ] || mkdir $thisdir/model

fairseq-train $data \
   --encoder-normalize-before --decoder-normalize-before \
   --arch transformer --layernorm-embedding \
   --task translation_multi_simple_epoch \
   --sampling-method "temperature" \
   --sampling-temperature $temp \
   --encoder-langtok "tgt" \
   --lang-dict $langlist \
   --lang-pairs $langpairs \
   --lr 0.005 \
   --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
   --optimizer adam --adam-eps 1e-06 --adam-betas '(0.9, 0.98)' \
   --lr-scheduler inverse_sqrt --lr 3e-05 --warmup-updates 2500 \
   --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0 \
   --scoring sacrebleu --bpe sentencepiece \
   --max-tokens 2048 --update-freq 2 \
   --save-interval 5 --validate-interval 5 \
   --save-dir $thisdir/model \
   --seed $seed --log-format simple --log-interval 500 \
   --patience 20
