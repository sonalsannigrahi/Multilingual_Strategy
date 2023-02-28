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

PAIRS=('gu-en' 'hi-en' 'ne-en')
BPESIZES="16000" # possibility to add more
TEMPS="1.5"
BPELANGS="en-gu-hi-ne"

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


# 2. Encode models with characters
[ -d $datadir/sampled ] || mkdir $datadir/sampled
[ -d $datadir/spm_models ] || mkdir $datadir/spm_models

[ ! -f $datadir/sampled/sampled.$BPELANGS ] || rm $datadir/sampled/sampled.$BPELANGS
for lang in `echo $BPELANGS | perl -pe 's/-/ /g'`; do
    cat $datadir/*$lang*/train.*$lang*.final.$lang >> $datadir/sampled/sampled.$BPELANGS
done

# train char-based model
if [ ! -f $datadir/spm_models/spm.$BPELANGS-char.model ]; then
    python $thisdir/spm_train.py \
	--input=$datadir/sampled/sampled.$BPELANGS \
	--model_prefix=$datadir/spm_models/spm.$BPELANGS-char \
	--character_coverage=1.0 \
	--model_type=char \
	--num_threads=8
fi

# encode files w/ character encoding
echo ">> Encoding files with char sentencepiece"
for pair in "${PAIRS[@]}"; do
    for dset in train dev test; do
        src=`echo $pair | cut -d'-' -f1`
        trg=`echo $pair | cut -d'-' -f2`
        for lang in $src $trg; do
            #if [[ $BPELANGS == *"$lang"* ]]; then
                #if [ ! -f $datadir/$pair/$dset.$pair.final.char.$lang ]; then
                    python $thisdir/spm_encode.py \
                        --model $datadir/spm_models/spm.$BPELANGS-char.model \
                        --output_format=piece \
                        --inputs $datadir/$pair/$dset.$pair.final.$lang \
                        --outputs $datadir/$pair/$dset.$pair.final.char.$lang
                #fi
            #fi
        done
    done
done


