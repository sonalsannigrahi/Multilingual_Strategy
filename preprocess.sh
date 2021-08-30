#!/bin/sh
#  preprocess.sh
#  
#
#  Created by Sonal Sannigrahi on 02/07/2021.
#  
export PATH=/opt/homebrew/bin:$PATH

#install dependencies

$pip install sentencepiece sacremoses fairseq sacrebleu

SRCS=(
    "fi"
    "et"
    "hi"
    "gu"
)

TGT=(
    "en"
)

TRAIN_MINLEN=1  # remove sentences with <1 token
TRAIN_MAXLEN=250  # remove sentences with >250 tokens

export PYTHONPATH="$(pwd)"

if [ ! -d "data" ]; then
  mkdir data
  for SRC in "${SRCS[@]}"; do
  cd data
  mkdir $SRC
  mkdir $SRC-valid
  cd ../
  done
  
fi

cd data
mkdir ne-valid
cd ../

echo 'data directories made...'

mkdir data-bin

cd data-bin

mkdir multi-en.bpe32k
mkdir multi-en.char32k
mkdir multi-en.byte32k

cd ../

echo 'binarisation directories made...'

mkdir data-scrap
#######################
##   DATA DOWNLOAD    #
#######################

## valid/test wmt data

wget -O multi-valid.tgz http://data.statmt.org/wmt18/translation-task/dev.tgz

tar zxvf multi-valid.tgz -C ./data/

wget -O gu-valid.tgz http://data.statmt.org/wmt19/translation-task/dev.tgz

tar zxvf gu-valid.tgz -C ./data/

###MOVE DATA###

mv ./data/dev/newsdev2015-fien-ref.en.sgm ./data/fi-valid/valid-fi-en.en
mv ./data/dev/newsdev2015-fien-src.fi.sgm ./data/fi-valid/valid-fi-en.fi

mv ./data/dev/newsdev2018-eten-ref.en.sgm ./data/et-valid/valid-et-en.en
mv ./data/dev/newsdev2018-eten-src.et.sgm ./data/et-valid/valid-et-en.et

mv ./data/dev/newsdev2019-guen-src.gu.sgm ./data/gu-valid/valid-gu-en.gu
mv ./data/dev/newsdev2019-guen-ref.en.sgm ./data/gu-valid/valid-gu-en.en

###Gujarati Training Data Download
wget -O gu-en-bible.tsv.gz http://data.statmt.org/wmt19/translation-task/bible.gu-en.tsv.gz
wget -O gu-en-wiki.tsv.gz http://data.statmt.org/wmt19/translation-task/wikipedia.gu-en.tsv.gz
wget -O gu-en-wikititles.tsv.gz http://data.statmt.org/wikititles/v1/wikititles-v1.gu-en.tsv.gz
gunzip -c gu-en-wiki.tsv.gz > ./data/gu/wiki.tsv
gunzip -c gu-en-wikititles.tsv.gz > ./data/gu/titles.tsv
gunzip -c gu-en-bible.tsv.gz > ./data/gu/bible.tsv

###Estonian Training Data Download

wget -O et-en-europarl.tgz https://www.statmt.org/europarl/v7/et-en.tgz

tar zxvf et-en-europarl.tgz -C ./data/et

###Finnish Training Data Download

wget -O fi-en-paracrawl.tgz https://s3.amazonaws.com/web-language-models/paracrawl/release1/paracrawl-release1.en-fi.zipporah0-dedup-clean.tgz
wget -O fi-en-wiki.tsv.gz http://data.statmt.org/wikititles/v1/wikititles-v1.fi-en.tsv.gz
wget -O fi-en-europarl.tsv.gz http://www.statmt.org/europarl/v9/training/europarl-v9.fi-en.tsv.gz

tar zxvf fi-en-paracrawl.tgz -C ./data/fi
gunzip -c fi-en-wiki.tsv.gz > ./data/fi/wiki.tsv
gunzip -c fi-en-europarl.tsv.gz > ./data/fi/europarl.tsv

###Nepali Training Data Download

tar -xvzf https://dl.fbaipublicfiles.com/flores101/dataset/flores101_dataset.tar.gz -C ./data/ne-valid

mv ./data/ne-valid/flores101_dataset/dev/npi.dev ./data/ne-valid/valid-ne-en.ne
mv ./data/ne-valid/flores101_dataset/dev/eng.dev ./data/ne-valid/valid-ne-en.en

