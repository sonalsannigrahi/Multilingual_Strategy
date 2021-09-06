#!/bin/sh

#  train.sh
#  
#
#  Created by Sonal Sannigrahi on 20/08/2021.
#

export PATH=/opt/homebrew/bin:$PATH

SRCS=(
    "hi"
    "fi"
    "gu"
    "ne"
    "et"
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
DATA=./multi.en.bpe32k

mkdir -p "$DATA"

# learn BPE with sentencepiece
TRAIN_FILES=$(for SRC in "${SRCS[@]}"; do echo ./data/${SRC}/${SRC}-${TGT}.train_${SRC}-sampled; echo ./data/${SRC}/${SRC}-${TGT}.train_${TGT}-sampled; done | tr "\n" ",")
echo "learning joint BPE over ${TRAIN_FILES}..."
python "$SPM_TRAIN" \
    --input=$TRAIN_FILES \
    --model_prefix=$DATA/sentencepiece.bpe \
    --vocab_size=$BPESIZE \
    --character_coverage=1.0\
    --model_type=bpe \
    --num_threads=8 \

#encode train
echo "encoding training data with learned BPE..."
for SRC in "${SRCS[@]}"; do
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.bpe.model" \
        --output_format=piece \
        --inputs ./data/${SRC}/${SRC}-${TGT}.train_${SRC}-sampled ./data/${SRC}/${SRC}-${TGT}.train_${TGT}-sampled \
        --outputs $DATA/train.bpe.${SRC}-${TGT}.${SRC} $DATA/train.bpe.${SRC}-${TGT}.${TGT} \
        --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
done

#validation data does not need to be sampled?

#encode valid
echo "encoding valid with learned BPE..."
for ((i=0;i<${#SRCS[@]};++i)); do
    SRC=${SRCS[i]}
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.bpe.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-valid/valid-${SRC}-${TGT}.${SRC} ./data/${SRC}-valid/valid-${SRC}-${TGT}.${TGT} \
        --outputs $DATA/valid.bpe.${SRC}-${TGT}.${SRC} $DATA/valid.bpe.${SRC}-${TGT}.${TGT}
done

####################
#   BINARISATION   #
####################

#### Convert joint bpe vocab into dictionary

tail -n +4 ./multi.en.bpe32k/sentencepiece.bpe.vocab | cut -f1 | sed 's/$/ 100/g' > fairseq-multi-en.vocab

for SRC in "${SRCS[@]}"; do
    fairseq-preprocess --source-lang ${SRC} --target-lang en \
        --trainpref $DATA/train.bpe.${SRC}-en \
        --validpref $DATA/valid.bpe.${SRC}-en \
        --tgtdict fairseq-multi-en.vocab \
        --destdir data-bin/multi-en.bpe32k/ \
        --workers 10
done


#################
#   TRAINING    #
#################


#BPE MODEL
mkdir -p checkpoints/multilingual_transformer

#command does not work because of language dict?
# CUDA_VISIBLE_DEVICES=0 fairseq-train data-bin/multi-en.bpe32k/ \
#   --encoder-normalize-before --decoder-normalize-before \
#   --arch transformer --layernorm-embedding \
#   --task translation_multi_simple_epoch \
#   --sampling-method "temperature" \
#   --sampling-temperature 1.5 \
#   --encoder-langtok "src" \
#   --decoder-langtok \
#   --lang-dict "lang.txt" \
#   --lang-pairs fi-en,ne-en,et-en,hi-en,gu-en \
#   --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
#   --optimizer adam --adam-eps 1e-06 --adam-betas '(0.9, 0.98)' \
#   --lr-scheduler inverse_sqrt --lr 3e-05 --warmup-updates 2500 --max-update 40000 \
#   --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0 \
#   --max-tokens 1024 --update-freq 2 \
#   --save-interval 1 --save-interval-updates 5000 --keep-interval-updates 10\
#   --save-dir checkpoints/multilingual_transformer \
#   --seed 222 --log-format simple --log-interval 2

CUDA_VISIBLE_DEVICES=0 fairseq-train data-bin/multi-en.bpe32k/ \
    --task multilingual_translation --lang-pairs fi-en,ne-en,et-en,hi-en,gu-en \
    --arch multilingual_transformer_iwslt_de_en \
    --share-decoders --share-decoder-input-output-embed \
    --optimizer adam --adam-betas '(0.9, 0.98)' \
    --lr 0.0005 --lr-scheduler inverse_sqrt \
    --warmup-updates 4000 --warmup-init-lr '1e-07' \
    --label-smoothing 0.1 --criterion label_smoothed_cross_entropy \
    --dropout 0.3 --weight-decay 0.0001 \
    --save-dir checkpoints/multilingual_transformer \
    --max-tokens 4000 \
    --update-freq 8
