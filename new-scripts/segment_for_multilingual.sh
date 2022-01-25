#!/bin/sh
thisdir=`realpath $(dirname $0)`
datadir=$thisdir/../data
databindir="$datadir/bin"
export PYTHONPATH="$PYTHONPATH:$thisdir"

PAIRS=('gu-en' 'et-en' 'hi-en' 'ne-en' 'fi-en')
BPESIZES="48000 32000 24000 16000" # possibility to add more
TEMPS="1.2 1.5 1.8"
BPELANGS="en-et-fi-gu-hi-ne"


langs='gu hi ne en'
src_langs='gu hi ne'
trg_langs='en'

# compute number of sentences available for each language
declare -A total_sents
for lang in $langs; do
    total_sents[$lang]=$(cat $datadir/*$lang*/train.*$lang*.final.$lang | wc -l)	
done

for subdir in sampled bin spm_models; do
    [ -d $datadir/$subdir ] || mkdir $datadir/$subdir
done

for temp in 1.2 1.5 1.8; do
    # calculate how much data to sample for each language

    if [ ! -f  "$datadir/sampled/sampling_percent_${langs// /_}_temp$temp.txt" ]; then
	pair2number_str="{\"hi\": ${total_sents[hi]}, 
                          \"gu\": ${total_sents[gu]}, 
                          \"ne\": ${total_sents[ne]}, 
                          \"en\": ${total_sents[en]}}"
        python -c "import sampling; sampling.temperature_sampling_get_n($pair2number_str, temp=$temp)" \
	    > $datadir/sampled/sampling_percent_${langs// /_}_temp$temp.txt
    fi
    echo ">> Sampling the following percentage from each language to train the BPE models:"
    cat $datadir/sampled/sampling_percent_${langs// /_}_temp$temp.txt

    for num in 1 2 3; do
	
	# sample n sentences from all languages
	total=10000000 
	if [ ! -f $datadir/sampled/sampling_data_${langs// /_}_temp${temp}_$num ]; then
	    for lang in $langs; do
		n=`cat $datadir/sampled/sampling_percent_${langs// /_}_temp$temp.txt | grep $lang | cut -f 2`
		n=`echo "$n*$total" | bc`
		cat $datadir/*$lang*/train.*$lang*.final.$lang | \
                    python -c "import sampling; sampling.sample_n($n, ${total_sents[$lang]})" \
                    >> $datadir/sampled/sampling_data_${langs// /_}_temp${temp}_$num
            done
	fi
	for bpesize in 48000 32000 24000 16000; do
	    signature="$bpesize_${langs// /_}_temp${temp}_$num"

	    # train a bpe model
            if [ ! -f $datadir/spm_models/spm.$signature.model ]; then
		echo "Training spm model $BPESIZE $TEMP"
		python $thisdir/spm_train.py \
                    --input=$datadir/sampled/sampling_data_${langs// /_}_temp${temp}_$num \
                    --model_prefix=$datadir/spm_models/spm.$signature \
                    --vocab_size=$bpesize \
                    --character_coverage=1.0 \
                    --model_type=bpe \
			--num_threads=8 
            fi
	    # encode all data with this bpe model
	    for src in langs; do
		for trg in langs; do
		    for dset in train dev test; do
			if [ -f $datadir/$pair/$dset.$pair.final.$src ]; then
			    for lang in src trg; do
				if [ ! -f $datadir/$pair/$dset.$pair.final.$signaure.$lang ]; then
				    python $thisdir/spm_encode.py \
					--model $datadir/spm_models/spm.$signature \
					--output_format=piece \
					--inputs $datadir/$pair/$dset.$pair.final.$lang \
					--outputs $datadir/$pair/$dset.$pair.final.$signature.$lang
				fi
			    done
			fi	
		    done
		done
	    done
	    # binarise
	    # get joint dictionary
            if [ ! -f $datadir/dict/dict.$signature.txt ]; then
		tail -n +4 $datadir/spm_models/spm.$signature.vocab | \
                    cut -f1 | sed 's/$/ 100/g' > $datadir/dict/dict.$signature.txt
            fi
            if [ ! -d $databindir/$signature ]; then
		for lang in langs; do
		    src=lang; trg=en
                    fairseq-preprocess --source-lang $src --target-lang $trg \
			--trainpref $datadir/$pair/train.$pair.final.$signature \
			--validpref $datadir/$pair/dev.$pair.final.$signature \
			--testpref $datadir/$pair/test.$pair.final.$signature \
			--srcdict $datadir/dict/dict.$signature.txt \
			--tgtdict $datadir/dict/dict.$signature.txt \
			--destdir $databindir/$signature \
			--workers 10
		done
		cp $datadir/dict/dict.$signature.txt $databindir/$signature/dict.txt
            fi
	done
    done
done
