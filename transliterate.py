
#!/bin/sh
#  preprocess.sh
#
#
#  Created by Sonal Sannigrahi on 21/01/2022.
#

#set environment variables to load transliterate objects into the main file
INDIC_NLP_LIBRARY='../indic_nlp_library'
INDIC_NLP_RESOURCES='../indic_nlp_resources'
from indicnlp import common
common.set_resources_path(INDIC_NLP_RESOURCES)
from indicnlp import loader
loader.load()

from indicnlp import *
from indicnlp.transliterate.unicode_transliterate import ItransTransliterator
from indicnlp.transliterate.unicode_transliterate import UnicodeIndicTransliterator


def convert_to_english(src_path,src_lang):
    tgt_path = src_path + ".translit"
    tgt_file = open(tgt_path, "w+")
    with open(src_path, "r") as src_file:
        for line in src_file.readlines():
            romanized = ItransTransliterator.to_itrans(line,src_lang)
            tgt_file.write(romanized)
    tgt_file.close()
    print("{} transliterated into {}".format(src_path,tgt_path))
    return None
    
def convert_to_scripts(src_path, src_lang, tgt_lang):
    tgt_path = src_path + ".transliterated.{}".format(tgt_lang)
    

    tgt_file = open(tgt_path, "w+")
    
    with open(src_path, "r") as src_file:
        for line in src_file.readlines():
            converted = UnicodeIndicTransliterator.transliterate(line,src_lang,tgt_lang)
            #converted = line
            tgt_file.write(converted)
    tgt_file.close()
    print("{} transliterated into {}".format(src_path,tgt_path))
    return None

def transliterate_ratio(src_path, ratio, lang, src_lang):
    tgt_path = src_path + ".ratio.{}".format(lang)
    

    tgt_file = open(tgt_path, "w+")

    with open(src_path, "r") as src_file:
        for line in src_file.readlines():
        
            conv = line.split()
            total = len(''.join(line.split()))
            total = ratio*total
            new = 0
            i = 0
            to_be_conv = []
            new_str = ''
            while new < total:
                word = conv[i]
                old = len(word)
                word = UnicodeIndicTransliterator.transliterate(word,src_lang,lang)
                new_str += word
                i += 1
                new += old
                new_str += ' '

            remaining = ' '.join(conv[i:])
            final = new_str + remaining
            tgt_file.write(final)
    tgt_file.close()
    return None

for lang in ['hi', 'ne']:
    for dset in ['test', 'train', 'dev']:
        src_path= "./data/"+ lang +"-en/"+ dset + "." + lang +"-en.final." + lang
        #convert_to_english(src_path, lang)
        #convert_to_scripts(src_path, lang, 'hi')
        transliterate_ratio(src_path, 0.3, 'gu',lang)

for lang in ['gu']:
    for dset in ['test', 'train', 'dev']:
        src_path= "./data/"+ lang +"-en/"+ dset + "." + lang +"-en.final." + lang
        #convert_to_english(src_path, lang)
        #convert_to_scripts(src_path, lang, 'hi')
        transliterate_ratio(src_path, 0.3,'hi','gu')



