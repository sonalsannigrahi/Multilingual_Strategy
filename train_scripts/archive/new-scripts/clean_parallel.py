#!/usr/bin/env python
# -*- coding: utf-8 -*-

# script from Roman (Edinburgh)

import sys
import re
import argparse


MIN_LENGTH = 2
MAX_LENGTH = 100

RATIO_LENGTH = 0.3

RATIO_ALPHA_WORDS = 0.5
RATIO_ALPHA_CHARS = 0.5

CHARS = {
    'en': r'[a-zA-Z]',
    'es': r'[a-zÁáÉéÍíÓóÚúñÑ¡!¿?]',
    'et': r'[a-zA-ZäõöšüžÄÕÖŠÜŽ]',
    'ta': u'[\u0b82-\u0bd7]', # excludes numerics, calendrical symbols, clerical symbols and currency symbol
    'fi': r'[a-zA-ZäåöšžÄÅÖŠŽ]',
    'hi': r'[\u0900-\u097F]',
    'ne': r'[\u0900-\u097F]',
    'gu': r'[\u0A80-\u0AFF]'
}


def main():
    args = parse_user_args()

    # for each line in input
    for i, line in enumerate(sys.stdin):
        fields = line.strip().split('\t')
        if len(fields) < 2:
            continue

        # get source and target sentences
        src = re.sub(' +', ' ', fields[-2].strip())
        trg = re.sub(' +', ' ', fields[-1].strip())

        # skip or keep
        skip = clean_parallel(src, trg, args.src_lang, args.trg_lang)
        if args.debug and skip:
            sys.stderr.write("{}\t{}".format(skip, line))
            continue
        if not skip:
            sys.stdout.write(line)



def clean_parallel(src, trg, src_lang, trg_lang):
    # identical source and target
    if src.lower() == trg.lower():
        return "IDENTICAL"

    src_toks = src.split()
    trg_toks = trg.split()
    src_len = len(src_toks)
    trg_len = len(trg_toks)

    # at least one side empty
    if not src_len or not trg_len:
        return "EMPTY" #+ str((src_len, trg_len))

    # ratio between sentence lengths not good
    ratio_len = src_len / float(trg_len)
    if ratio_len < RATIO_LENGTH or ratio_len > (1. / RATIO_LENGTH):
        return "RATIO_LENGTH {}".format(ratio_len)

    # at least one sentence too long or too short
    if src_len < MIN_LENGTH or trg_len < MIN_LENGTH:
        return "TOO_SHORT"

    if src_len > MAX_LENGTH or trg_len > MAX_LENGTH:
        return "TOO_LONG"


    # do not include these characters
    for char in ["{", "}"]:
        if char in src or char in trg:
            return "DISALLOWED_CHARACTER"
        
    # not enough alphabetical words
    num_alpha = sum(
        [1 if re.match('.*?' + CHARS[src_lang], t, re.A | re.I) else 0 for t in src_toks])
    if num_alpha / float(src_len) < RATIO_ALPHA_WORDS:
        return "RATIO_ALPHA_SRC"
    num_alpha = sum(
        [1 if re.match('.*?' + CHARS[trg_lang], t, re.IGNORECASE) else 0 for t in trg_toks])
    if num_alpha / float(trg_len) < RATIO_ALPHA_WORDS:
        return "RATIO_ALPHA_TRG"

    # not enough alphabetical characters
    char_alpha = len(re.findall(CHARS[src_lang], src, re.IGNORECASE))
    if char_alpha / float(len(src.replace(' ', ''))) < RATIO_ALPHA_CHARS:
        return "RATIO_CHARS_SRC"
    char_alpha = len(re.findall(CHARS[trg_lang], trg, re.IGNORECASE))
    if char_alpha / float(len(trg.replace(' ', ''))) < RATIO_ALPHA_CHARS:
        return "RATIO_CHARS_TRG"

    return None


def parse_user_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-l1", "--src-lang", default='es')
    parser.add_argument("-l2", "--trg-lang", default='en')
    parser.add_argument("--debug", action='store_true')
    return parser.parse_args()


if __name__ == "__main__":

    

    main()

    
