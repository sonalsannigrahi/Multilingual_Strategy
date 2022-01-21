
#!/bin/sh
#  preprocess.sh
#
#
#  Created by Sonal Sannigrahi on 21/01/2022.
#
from indicnlp import *
from indicnlp.transliterate.unicode_transliterate import ItransTransliterator
from indicnlp.transliterate.unicode_transliterate import UnicodeIndicTransliterator


def convert_to_english(src_path,src_lang):
    tgt_path = src_path + ".transliterated.en"
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
            tgt_file.write(converted)
    tgt_file.close()
    print("{} transliterated into {}".format(src_path,tgt_path))
    return None