# 2. Prepare sampled dataset to train segmentation models (from final train set)
# compute number of sentences
declare -A total_all
declare -A total_no_en
for lang in hi gu ne en; do
    total_all[$lang]=$(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
    if [[ $lang != "en" ]]; then
	total_no_en[$lang]=$(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
    fi
    echo $lang, $(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)
done


# get sampled data to train sentencepiece models with different temperatures
for TEMP in $TEMPS; do
    # calculate how much data to sample for each language
    pair2number_all="{\"hi\": ${total_all[hi]}, \"gu\": ${total_all[gu]}, \"ne\": ${total_all[ne]}, \"en\": ${total_all[en]}}"
    if [ ! -f  $datadir/sampled/sampling_per_language_all_temp$TEMP.txt ]; then
	python -c "import sampling; sampling.temperature_sampling_get_n($pair2number_all, temp=$TEMP)" \
	    > $datadir/sampled/sampling_per_language_all_temp$TEMP.txt
    fi

    echo $pair2number_all
    
    pair2number_no_en="{\"hi\": ${total_no_en[hi]}, \"gu\": ${total_no_en[gu]}, \"ne\": ${total_no_en[ne]}"
    if [ ! -f $datadir/sampled/sampling_per_language_no_en_temp$TEMP.txt ]; then
	python -c "import sampling; sampling.temperature_sampling_get_n($pair2number_no_en, temp=$TEMP)" \
	    > $datadir/sampled/sampling_per_language_no_en_temp$TEMP.txt
    fi


    echo ">> Sampling the following percentage from each language to train the BPE models:"
    echo ">> All languages"
    cat $datadir/sampled/sampling_per_language_all_temp$TEMP.txt
    echo ">> All languages but English"
    cat $datadir/sampled/sampling_per_language_no_en_temp$TEMP.txt


    total=2500000 # total of 10M lines
    # go through all languages included and sample n sentences
    if [ ! -f $datadir/sampled/sampled.gu-hi-ne.temp$TEMP ]; then
	for lang in gu hi ne; do
	    n=`cat $datadir/sampled/sampling_per_language_no_en_temp$TEMP.txt | grep $lang | cut -f 2`
	    n=`echo "$n*$total" | bc`
	    cat $datadir/*$lang*/train.*$lang*.final.$lang | \
		python -c "import sampling; sampling.sample_n($n, ${total_no_en[$lang]})" \
		>> $datadir/sampled/sampled.gu-hi-ne.temp$TEMP	
	done
    fi
    if [ ! -f $datadir/sampled/sampled.en-gu-hi-ne.temp$TEMP ]; then
	for lang in en gu hi ne; do
	    n=`cat $datadir/sampled/sampling_per_language_all_temp$TEMP.txt | grep $lang | cut -f 2`
	    n=`echo "$n*$total" | bc`
	    cat $datadir/*$lang*/train.*$lang*.final.$lang | \
		python -c "import sampling; sampling.sample_n($n, ${total_all[$lang]})" \
		>> $datadir/sampled/sampled.en-gu-hi-ne.temp$TEMP
	done
    fi
    # get sample of English
    echo ">> Getting sampled English data"
    if [ ! -f $datadir/sampled/sampled.en ]; then
	cat $datadir/*en*/train.*final.en | shuf | head -n $total > $datadir/sampled/sampled.en
    fi
    # encode sampled data as bytes and chars
    for seg in byte char; do
	if [ ! -f $datadir/sampled/sampled.$BPELANGS.temp$TEMP.$seg ]; then
	    cat $datadir/sampled/sampled.$BPELANGS.temp$TEMP | python -c "import segment; segment.${seg}_encode()" \
		> $datadir/sampled/sampled.$BPELANGS.temp$TEMP.$seg
	fi
    done


    # train bpe models
    echo ">> Training sentencepiece models"
    for BPESIZE in $BPESIZES; do
	langs=$BPELANGS
	if [ ! -f $datadir/spm_models/spm.$langs-$BPESIZE-temp$TEMP.model ]; then
	    echo "Training spm model $BPESIZE $TEMP"
	    python $thisdir/spm_train.py \
		--input=$datadir/sampled/sampled.$langs.temp$TEMP \
		--model_prefix=$datadir/spm_models/spm.$langs-$BPESIZE-temp$TEMP \
		--vocab_size=$BPESIZE \
		--character_coverage=1.0 \
		--model_type=bpe \
		--num_threads=8 
	fi
    done


    # encode files w/ bpe
    echo ">> Encoding files with BPE"
    for pair in "${PAIRS[@]}"; do
	for dset in train dev test; do
	    for BPESIZE in $BPESIZES; do
		src=`echo $pair | cut -d'-' -f1`
		trg=`echo $pair | cut -d'-' -f2`
		infix=$BPELANGS-$BPESIZE-temp$TEMP
		for lang in $src $trg; do
		    #if [[ $BPELANGS == *"$lang"* ]]; then
			#if [ ! -f $datadir/$pair/$dset.$pair.final.$infix.$lang ]; then
			    python $thisdir/spm_encode.py \
				--model $datadir/spm_models/spm.$infix.model \
				--output_format=piece \
				--inputs $datadir/$pair/$dset.$pair.final.$lang \
				--outputs $datadir/$pair/$dset.$pair.final.$infix.$lang 
			#fi
		    #fi
		done
	    done
	done
    done
done



# binarise (fairseq-preprocess) for bytes and chars
echo ">> Binarising files"
[ -d $datadir/dict ] || mkdir $datadir/dict
[ -d $databindir ] || mkdir $databindir
comma_langs=`echo $BPELANGS | perl -pe 's/\-/,/g'`
maximum_byte=240
for BPESIZE in char; do
    # get joint dictionary
    #if [ ! -f $datadir/dict/dict.$BPELANGS-$BPESIZE.txt ]; then
	if [[ "$BPESIZE" == "byte" ]]; then
	    # get manually
	    for ((i=1; i<=$maximum_byte; i++)); do
		echo "$i 100" >> $datadir/dict/dict.$BPELANGS-$BPESIZE.txt
	    done
	else
	    tail -n +4 $datadir/spm_models/spm.$BPELANGS-$BPESIZE.vocab | cut -f1 | sed 's/$/ 100/g' \
		> $datadir/dict/dict.$BPELANGS-$BPESIZE.txt
	fi
    #fi

    infix=char
    if [ ! -d $databindir/joint-$BPELANGS-$BPESIZE ]; then
	for pair in "${PAIRS[@]}"; do
            src=`echo $pair | cut -d'-' -f1`
            trg=`echo $pair | cut -d'-' -f2`
            fairseq-preprocess --source-lang $src --target-lang $trg \
		--trainpref $datadir/$pair/train.$pair.final.$infix \
		--validpref $datadir/$pair/dev.$pair.final.$infix \
		--testpref $datadir/$pair/test.$pair.final.$infix \
		--srcdict $datadir/dict/dict.$infix.txt \
		--tgtdict $datadir/dict/dict.$infix.txt \
		--destdir $databindir/joint-$infix \
		--workers 10
	done
	# now binarise each language
	cp $datadir/dict/dict.$infix.txt $databindir/joint-$infix/dict.txt
    fi
done

# binarise for subwords
for BPESIZE in $BPESIZES; do
    for TEMP in $TEMPS; do
	# get joint dictionary
	if [ ! -f $datadir/dict/dict.$BPELANGS-$BPESIZE-temp$TEMP.txt ]; then
            tail -n +4 $datadir/spm_models/spm.$BPELANGS-$BPESIZE-temp$TEMP.vocab | \
		cut -f1 | sed 's/$/ 100/g' > $datadir/dict/dict.$BPELANGS-$BPESIZE-temp$TEMP.txt
        fi
        infix=$BPELANGS-$BPESIZE-temp$TEMP
	if [ ! -d $databindir/joint-$infix ]; then
            for pair in "${PAIRS[@]}"; do
		src=`echo $pair | cut -d'-' -f1`
		trg=`echo $pair | cut -d'-' -f2`
		fairseq-preprocess --source-lang $src --target-lang $trg \
                    --trainpref $datadir/$pair/train.$pair.final.$infix \
                    --validpref $datadir/$pair/dev.$pair.final.$infix \
                    --testpref $datadir/$pair/test.$pair.final.$infix \
                    --srcdict $datadir/dict/dict.$infix.txt \
                    --tgtdict $datadir/dict/dict.$infix.txt \
                    --destdir $databindir/joint-$infix \
                    --workers 10
            done
            cp $datadir/dict/dict.$infix.txt $databindir/joint-$infix/dict.txt
	fi
    done
done
