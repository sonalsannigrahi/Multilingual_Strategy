# Tokenisation in Multilingual MT

This repository gathers code to separtely tokenise text into bytes, chars, and BPE and then train different multilingual transformer models in supervised machine translation. 

## Training Instructions 

First, create a new conda env where you can install the requirements/dependencies. 

```
$ conda create -n pt_env python=3.8
$ conda init bash
$ conda activate pt_env
$ conda install pytorch torchvision torchaudio cudatoolkit=11.1 -c pytorch -c nvidia
$ pip install sentencepiece fairseq
```

Locally run the preprocess.sh script to extract, clean, and byte-encode the training and validation data for Finnish, Estonian, Hindi, Gujarati, and Nepali.

```
$ sh preprocess.sh
```

Next, run the prepare-{byte, char, bpe}.sh scripts to learn respective tokenisation models, tokenise the data, and then binarise it to get it ready for training. 

```
$ sh prepare-bpe.sh
```

Then, run the training scripts on the gpu via the batch files. This should start the training for all the models. 

```
$ sbatch bpe-tok.batch
```

## Evaluation Scripts



----

New scripts:

Download raw data (produces $pair/{train,dev,test}.$pair.final.{src,trg}
```
bash new-scripts/get_data.sh
```

Preprocess data sets (normalisation, filtering, deduplication, segmentation (bpe, char, bytes), binarisation
```
bash new-scripts/process_data.sh
```

Train a model (Rachel's runs)
```
cd cd models/et-fi-gu-hi-ne2en/sp48k-tmp1.2/{1,2,3}
sbatch train-bpe.slurm
```

Generate the validation sets from each checkpoint (after each epoch):
```
sbatch generate-valid.slurm
```
The outputs are saved to `model-bpe/valid_outputs/checkpointEPOCH.pt.postproc.ne-en`, where `EPOCH` is the epoch number.

Score each generated validation file and produce a tab-separated results table:
````
python ../../../../new-scripts/score-all-epochs-valid.py model-bpe ../../../../data/
```
