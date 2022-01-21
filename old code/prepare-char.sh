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
        --inputs ./data/${SRC}/${SRC}-${TGT}.train_${SRC}-sampled ./data/${SRC}/${SRC}-${TGT}.train_${TGT}-sampled \
        --outputs $DATAC/train.char.${SRC}-${TGT}.${SRC} $DATAC/train.char.${SRC}-${TGT}.${TGT} \
        --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
done

echo "encoding valid with learned char model..."
for ((i=0;i<${#SRCS[@]};++i)); do
    SRC=${SRCS[i]}
    python "$SPM_ENCODE" \
        --model "$DATAC/sentencepiece.char.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-valid/valid-${SRC}-${TGT}.${SRC} ./data/${SRC}-valid/valid-${SRC}-${TGT}.${TGT} \
        --outputs $DATAC/valid.char.${SRC}-${TGT}.${SRC} $DATAC/valid.char.${SRC}-${TGT}.${TGT}
done

####################
#   BINARISATION   #
####################

#### Convert joint char vocab into dictionary

tail -n +4 ./multi.en.char32k/sentencepiece.char.vocab | cut -f1 | sed 's/$/ 100/g' > fairseq-multi-en-char.vocab


for SRC in "${SRCS[@]}"; do
    fairseq-preprocess --source-lang ${SRC} --target-lang en \
        --trainpref $DATAC/train.char.${SRC}-en \
        --validpref $DATAC/valid.char.${SRC}-en \
        --tgtdict fairseq-multi-en-char.vocab \
        --destdir data-bin/multi-en.char32k/ \
        --workers 10
done