###Hindi Training Data Download
wget -O hi-en-iitb.tgz https://www.cfilt.iitb.ac.in/~parallelcorp/iitb_en_hi_parallel/iitb_corpus_download/parallel.tgz

tar zxvf hi-en-iitb.tgz -C ./data/hi

###Hindi DevTest data

wget -O hi-en-devtest.tgz https://www.cfilt.iitb.ac.in/~parallelcorp/iitb_en_hi_parallel/iitb_corpus_download/dev_test.tgz

tar zxvf  hi-en-devtest.tgz -C ./data/hi

### FINNISH ####
python -c 'import processor; processor.file_combine("./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.fi","./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.en","fi","en")'

rm ./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.fi
rm ./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.en

cat ./data/fi/* > ./data/en-fi-concat

python -c 'import processor; processor.complete_process("./data/en-fi-concat","fi","en", "fi-en.train")'

python -c 'import processor; processor.byte_encode("./fi-en.train_fi","fi-en.train.fi")'

python -c 'import processor; processor.byte_encode("./fi-en.train_en","fi-en.train.en")'
#### ESTONIAN ####

python -c 'import processor; processor.file_combine("./data/et/europarl-v7.et-en.et","./data/et/europarl-v7.et-en.en","et","en")'
rm ./data/et/europarl-v7.et-en.en
rm ./data/et/europarl-v7.et-en.et

python -c 'import processor; processor.file_combine("./data/et/paracrawl-release1.en-et.zipporah0-dedup-clean.et","./data/et/paracrawl-release1.en-et.zipporah0-dedup-clean.en","et","en", "data/et/et-en-paracrawl.combine")'

rm ./data/et/paracrawl-release1.en-et.zipporah0-dedup-clean.et
rm ./data/et/paracrawl-release1.en-et.zipporah0-dedup-clean.en

cat ./data/et/* > ./data/en-et-concat

python -c 'import processor; processor.complete_process("./data/en-et-concat","et","en", "et-en.train")'

python -c 'import processor; processor.byte_encode("./et-en.train_et","et-en.train.et")'

python -c 'import processor; processor.byte_encode("./et-en.train_en","et-en.train.en")'

#### HINDI #####

python -c 'import processor; processor.file_combine("./data/hi/parallel/IITB.en-hi.hi","./data/hi/parallel/IITB.en-hi.en","hi","en")'

rm -r ./data/hi/parallel

cat ./data/hi/* > ./data/en-hi-concat

python -c 'import processor; processor.complete_process("./data/en-hi-concat","hi","en", "hi-en.train")'

python -c 'import processor; processor.byte_encode("./hi-en.train_hi","hi-en.train.hi")'

python -c 'import processor; processor.byte_encode("./hi-en.train_en","hi-en.train.en")'

## Hindi Valid/Dev data
python -c 'import processor; processor.file_combine("./data/hi/dev_test/dev.hi","./data/hi/dev_test/dev.en","hi","en","data/hi/hi-en.dev)'

cat ./data/hi/hi-en.dev > ./data/en-hi-dev-concat

python -c 'import processor; processor.file_split("./data/en-hi-dev-concat","hi","en", "hi-en.valid_hi", "hi-en.valid_en")'

### Hindi Test Data

python -c 'import processor; processor.file_combine("./data/hi/dev_test/test.hi","./data/hi/dev_test/test.en","hi","en","data/hi/hi-en.test")'

cat ./data/hi/hi-en.test > ./data/en-hi-test-concat

python -c 'import processor; processor.file_split("./data/en-hi-test-concat","hi","en", "hi-en.test_hi", "hi-en.test_en")'

##rm -r ./data/hi/parallel

### GUJARATI ###

cat ./data/gu/* > ./data/en-gu-concat
python -c 'import processor; processor.complete_process("./data/en-gu-concat","gu","en", "gu-en.train")'

python -c 'import processor; processor.byte_encode("./gu-en.train_gu","gu-en.train.gu")'

python -c 'import processor; processor.byte_encode("./gu-en.train_en","gu-en.train.en")'

### NEPALI ###

python -c 'import processor; processor.byte_encode("./ne-en.train_ne","ne-en.train.ne")'

python -c 'import processor; processor.byte_encode("./ne-en.train_en","ne-en.train.en")'

