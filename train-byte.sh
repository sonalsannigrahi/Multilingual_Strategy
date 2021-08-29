#!/bin/sh

#  train-byte.sh
#  
#
#  Created by Sonal Sannigrahi on 25/08/2021.
#
export PATH=/opt/homebrew/bin:$PATH

SRCS=(
    "fi"
    "et"
    "hi"
    "gu"
)

TGT=(
    "en"
)

TRAIN_MINLEN=1  # remove sentences with <1 token
TRAIN_MAXLEN=250  # remove sentences with >250 tokens

export PYTHONPATH="$(pwd)"

#####################
#   TOKENISATION    #
#####################

#adapted from fairseq example: https://github.com/pytorch/fairseq/tree/master/examples/translation

SCRIPTS=./scripts
SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

BPESIZE=32000
DATA=./multi.en.byte32k

mkdir -p "$DATA"

# learn byte-encoding with sentencepiece
TRAIN_FILES=$(for SRC in "${SRCS[@]}"; do echo ./data/${SRC}-${TGT}.train_${SRC}; echo ./data/${SRC}-${TGT}.train_${TGT}; done | tr "\n" ",")
echo "learning joint byte model over ${TRAIN_FILES}..."
python "$SPM_TRAIN" \
    --input=$TRAIN_FILES \
    --model_prefix=$DATA/sentencepiece.byte \
    --vocab_size=$BPESIZE \
    --character_coverage=1.0 \
    --model_type=char \

#encode train
echo "encoding training data with learned byte encoding..."
for SRC in "${SRCS[@]}"; do
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.byte.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-${TGT}.train_${SRC} ./data/${SRC}-${TGT}.train_${TGT} \
        --outputs ./data/train.byte.${SRC}-${TGT}.${SRC} ./data/train.byte.${SRC}-${TGT}.${TGT} \
        --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
done

#encode valid
echo "encoding valid with learned BPE..."
for ((i=0;i<${#SRCS[@]};++i)); do
    SRC=${SRCS[i]}
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.byte.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-${TGT}.valid_${SRC} ./data/${SRC}-${TGT}.valid_${TGT} \
        --outputs $DATA/valid.byte.${SRC}-${TGT}.${SRC} $DATA/valid.byte.${SRC}-${TGT}.${TGT}
done

####################
#   BINARISATION   #
####################


#### Convert joint bpe vocab into dictionary

tail -n +4 ./multi.en.byte32k/sentencepiece.byte.vocab | cut -f1 | sed 's/$/ 100/g' > fairseq-multi-en-byte.vocab


for SRC in "${SRCS[@]}"; do
    fairseq-preprocess --source-lang ${SRC} --target-lang en \
        --trainpref ./data/train.byte.${SRC}-en \
        --validpref ./data/valid.byte.${SRC}-en \
        --tgtdict fairseq-multi-en-byte.vocab \
        --destdir data-bin/multi-en.byte32k/ \
        --workers 10
done


#################
#   TRAINING    #
#################


##BPE MODEL
#mkdir -p checkpoints/multilingual_transformer
#
#
#CUDA_VISIBLE_DEVICES=0 fairseq-train data-bin/multi-en.bpe32k/ \
#  --encoder-normalize-before --decoder-normalize-before \
#  --arch transformer --layernorm-embedding \
#  --task translation_multi_simple_epoch \
#  --sampling-method "temperature" \
#  --sampling-temperature 1.5 \
#  --encoder-langtok "src" \
#  --decoder-langtok \
#  --lang-dict "$lang_list" \
#  --lang-pairs "$lang_pairs" \
#  --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
#  --optimizer adam --adam-eps 1e-06 --adam-betas '(0.9, 0.98)' \
#  --lr-scheduler inverse_sqrt --lr 3e-05 --warmup-updates 2500 --max-update 40000 \
#  --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0 \
#  --max-tokens 1024 --update-freq 2 \
#  --save-interval 1 --save-interval-updates 5000 --keep-interval-updates 10\
#  --save-dir checkpoints/multilingual_transformer \
#  --seed 222 --log-format simple --log-interval 2

#CHAR MODEL



#BYTE MODEL


