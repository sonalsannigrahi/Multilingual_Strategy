#!/usr/bin/python
import os, re
import argparse
from sacrebleu.metrics import BLEU
import pandas as pd
import pickle

parser = argparse.ArgumentParser()
parser.add_argument('modeldir')
parser.add_argument('datadir')
args = parser.parse_args()

def read_file(filename, ref=False):
    contents = []
    with open(filename) as fp:
        for line in fp:
            line = line.strip()
            contents.append(line)
    if ref:
        return [contents]
    return contents

cachefile = args.modeldir + '/.cache-bleu-scores-epoch.pickle'
if os.path.exists(cachefile):
   results = pickle.load(open(cachefile, 'rb')) 
else:
    results = {}
#print(results)
bleu = BLEU()
lp2ref = {}
for output in os.listdir(args.modeldir + '/valid_outputs/'):
    namematch = re.match('.*?checkpoint(\d+).pt.postproc.([a-z\-]+)', output)
    if namematch:
        checkpoint = int(namematch.group(1))
        langpair = namematch.group(2)
        if langpair not in results:
            results[langpair] = {}
        if langpair not in lp2ref:
            lp2ref[langpair] = read_file(args.datadir + '/' + langpair + '/dev.' + langpair + '.' + langpair.split('-')[-1], ref=True)
        if checkpoint not in results[langpair]:
            hyp = read_file(args.modeldir + '/valid_outputs/' + output)
            results[langpair][checkpoint] = bleu.corpus_score(hyp, lp2ref[langpair]).score
print(results)
df = pd.DataFrame(results).sort_index()
lps = sorted(results.keys())
df = df[lps]

with pd.option_context('display.max_rows', None, 'display.max_columns', None):  # more options can be specified also
    print(df)

# save cache file
pickle.dump(results, open(cachefile, 'wb'))
