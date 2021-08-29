import time
#auxiliary functions for processing text files

#Requirements:

#A folder named data with different folders for the languages using ISO codes, functions will create different temp files in this directory




#Global Variables

alpha_ratio = 0.3

#reg_ex = {'en': [a-zA-Z0-9], 'fi': [a-zA-ZäåöšžÄÅÖŠŽ0-9], 'et': [a-zA-ZäõöšüžÄÕÖŠÜŽ0-9], 'hi':[\u0900-\u097F], 'ne':[\u0900-\u097F], 'gu': [\u0A80–\u0AFF]}

def file_combine(filesrc, filetgt, src, tgt, file_name=None):
    """
    given one text file with source data and target data in separate files,
    this function combines them into source \t target
    """
    if file_name:
        combined = open(file_name, "x")
    else:
        combined = open("data/{}/{}-{}.combine".format(src,src,tgt), "x")
        file_name ="data/{}/{}-{}.combine".format(src,src,tgt)
    i= 0
    try:
        f1 = open(filesrc, "r")
        f2 = open(filetgt, "r")
    except:
        raise ValueError('Could not open source and target files!')
    for sr, tg in zip(f1.readlines(), f2.readlines()):
        i+= 1
        sr = sr.replace("\n", " ")
        combined.write(sr)
        combined.write("\t")
        combined.write(tg)
    combined.close()
    print("Processed {} lines".format(i))
    return file_name
    
def file_split(file, src, tgt, file_name_src=None, file_name_tgt=None):
    """
    given one text file with source data and target data separated by tabs,
    this function splits them into source and target files
    """
    if file_name_src:
        source = open(file_name_src, "x")
        target = open(file_name_tgt, "x")
    else:
        source = open("data/{}/{}-{}.split.{}".format(src,src,tgt,src), "x")
        file_name_src = "data/{}/{}-{}.split.{}".format(src,src,tgt,src)
        target = open("data/{}/{}-{}.split.{}".format(src,src,tgt,tgt), "x")
        file_name_tgt = "data/{}/{}-{}.split.{}".format(src,src,tgt,tgt)
    i= 0
    with open(file, "r") as f:
        for line in f.readlines():
            i += 1
            sent = line.split("\t")
            source.write(sent[0])
            source.write("\n")
            target.write(sent[1])
    source.close()
    target.close()
    print("Processed {} lines".format(i))
    return file_name_src, file_name_tgt
    
def remove_equal(src, tgt, lang1, lang2, file_name_src=None, file_name_tgt=None):

    """
    Given source and target files, remove identical lines with more than 3 words
    This tries to take into account proper nouns that remain the same or phrases that are borrowed from english
    """
    if file_name_src:
        source = open(file_name_src, "x")
        target = open(file_name_tgt, "x")
    else:
        source = open("data/{}/{}-{}.clean.{}".format(lang1,lang1,lang2,lang1), "x")
        file_name_src = "data/{}/{}-{}.clean.{}".format(lang1,lang1,lang2,lang1)
        target = open("data/{}/{}-{}.clean.{}".format(lang1,lang1, lang2, lang2), "x")
        file_name_tgt ="data/{}/{}-{}.clean.{}".format(lang1,lang1, lang2, lang2)
    try:
        f1 = open(src, "r")
        f2 = open(tgt, "r")
    except:
        raise ValueError('Could not open source and target files!')
    i=0
    for sr, tg in zip(f1.readlines(), f2.readlines()):
        if sr==tg and len(sr)>3:
            i+= 1
            continue
        else:
            source.write(sr)
            target.write(tg)
            
    print("{} lines were removed from source and target files for being identical".format(i))
    source.close()
    target.close()
    return file_name_src, file_name_tgt
    
