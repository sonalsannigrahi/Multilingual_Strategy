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

PAIRS=('et-en' 'fi-en')
BPESIZES="48000 32000 24000 16000" # possibility to add more
TEMPS="1.2 1.5 1.8"
BPELANGS="en-et-fi-gu-hi-ne"

# 1. Finalise dataset by normalising (train, dev and test) and filtering/cleaning (train only)
for pair in "${PAIRS[@]}"; do
    for dset in train dev test; do
	src=`echo $pair | cut -d'-' -f1`
	trg=`echo $pair | cut -d'-' -f2`
	echo ">> Processing $pair $dset"
	for lang in $src $trg; do
	    # normalise punctuation
	    #if [ ! -f $datadir/$pair/$dset.$pair.norm.$lang ]; then
		cat $datadir/$pair/$dset.$pair.$lang | perl $MOSESSCRIPTS/tokenizer/normalize-punctuation.perl $lang \
		    > $datadir/$pair/$dset.$pair.norm.$lang
	    #fi
	done
	if [ $dset == "train" ]; then
	    # filter out unwanted sentences and deduplicate in train only
	    #if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg ]; then
		paste $datadir/$pair/train.$pair.norm.$src $datadir/$pair/train.$pair.norm.$trg | \
		    python $thisdir/clean_parallel.py -l1 $src -l2 $trg | sort -u \
		    > $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg
	    #fi
	    #if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$src ]; then
		cat $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg | cut -f 1 > $datadir/$pair/$dset.$pair.norm.clean.dedup.$src
	    #fi
	    #if [ ! -f $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg ]; then
		cat $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg | cut -f 2 > $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg
	    #fi
	    echo ">> Linking final raw datasets"
	    lsn -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$src-$trg $datadir/$pair/$dset.$pair.final.$src-$trg
	    ln -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$src $datadir/$pair/$dset.$pair.final.$src
	    ln -sf $datadir/$pair/$dset.$pair.norm.clean.dedup.$trg $datadir/$pair/$dset.$pair.final.$trg
	else
	    ln -sf $datadir/$pair/$dset.$pair.norm.$src $datadir/$pair/$dset.$pair.final.$src
            ln -sf $datadir/$pair/$dset.$pair.norm.$trg $datadir/$pair/$dset.$pair.final.$trg
	fi
    done
done


# 2. Encode models with characters and bytes
[ -d $datadir/sampled ] || mkdir $datadir/sampled
[ -d $datadir/spm_models ] || mkdir $datadir/spm_models

[ ! -f $datadir/sampled/sampled.$BPELANGS ] || rm $datadir/sampled/sampled.$BPELANGS
for lang in `echo $BPELANGS | perl -pe 's/-/ /g'`; do
    cat $datadir/*$lang*/train.*$lang*.final.$lang >> $datadir/sampled/sampled.$BPELANGS
done
