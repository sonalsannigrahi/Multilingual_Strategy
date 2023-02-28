
#!/bin/sh
#  preprocess.sh
#
#
#  Created by Sonal Sannigrahi on 02/07/2021.
#

MOSESSCRIPTS=~/scratch/tools/mosesdecoder/scripts
thisdir=`realpath $(dirname $0)`
datadir=./data
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"

#Indian family
PAIRS=('gu-en' 'hi-en' 'ne-en')
BPESIZES="10000"

#Uralic family
#PAIRS=('fi-en' 'et-en')
#BPESIZES="16000 32000"

# 1. Train shared BPE models/vocab for each lang pair

[ -d $datadir/spm_models ] || mkdir $datadir/spm_models
# train bpe models
echo ">> Training sentencepiece bilingual models"

for BPESIZE in $BPESIZES; do
    for pair in "${PAIRS[@]}"; do
        src=`echo $pair | cut -d'-' -f1`
        trg=`echo $pair | cut -d'-' -f2`
        TRAIN_FILES=$(for lang in $src $trg; do echo $datadir/$pair/train.$pair.final.$lang; done | tr "\n" ",")
        if [ ! -f $datadir/spm_models/spm.$pair-$BPESIZE.model ]; then
            python $thisdir/spm_train.py \
            --input=$TRAIN_FILES \
            --model_prefix=$datadir/spm_models/spm.$pair-$BPESIZE \
            --vocab_size=$BPESIZE \
            --character_coverage=1.0 \
            --model_type=bpe \
            --num_threads=8
        fi
    done
done

# encode files w/ bpe
echo ">> Encoding files with BPE"
for pair in "${PAIRS[@]}"; do
    echo $pair
    for dset in train dev test; do
    echo $dset
    for BPESIZE in $BPESIZES; do
        src=`echo $pair | cut -d'-' -f1`
        trg=`echo $pair | cut -d'-' -f2`
        infix=$pair-$BPESIZE
        echo $infix
        for lang in $src $trg; do
            if [ ! -f $datadir/$pair/$dset.$pair.final.$infix.$lang ]; then
            python $thisdir/spm_encode.py \
                --model $datadir/spm_models/spm.$pair-$BPESIZE.model \
                --output_format=piece \
                --inputs $datadir/$pair/$dset.$pair.final.$lang \
                --outputs $datadir/$pair/$dset.$pair.final.$infix.$lang
            fi
        done
    done
    done
done

# 3. binarise pairwise datasets (fairseq-preprocess)
echo ">> Binarising files"
[ -d $datadir/dict ] || mkdir $datadir/dict
comma_langs=`echo $BPELANGS | perl -pe 's/\-/,/g'`
maximum_byte=240
for BPESIZE in $BPESIZES; do
    for pair in "${PAIRS[@]}"; do
        tail -n +4 $datadir/spm_models/spm.$pair-$BPESIZE.vocab | cut -f1 | sed 's/$/ 100/g' > $datadir/dict/dict.$pair-$BPESIZE.txt

        infix=$pair-$BPESIZE
        src=`echo $pair | cut -d'-' -f1`
        trg=`echo $pair | cut -d'-' -f2`
        fairseq-preprocess --source-lang $src --target-lang $trg \
            --trainpref $datadir/$pair/train.$pair.final.$infix \
            --validpref $datadir/$pair/dev.$pair.final.$infix \
            --testpref $datadir/$pair/test.$pair.final.$infix \
            --srcdict $datadir/dict/dict.$pair-$BPESIZE.txt \
            --tgtdict $datadir/dict/dict.$pair-$BPESIZE.txt \
            --destdir $databindir/bilingual-$pair-$BPESIZE \
            --workers 10
    done
    for pair in "${PAIRS[@]}"; do
        cp $datadir/dict/dict.$pair-$BPESIZE.txt $databindir/bilingual-$pair-$BPESIZE/dict.txt
    done
done