def remove_repeats(src, tgt, lang1, lang2, file_src=None, file_tgt=None):
    """
    Given source and target files, removes repeating source-target translations [deduplication]
    """
    if file_src:
        source = open(file_src, "x")
    elif file_src==None:
        source = open("data/{}-{}-complete.{}".format(lang1,lang2,lang1), "x")
        file_src = "data/{}-{}-complete.{}".format(lang1,lang2,lang1)
        
    if file_tgt:
        target = open(file_tgt, "x")
    elif file_tgt==None:
        target = open("data/{}-{}-complete.{}".format(lang1,lang2,lang2), "x")
        file_tgt = "data/{}-{}-complete.{}".format(lang1,lang2,lang2)
        
    try:
        f1 = open(src, "r")
        f2 = open(tgt, "r")
    except:
        raise ValueError('Could not open source and target files!')
    i=0
    seen_source = set()
    seen_target = set()
    for sr, tg in zip(f1.readlines(), f2.readlines()):
        if sr in seen_source and tg in seen_target:
            i+= 1
            continue
        else:
            source.write(sr)
            target.write(tg)
            seen_source.add(sr)
            seen_target.add(tg)
    
    print("{} repeated translations were removed from source and target files".format(i))
    source.close()
    target.close()
    return file_src, file_tgt
def remove_nonalpha(src, tgt, lang1, lang2):
    """
    Check if ratio of non-alpha characters to alpha characters is more than alpha ratio, if so then remove it!
    
    """
    source = open("{}-{}.{}".format(lang1,lang2,lang1), "x")
    target = open("{}-{}.{}".format(lang1,lang2,lang2), "x")
    try:
        f1 = open(src, "r")
        f2 = open(tgt, "r")
    except:
        raise ValueError('Could not open source and target files!')
        
    for sr, tg in zip(f1.readlines(), f2.readlines()):
        source_words = sr.strip.split(" ")
        target_words = tg.strip.split(" ")
 
 
def byte_encode(file, prefix=None):
    bfile = open("{}-byte-encoded".format(prefix), "x")
    with open(file, "r") as f:
        for line in f.readlines():
            arr = bytes(line, 'utf-8')
            #arr2 = bytes(string, 'ascii')
            for byte in arr:
                bfile.write(str(byte))
                bfile.write(" ")
            bfile.write("\n")
    
def complete_process(concat_file, src, tgt, file_prefix=None):
    if file_prefix:
        file_src = "./data-scrap/" + file_prefix + "_{}_split".format(src)
        file_tgt = "./data-scrap/" +file_prefix + "_{}_split".format(tgt)

        rm_src = "./data-scrap/"+file_prefix + "_{}_equal".format(src)
        rm_tgt =  "./data-scrap/"+file_prefix + "_{}_equal".format(tgt)
        
        rr_src = file_prefix + "_{}".format(src)
        rr_tgt =  file_prefix + "_{}".format(tgt)
        source, target = file_split(concat_file, src, tgt, file_src, file_tgt)
        source_re, target_re = remove_equal(source, target, src, tgt, rm_src, rm_tgt)
        source_rr, target_rr = remove_repeats(source_re, target_re, src, tgt, rr_src, rr_tgt)
    else:
        source, target = file_split(concat_file, src, tgt)

        source_re, target_re = remove_equal(source, target, src, tgt)
        source_rr, target_rr = remove_repeats(source_re, target_re, src, tgt)
    print("Cleaning suite complete!")
    
#TEST COMMANDS: complete cleaning suite works :)
#file_combine("./data/fi/paracrawl-clean.fi","./data/fi/paracrawl-clean.en","fi","en")

#start_time = time.time()
#file_split("./data/en-fi-concat", "fi", "en")
#remove_equal("./data/fi/fi-en.split.fi","./data/fi/fi-en.split.en" , "fi", "en")
#remove_repeats("./data/fi/fi-en.clean.fi","./data/fi/fi-en.clean.en" , "fi", "en")
#end_time = time.time()
#print("Entire cleaning took {} seconds".format(end_time - start_time))

#"./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.fi","./data/fi/paracrawl-release1.en-fi.zipporah0-dedup-clean.en","fi","en"

