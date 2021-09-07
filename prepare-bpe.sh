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
