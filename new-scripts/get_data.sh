#!/bin/sh
#  preprocess.sh
#
#
#  Created by Sonal Sannigrahi on 02/07/2021.
#

PAIRS=('fi-en' 'et-en' 'hi-en' 'ne-en' 'gu-en')
thisdir=`realpath $(dirname $0)`
datadir=$thisdir/../data

# Create all directories
[ -d $datadir ] || mkdir $datadir
[ -d $datadir/raw_corpora ] || mkdir $datadir/raw_corpora
for PAIR in "${PAIRS[@]}"; do
    [ -d $datadir/$PAIR ] || mkdir $datadir/$PAIR
    [ -d $datadir/$PAIR/raw_corpora ] || mkdir $datadir/$PAIR/raw_corpora
done
[ -d $datadir/dev_test ] || mkdir $datadir/dev_test

echo '>> data directories made...'


#######################
##   DATA DOWNLOAD    #
#######################

## valid/test wmt data
for year in 18 19; do
    for dset in dev test; do
	[ -f $datadir/wmt$year-$dset.tgz ] || wget -O $datadir/wmt$year-$dset.tgz http://data.statmt.org/wmt$year/translation-task/$dset.tgz --no-check-certificate
	if [ ! -f $datadir/.wmt$year-$dset ]; then
	    echo ">> unzipping dev files"
	    tar -zxvf $datadir/wmt$year-$dset.tgz -C $datadir/
	    echo "done " > $datadir/.wmt$year-$dset # log that this has been done
	fi
    done
