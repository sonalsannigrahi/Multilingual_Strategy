#!/bin/sh
#  preprocess.sh
#
#
#  Created by Sonal Sannigrahi on 02/07/2021.
#

MOSESSCRIPTS=~/scratch/tools/mosesdecoder/scripts
thisdir=`realpath $(dirname $0)`
datadir=$thisdir/../data
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"

PAIRS=('gu-en' 'et-en' 'hi-en' 'ne-en' 'fi-en')
BPESIZES="32000"  #"24000 32000" # possibility to add more
BPELANGS="en-et-fi-gu-hi-ne"  #"et-fi-gu-hi-ne en-et-fi-gu-hi-ne en" # different combinations for joint BPE

# 1. Finalise dataset by normalising (train, dev and test) and filtering/cleaning (train only)
for pair in "${PAIRS[@]}"; do
    for dset in train dev test; do
	src=`echo $pair | cut -d'-' -f1`
	trg=`echo $pair | cut -d'-' -f2`
	echo ">> Processing $pair $dset"
	for lang in $src $trg; do
	    # normalise punctuation
	    if [ ! -f $datadir/$pair/$dset.$pair.norm.$lang ]; then
		cat $datadir/$pair/$dset.$pair.$lang | perl $MOSESSCRIPTS/tokenizer/normalize-punctuation.perl $lang \
		    > $datadir/$pair/$dset.$pair.norm.$lang
	    fi
	done
	if [ $dset == "train" ]; then
	    # filter out unwanted sentences and deduplicate in train only
	    if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg ]; then
		paste $datadir/$pair/train.$pair.norm.$src $datadir/$pair/train.$pair.norm.$trg | \
		    python $thisdir/clean_parallel.py -l1 $src -l2 $trg | sort -u \
		    > $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg
	    fi
	    if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$src ]; then
		cat $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg | cut -f 1 > $datadir/$pair/$dset.$pair.norm.clean.dedup.$src
	    fi
	    if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg ]; then
		cat $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg | cut -f 2 > $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg
	    fi
	    echo ">> Linking final raw datasets"
	    ln -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg $datadir/$pair/$dset.$pair.final.$src-$trg
	    ln -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$src $datadir/$pair/$dset.$pair.final.$src
	    ln -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg $datadir/$pair/$dset.$pair.final.$trg
	else
	    ln -sf $datadir/$pair/$dset.$pair.norm.$src $datadir/$pair/$dset.$pair.final.$src
            ln -sf $datadir/$pair/$dset.$pair.norm.$trg $datadir/$pair/$dset.$pair.final.$trg
	fi
    done
done


