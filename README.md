# Tokenisation in Multilingual MT

This repository gathers code to separately tokenise text into chars and BPE and then train different multilingual transformer models in supervised machine translation. 

## Setup

First, create a new conda env where you can install the requirements/dependencies. 

```
$ conda create -n pt_env python=3.8
$ conda init bash
$ conda activate pt_env
$ conda install pytorch torchvision torchaudio cudatoolkit=11.1 -c pytorch -c nvidia
$ pip install sentencepiece fairseq
```

## Training and Evaluation Scripts
----

New scripts:

Download raw data (produces $pair/{train,dev,test}.$pair.final.{src,trg}
```
bash train_scripts/get_data.sh
```

Run the script to transliterate data after:

```
python3 transliterate.py
```

Preprocess data sets (normalisation, filtering, deduplication, segmentation (bpe, char), binarisation
```
bash train_scripts/process_data.sh
bash train_scripts/process_data_tl.sh
```

Train a model as follows (replace {}-{} with the vocabulary size and temperature combination so 24-1.5 for 24K and 1.5 temp):
```
sbatch train_scripts/multilingual/train-bpe-{}-{}-1.slurm
sbatch train_scripts/bilingual/train-bpe-{}-{}-1.slurm
sbatch train_scripts/multilingual-transliterate/train-bpe-{}-{}-1.slurm
sbatch train_scripts/bilingual-transliterate/train-bpe-{}-{}-1.slurm
```

Generate the validation sets from each checkpoint (after each epoch) [f if finetuning] (replace {}-{} with the vocabulary size and temperature combination so 24-1.5 for 24K and 1.5 temp):
```
sbatch generate-valid-ind-{}-{}-1.slurm 
sbatch generate-valid-ind-{}-{}-f.slurm 
```
The outputs are saved to `model-bpe/valid_outputs/checkpointEPOCH.pt.postproc.{}-en`, where `EPOCH` is the epoch number.

Score each generated validation file and produce a tab-separated results table:
````
python ../../../../train_scripts/score-all-epochs-valid.py model-bpe ../../../../data/
```
