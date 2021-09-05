#!/bin/sh

#  train-char.sh
#  
#
#  Created by Sonal Sannigrahi on 20/08/2021.
#  

export PATH=/opt/homebrew/bin:$PATH

SRCS=(
    "fi"
    "hi"
    "et"
    "ne"
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
SCRIPTS=./scripts
SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

SIZE=32000

DATAC=./multi.en.char32k

mkdir -p "$DATAC"
#learn char tokenisation
TRAIN_FILES=$(for SRC in "${SRCS[@]}"; do echo ./data/${SRC}/${SRC}-${TGT}.train_${SRC}-sampled; echo ./data/${SRC}/${SRC}-${TGT}.train_${TGT}-sampled; done | tr "\n" ",")
echo "learning joint char over ${TRAIN_FILES}..."
python "$SPM_TRAIN" \
    --input=$TRAIN_FILES \
    --model_prefix=$DATAC/sentencepiece.char \
    --vocab_size=$SIZE \
    --character_coverage=1.0 \
    --model_type=char \

echo "encoding training data with learned char model..."
for SRC in "${SRCS[@]}"; do
    python "$SPM_ENCODE" \
        --model "$DATAC/sentencepiece.char.model" \
        --output_format=piece \
        --inputs ./${SRC}-${TGT}.train_${SRC}-sampled ./${SRC}-${TGT}.train_${TGT}-sampled \
        --outputs ./data/train.char.${SRC}-${TGT}.${SRC} ./data/train.char.${SRC}-${TGT}.${TGT} \
        --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
done

echo "encoding valid with learned char model..."
for ((i=0;i<${#SRCS[@]};++i)); do
    SRC=${SRCS[i]}
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.char.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-valid/valid-${SRC}-${TGT}.${SRC} ./data/${SRC}-valid/valid-${SRC}-${TGT}.${TGT} \
        --outputs $DATA/valid.char.${SRC}-${TGT}.${SRC} $DATA/valid.char.${SRC}-${TGT}.${TGT}
done

####################
#   BINARISATION   #
####################

#### Convert joint char vocab into dictionary

tail -n +4 ./multi.en.char32k/sentencepiece.char.vocab | cut -f1 | sed 's/$/ 100/g' > fairseq-multi-en-char.vocab


for SRC in "${SRCS[@]}"; do
    fairseq-preprocess --source-lang ${SRC} --target-lang en \
        --trainpref ./data/train.char.${SRC}-en \
        --validpref ./data/valid.char.${SRC}-en \
        --tgtdict fairseq-multi-en-char.vocab \
        --destdir data-bin/multi-en.char32k/ \
        --workers 10
done

#################
#   TRAINING    #
#################

mkdir -p checkpoints/multilingual_transformer_char

CUDA_VISIBLE_DEVICES=0 fairseq-train data-bin/multi-en.char32k/ \
 --encoder-normalize-before --decoder-normalize-before \
 --arch transformer --layernorm-embedding \
 --task translation_multi_simple_epoch \
 --sampling-method "temperature" \
 --sampling-temperature 1.5 \
 --encoder-langtok "src" \
 --decoder-langtok \
 --lang-dict "$lang_list" \
 --lang-pairs "$lang_pairs" \
 --criterion label_smoothed_cross_entropy --label-smoothing 0.2 \
 --optimizer adam --adam-eps 1e-06 --adam-betas '(0.9, 0.98)' \
 --lr-scheduler inverse_sqrt --lr 3e-05 --warmup-updates 2500 --max-update 40000 \
 --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0 \
 --max-tokens 1024 --update-freq 2 \
 --save-interval 1 --save-interval-updates 5000 --keep-interval-updates 10\
 --save-dir checkpoints/multilingual_transformer_char \
 --seed 222 --log-format simple --log-interval 2