done
# clean up locations - all goes into dev_test/
for folder in dev test sgm; do
    if [ -d $datadir/$folder ]; then
	mv $datadir/$folder/* $datadir/dev_test/
	rm -r $datadir/$folder
    fi
done
# reformat Hindi. N.B. test set not actually directional
for dset in dev test; do
    if [ ! -f $datadir/dev_test/news${dset}2014-hien-src.hi.sgm ]; then
	echo "mv $datadir/dev_test/news${dset}2014-src.hi.sgm $datadir/dev_test/news${dset}2014-hien-src.hi.sgm"
	echo "$datadir/dev_test/news${dset}2014-ref.en.sgm $datadir/dev_test/news${dset}2014-hien-ref.en.sgm"
	mv $datadir/dev_test/news${dset}2014-src.hi.sgm $datadir/dev_test/news${dset}2014-hien-src.hi.sgm
	mv $datadir/dev_test/news${dset}2014-ref.en.sgm $datadir/dev_test/news${dset}2014-hien-ref.en.sgm
    fi
done

### Extract dev data
language_pairs=( hi-en fi-en et-en gu-en )
years=( 2014 2015 2018 2019 )

for dset in dev test; do
    for i in "${!language_pairs[@]}"; do
	src=`echo ${language_pairs[i]} | cut -f 1 -d"-"`
	trg=`echo ${language_pairs[i]} | cut -f 2 -d"-"`
	if [ ! -f $datadir/$src-$trg/$dset.$src-$trg.$trg ]; then
	    cat $datadir/dev_test/news$dset${years[i]}-$src$trg-ref.$trg.sgm | grep "<seg" | perl -pe 's/<seg.+?>(.+?)<\/seg>/\1/' \
		> $datadir/$src-$trg/$dset.$src-$trg.$trg
	fi
	if [ ! -f $datadir/$src-$trg/valid.$src-$trg.$src ]; then
	    cat $datadir/dev_test/news$dset${years[i]}-$src$trg-src.$src.sgm | grep "<seg" | perl -pe 's/<seg.+?>(.+?)<\/seg>/\1/' \
		> $datadir/$src-$trg/$dset.$src-$trg.$src
	fi
    done
done


### Gujarati Training Data Download
# Wikititles, bible-uedin, localisation, emille, wikipedia-promt, crawled-cleaned
# TODO: Emille - it is not sentence-aligned yet...
if [ ! -f $datadir/gu-en/train.gu-en.en ]; then
    [ -f $datadir/gu-en/raw_corpora/bible.tsv.gz ] || wget -O $datadir/gu-en/raw_corpora/bible.tsv.gz http://data.statmt.org/wmt19/translation-task/bible.gu-en.tsv.gz --no-check-certificate
    [ -f $datadir/gu-en/raw_corpora/wiki.tsv.gz ] || wget -O $datadir/gu-en/raw_corpora/wiki.tsv.gz http://data.statmt.org/wmt19/translation-task/wikipedia.gu-en.tsv.gz --no-check-certificate
    [ -f $datadir/gu-en/raw_corpora/wikititles.tsv.gz ] || wget -O $datadir/gu-en/raw_corpora/wikititles.tsv.gz http://data.statmt.org/wikititles/v1/wikititles-v1.gu-en.tsv.gz --no-check-certificate
    [ -f $datadir/gu-en/raw_corpora/govin-clean.tsv.gz ] || wget -O $datadir/gu-en/raw_corpora/govin-clean.tsv.gz http://data.statmt.org/wmt19/translation-task/govin-clean.gu-en.tsv.gz --no-check-certificate
    [ -f $datadir/gu-en/raw_corpora/localisation.tsv.gz ] || wget -O $datadir/gu-en/raw_corpora/localisation.tsv.gz http://data.statmt.org/wmt19/translation-task/opus.gu-en.tsv.gz --no-check-certificate

    for corpus in wiki wikititles bible govin-clean localisation; do
	zcat $datadir/gu-en/raw_corpora/$corpus.tsv.gz | cut -f 1 | perl -pe 's/\t/ /g' >> $datadir/gu-en/train.gu-en.gu
	zcat $datadir/gu-en/raw_corpora/$corpus.tsv.gz | cut -f 2 | perl -pe 's/\t/ /g'>> $datadir/gu-en/train.gu-en.en
    done
fi


### Estonian Training Data Download
# europarl-v7, rapid2016, paracrawl
if [ ! -f $datadir/et-en/train.et-en.en ]; then
    [ -f $datadir/et-en/raw_corpora/europarl-v7.tgz ] || wget -O $datadir/et-en/raw_corpora/europarl-v7.tgz https://www.statmt.org/europarl/v7/et-en.tgz --no-check-certificate
    [ -f $datadir/raw_corpora/rapid2016.tgz ] || wget -O $datadir/raw_corpora/rapid2016.tgz http://data.statmt.org/wmt18/translation-task/rapid2016.tgz --no-check-certificate
    [ -f $datadir/et-en/raw_corpora/paracrawl.tgz ] || wget -O $datadir/et-en/raw_corpora/paracrawl.tgz https://s3.amazonaws.com/web-language-models/paracrawl/release1/paracrawl-release1.en-et.zipporah0-dedup-clean.tgz

    for corpus in europarl-v7; do # paracrawl (removed)
	[ -d $datadir/et-en/raw_corpora/$corpus ] || mkdir $datadir/et-en/raw_corpora/$corpus
	tar -zxvf $datadir/et-en/raw_corpora/$corpus.tgz -C $datadir/et-en/raw_corpora/$corpus
	# rename paracrawl corpus
	if [[ $corpus == paracrawl ]]; then
	    for lang in et en; do
		mv $datadir/et-en/raw_corpora/$corpus/paracrawl-release1.en-et.zipporah0-dedup-clean.$lang \
		    $datadir/et-en/raw_corpora/$corpus/$corpus.et-en.$lang
	    done
	fi
	# output to train
	for lang in et en; do
	    cat $datadir/et-en/raw_corpora/$corpus/$corpus.et-en.$lang | perl -pe 's/\t/ /g' >> $datadir/et-en/train.et-en.$lang
	done
    done
    # corpora with other languages in too
    for corpus in rapid2016; do
	[ -d $datadir/raw_corpora/$corpus ] || mkdir $datadir/raw_corpora/$corpus
	tar -zxvf $datadir/raw_corpora/$corpus.tgz -C $datadir/raw_corpora/$corpus
	for lang in et en; do
	    cat $datadir/raw_corpora/$corpus/$corpus.en-et.$lang | perl -pe 's/\t/ /g' >> $datadir/et-en/train.et-en.$lang
	done
    done
fi

### Finnish Training Data Download
# europarl-v9, paracrawl, wikititles, rapid2016
if [ ! -f $datadir/fi-en/train.fi-en.en ]; then
    [ -f $datadir/fi-en/raw_corpora/paracrawl.tgz ] || wget -O $datadir/fi-en/raw_corpora/paracrawl.tgz https://s3.amazonaws.com/web-language-models/paracrawl/release1/paracrawl-release1.en-fi.zipporah0-dedup-clean.tgz
    [ -f $datadir/fi-en/raw_corpora/europarl.tsv.gz ] || wget -O $datadir/fi-en/raw_corpora/europarl.tsv.gz http://www.statmt.org/europarl/v9/training/europarl-v9.fi-en.tsv.gz --no-check-certificate
    [ -f $datadir/fi-en/raw_corpora/wikititles.tsv.gz ] || wget -O $datadir/fi-en/raw_corpora/wikititles.tsv.gz http://data.statmt.org/wikititles/v1/wikititles-v1.fi-en.tsv.gz --no-check-certificate
    tar -zxvf $datadir/fi-en/raw_corpora/paracrawl.tgz -C $datadir/fi-en/raw_corpora/

    for corpus in wikititles europarl; do
	#gunzip -c $datadir/fi-en/$corpus.tsv.gz > $datadir/fi-en/$corpus.tsv
	zcat $datadir/fi-en/raw_corpora/$corpus.tsv.gz | cut -f 1 | perl -pe 's/\t/ /g' >> $datadir/fi-en/train.fi-en.fi
	zcat $datadir/fi-en/raw_corpora/$corpus.tsv.gz | cut -f 2 | perl -pe 's/\t/ /g' >> $datadir/fi-en/train.fi-en.en
    done
    for lang in fi en; do
	cat $datadir/fi-en/raw_corpora/paracrawl-release1.en-fi.zipporah0-dedup-clean.$lang | perl -pe 's/\t/ /g' >> $datadir/fi-en/train.fi-en.$lang
    done
fi


### Nepali training data
# TODO: add Nepali PTB data?
if [ ! -f $datadir/ne-en/train.ne-en.en ]; then
    wget -O $datadir/ne-en/raw_corpora/bible-uedin.zip https://object.pouta.csc.fi/OPUS-bible-uedin/v1/moses/en-ne.txt.zip
    wget -O $datadir/ne-en/raw_corpora/TED2020.zip https://object.pouta.csc.fi/OPUS-TED2020/v1/moses/en-ne.txt.zip
    wget -O $datadir/ne-en/raw_corpora/QED.zip https://object.pouta.csc.fi/OPUS-QED/v2.0a/moses/en-ne.txt.zip
    wget -O $datadir/ne-en/raw_corpora/GlobalVoices.zip https://opus.nlpl.eu/download.php?f=GlobalVoices/v2018q4/moses/en-ne.txt.zip
    wget -O $datadir/ne-en/raw_corpora/GNOME.zip https://opus.nlpl.eu/download.php?f=GNOME/v1/moses/en_GB-ne.txt.zip
    wget -O $datadir/ne-en/raw_corpora/KDE4.zip https://opus.nlpl.eu/download.php?f=KDE4/v2/moses/en-ne.txt.zip
    for corpus in bible-uedin TED2020 QED GlobalVoices GNOME KDE4; do
	unzip -o $datadir/ne-en/raw_corpora/$corpus -d $datadir/ne-en/raw_corpora/$corpus
	cat $datadir/ne-en/raw_corpora/$corpus/$corpus.en-ne.en | perl -pe 's/\t/ /g' >> $datadir/ne-en/train.ne-en.en
	cat $datadir/ne-en/raw_corpora/$corpus/$corpus.en-ne.ne | perl -pe 's/\t/ /g' >> $datadir/ne-en/train.ne-en.ne
    done
fi
### Nepali dev/test data
if [ ! -f $datadir/ne-en/dev.ne-en.en ]; then
    [ -d $datadir/raw_corpora/flores.tar.gz ] || wget -O $datadir/raw_corpora/flores.tar.gz https://dl.fbaipublicfiles.com/flores101/dataset/flores101_dataset.tar.gz
    [ -f $datadir/raw_corpora/flores101_dataset ] || tar -xvzf $datadir/raw_corpora/flores.tar.gz -C $datadir/raw_corpora/
    
    mv $datadir/raw_corpora/flores101_dataset/dev/npi.dev $datadir/ne-en/dev.ne-en.ne
    mv $datadir/raw_corpora/flores101_dataset/dev/eng.dev $datadir/ne-en/dev.ne-en.en
    mv $datadir/raw_corpora/flores101_dataset/devtest/npi.devtest $datadir/ne-en/test.ne-en.ne
    mv $datadir/raw_corpora/flores101_dataset/devtest/eng.devtest $datadir/ne-en/test.ne-en.en
fi


### Hindi Training Data Download
# IITB, wikititles, HindEnCorp
if [ ! -f $datadir/hi-en/train.hi-en.en ]; then
    [ -f $datadir/hi-en/raw_corpora/iitb.tgz ] || wget -O $datadir/hi-en/raw_corpora/iitb.tgz https://www.cfilt.iitb.ac.in/~parallelcorp/iitb_en_hi_parallel/iitb_corpus_download/parallel.tgz
    [ -f $datadir/raw_corpora/wikititles-wmt14.tgz ] || wget -O $datadir/raw_corpora/wikititles-wmt14.tgz https://www.statmt.org/wmt14/wiki-titles.tgz --no-check-certificate
    [ -f $datadir/hi-en/raw_corpora/hindencorp.tsv.gz ] || wget -O $datadir/hi-en/raw_corpora/hindencorp.tsv.gz https://lindat.mff.cuni.cz/repository/xmlui/bitstream/handle/11858/00-097C-0000-0023-625F-0/hindencorp05.plaintext.gz
    
    # for hindi-specific corpora
    for corpus in hi-en/raw_corpora/iitb raw_corpora/wikititles-wmt14; do
	[ -d $datadir/$corpus ] || mkdir $datadir/$corpus
	tar -zxvf $datadir/$corpus.tgz -C $datadir/$corpus
    done

    for lang in en hi; do
	cat $datadir/hi-en/raw_corpora/iitb/parallel/IITB.en-hi.$lang >> $datadir/hi-en/raw_corpora/train.hi-en.$lang
    done
    zcat $datadir/hi-en/raw_corpora/hindencorp.tsv.gz | cut -f4 >> $datadir/hi-en/train.hi-en.en
    zcat $datadir/hi-en/raw_corpora/hindencorp.tsv.gz | cut -f5 >> $datadir/hi-en/train.hi-en.hi
    cat $datadir/raw_corpora/wikititles-wmt14/wiki/hi-en/wiki-titles.hi-en | cut -d"|" -f1 >> $datadir/hi-en/train.hi-en.hi
    cat $datadir/raw_corpora/wikititles-wmt14/wiki/hi-en/wiki-titles.hi-en | cut -d"|" -f4 >> $datadir/hi-en/train.hi-en.en 
fi

### Hindi DevTest data
if [ ! -f $datadir/hi-en/raw_corpora/iitb-dev.hi-en.en ]; then
    [ -f $datadir/hi-en/raw_corpora/iitb-devtest.tgz ] || wget -O $datadir/hi-en/raw_corpora/iitb-devtest.tgz https://www.cfilt.iitb.ac.in/~parallelcorp/iitb_en_hi_parallel/iitb_corpus_download/dev_test.tgz
    tar -zxvf $datadir/hi-en/raw_corpora/iitb-devtest.tgz -C $datadir/hi-en
    for dset in dev test; do
	for lang in en hi; do
	    mv $datadir/hi-en/dev_test/$dset.$lang $datadir/hi-en/iitb-$dset.hi-en.$lang
	done
    done
fi
echo ">> Got all training/dev/test data"
