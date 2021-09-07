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

#adapted from fairseq example: https://github.com/pytorch/fairseq/tree/master/examples/translation

SCRIPTS=./scripts
SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

BPESIZE=32000
DATA=./multi.en.byte32k

mkdir -p "$DATA"

# learn byte-encoding with sentencepiece
TRAIN_FILES=$(for SRC in "${SRCS[@]}"; do echo ./data/${SRC}/${SRC}-${TGT}.train.${SRC}-byte-encoded; echo ./data/${SRC}/${SRC}-${TGT}.train.${TGT}-byte-encoded; done | tr "\n" ",")
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
        --inputs ./data/${SRC}/${SRC}-${TGT}.train.${SRC}-byte-encoded ./data/${SRC}/${SRC}-${TGT}.train.${TGT}-byte-encoded \
        --outputs $DATA/train.byte.${SRC}-${TGT}.${SRC} $DATA/train.byte.${SRC}-${TGT}.${TGT} \
        --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
done

#encode valid
echo "encoding valid with learned BPE..."
for ((i=0;i<${#SRCS[@]};++i)); do
    SRC=${SRCS[i]}
    python "$SPM_ENCODE" \
        --model "$DATA/sentencepiece.byte.model" \
        --output_format=piece \
        --inputs ./data/${SRC}-valid/${SRC}-${TGT}.valid.${SRC}-byte-encoded ./data/${SRC}-valid/${SRC}-${TGT}.valid.${TGT}-byte-encoded \
        --outputs $DATA/valid.byte.${SRC}-${TGT}.${SRC} $DATA/valid.byte.${SRC}-${TGT}.${TGT}
done

####################
#   BINARISATION   #
####################


#### Convert joint bpe vocab into dictionary

tail -n +4 ./multi.en.byte32k/sentencepiece.byte.vocab | cut -f1 | sed 's/$/ 100/g' > fairseq-multi-en-byte.vocab


for SRC in "${SRCS[@]}"; do
    fairseq-preprocess --source-lang ${SRC} --target-lang en \
        --trainpref $DATA/train.byte.${SRC}-en \
        --validpref $DATA/valid.byte.${SRC}-en \
        --tgtdict fairseq-multi-en-byte.vocab \
        --destdir data-bin/multi-en.byte32k/ \
        --workers 10
done
