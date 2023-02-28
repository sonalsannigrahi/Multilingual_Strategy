#!/bin/sh
thisdir=`realpath $(dirname $0)`
datadir=$thisdir/../data
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"

vocabs='16000 32000 24000 48000'
temps='1.2 1.5 1.8'



for vocab in $vocabs; do
    for temp in $temps; do
    
    cat data/mr-en/test.mr-en.mr | python scripts/transliterate.py bn | python ./scripts/spm_encode.py --model data/spm_models/spm.${vocab}_gu_hi_ne_en_temp${temp}_1.model | fairseq-interactive data/bin/${vocab}_gu_hi_ne_en_temp${temp}_1 --path models/joint-en-gu-hi-ne-bpe-${temp}-${vocab}-1/checkpoint_best.pt --remove-bpe --encoder-langtok "tgt" --task translation_multi_simple_epoch --lang-pairs hi-en  --lang-dict ~/scratch/multimt-tokenisation/new-scripts/langs-en-gu-hi-ne.txt | grep "H-" | perl -pe 's/^H-//' | sort -n | cut -f3 | perl -pe 's/ //g;s/▁/ /g' > ./data/mr-en/output_${vocab}_${temp}.txt

    echo 'temp ${temp} vocab ${vocab}'
    
    sacrebleu ./data/mr-en/test.mr-en.en -i ./data/mr-en/output_${vocab}_${temp}.txt -m bleu -b -w 4
    done
done