# 2. Prepare sampled dataset to train segmentation models (from final train set)
[ -d $datadir/sampled ] || mkdir $datadir/sampled
# compute number of sentences
declare -A total_all
declare -A total_no_en
for lang in hi fi gu ne et en; do
    total_all[$lang]=$(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
    if [[ $lang != "en" ]]; then
	total_no_en[$lang]=$(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
    fi
    echo $lang, $(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
done

# calculate how much data to sample for each language
pair2number_all="{\"hi\": ${total_all[hi]}, \"fi\": ${total_all[fi]}, \"gu\": ${total_all[gu]}, \"ne\": ${total_all[ne]}, \"et\": ${total_all[et]}, \"en\": ${total_all[en]}}"
python -c "import sampling; sampling.temperature_sampling_get_n($pair2number_all, temp=1.5)" \
    > $datadir/sampled/sampling_per_language_all.txt

echo $pair2number_all

pair2number_no_en="{\"hi\": ${total_no_en[hi]}, \"fi\": ${total_no_en[fi]}, \"gu\": ${total_no_en[gu]}, \"ne\": ${total_no_en[ne]}, \"et\": ${total_no_en[et]}}"
python -c "import sampling; sampling.temperature_sampling_get_n($pair2number_no_en, temp=1.5)" \
    > $datadir/sampled/sampling_per_language_no_en.txt

echo ">> Sampling the following percentage from each language to train the BPE models:"
echo ">> All languages"
cat $datadir/sampled/sampling_per_language_all.txt
echo ">> All languages but English"
cat $datadir/sampled/sampling_per_language_no_en.txt


total=2500000 # total of 10M lines
# go through all languages included and sample n sentences
if [ ! -f $datadir/sampled/sampled.et-fi-gu-hi-ne ]; then
    for lang in et fi gu hi ne; do
	n=`cat $datadir/sampled/sampling_per_language_no_en.txt | grep $lang | cut -f 2`
	n=`echo "$n*$total" | bc`
	cat $datadir/*$lang*/train.*$lang*.final.$lang | \
	    python -c "import sampling; sampling.sample_n($n, ${total_no_en[$lang]})" \
	    >> $datadir/sampled/sampled.et-fi-gu-hi-ne	
    done
fi
if [ ! -f $datadir/sampled/sampled.en-et-fi-gu-hi-ne ]; then
    for lang in en et fi gu hi ne; do
	n=`cat $datadir/sampled/sampling_per_language_all.txt | grep $lang | cut -f 2`
	n=`echo "$n*$total" | bc`
	cat $datadir/*$lang*/train.*$lang*.final.$lang | \
	    python -c "import sampling; sampling.sample_n($n, ${total_all[$lang]})" \
	    >> $datadir/sampled/sampled.en-et-fi-gu-hi-ne
    done
fi
# get sample of English
echo ">> Getting sampled English data"
if [ ! -f $datadir/sampled/sampled.en ]; then
    cat $datadir/*en*/train.*final.en | shuf | head -n $total > $datadir/sampled/sampled.en
fi
# encode sampled data as bytes and chars
for seg in byte char; do
    if [ ! -f $datadir/sampled/sampled.$BPELANGS.$seg ]; then
	cat $datadir/sampled/sampled.$BPELANGS | python -c "import segment; segment.${seg}_encode()" \
	    > $datadir/sampled/sampled.$BPELANGS.$seg
    fi
done

[ -d $datadir/spm_models ] || mkdir $datadir/spm_models
# train bpe models
echo ">> Training sentencepiece models"
for BPESIZE in $BPESIZES; do
    for langs in $BPELANGS; do
	if [ ! -f $datadir/spm_models/spm.$langs-$BPESIZE.model ]; then
	    python $thisdir/spm_train.py \
		--input=$datadir/sampled/sampled.$langs \
		--model_prefix=$datadir/spm_models/spm.$langs-$BPESIZE \
		--vocab_size=$BPESIZE \
		--character_coverage=1.0 \
		--model_type=bpe \
		--num_threads=8 
	fi
    done
done

# char-based
for langs in $BPELANGS; do
    if [ ! -f $datadir/spm_models/spm.$langs-char.model ]; then
        python $thisdir/spm_train.py \
		--input=$datadir/sampled/sampled.$langs$suffix \
	    --model_prefix=$datadir/spm_models/spm.$langs-char \
	    --character_coverage=1.0 \
	    --model_type=char \
	    --num_threads=8
    fi
done


# encode files w/ bpe
echo ">> Encoding files with BPE"
for pair in "${PAIRS[@]}"; do
    echo $pair
    for dset in train dev test; do
	echo $dset
	for BPESIZE in $BPESIZES char; do
	    src=`echo $pair | cut -d'-' -f1`
	    trg=`echo $pair | cut -d'-' -f2`
	    if [[ "$BPESIZE" == "char" ]]; then
		infix=$BPESIZE
	    else
		infix=$BPELANGS-$BPESIZE
	    fi
	    echo $infix
	    for lang in $src $trg; do
		if [[ $BPELANGS == *"$lang"* ]]; then
		    if [ ! -f $datadir/$pair/$dset.$pair.final.$infix.$lang ]; then
			python $thisdir/spm_encode.py \
			    --model $datadir/spm_models/spm.$BPELANGS-$BPESIZE.model \
			    --output_format=piece \
			    --inputs $datadir/$pair/$dset.$pair.final.$lang \
			    --outputs $datadir/$pair/$dset.$pair.final.$infix.$lang 
		    fi
		fi
	    done
	done
    done
done


# encode files as bytes
echo ">> Encoding files as bytes"
for pair in ${PAIRS[@]}; do
    for dset in train dev test; do
	src=`echo $pair | cut -d'-' -f1`
	trg=`echo $pair | cut -d'-' -f2`
	if [ ! -f $datadir/$pair/$dset.$pair.final.byte.$lang ]; then
	    for lang in $src $trg; do
		cat $datadir/$pair/$dset.$pair.final.$lang | python -c "import segment; segment.byte_encode()" \
		    > $datadir/$pair/$dset.$pair.final.byte.$lang
	    done
	fi
    done
done

# binarise (fairseq-preprocess)
echo ">> Binarising files"
[ -d $datadir/dict ] || mkdir $datadir/dict
comma_langs=`echo $BPELANGS | perl -pe 's/\-/,/g'`
maximum_byte=240
for BPESIZE in char byte $BPESIZES; do
    # get joint dictionary
    if [ ! -f $datadir/dict/dict.$BPELANGS-$BPESIZE.txt ]; then
	if [[ "$BPESIZE" == "byte" ]]; then
	    # get manually
	    for ((i=1; i<=$maximum_byte; i++)); do
		echo "$i 100" >> $datadir/dict/dict.$BPELANGS-$BPESIZE.txt
	    done
	else
	    tail -n +4 $datadir/spm_models/spm.$BPELANGS-$BPESIZE.vocab | cut -f1 | sed 's/$/ 100/g' > $datadir/dict/dict.$BPELANGS-$BPESIZE.txt
	fi
    fi
    if [[ $BPESIZE == char ]] || [[ $BPESIZE == byte ]]; then
        infix=$BPESIZE
    else
        infix=$BPELANGS-$BPESIZE
    fi
    if [ ! -d $databindir/joint-$BPELANGS-$BPESIZE ]; then
	for pair in "${PAIRS[@]}"; do
            src=`echo $pair | cut -d'-' -f1`
            trg=`echo $pair | cut -d'-' -f2`
            fairseq-preprocess --source-lang $src --target-lang $trg \
		--trainpref $datadir/$pair/train.$pair.final.$infix \
		--validpref $datadir/$pair/dev.$pair.final.$infix \
		--testpref $datadir/$pair/test.$pair.final.$infix \
		--srcdict $datadir/dict/dict.$BPELANGS-$BPESIZE.txt \
		--tgtdict $datadir/dict/dict.$BPELANGS-$BPESIZE.txt \
		--destdir $databindir/joint-$BPELANGS-$BPESIZE \
		--workers 10
	done
	# now binarise each language
	cp $datadir/dict/dict.$BPELANGS-$BPESIZE.txt $databindir/joint-$BPELANGS-$BPESIZE/dict.txt
    fi
done
