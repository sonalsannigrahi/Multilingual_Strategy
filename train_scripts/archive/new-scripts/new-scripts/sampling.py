#!/usr/bin/python
import os, random, sys

def sample_n(n, total):
    n = round(n)
    sampled = sorted(random.choices(range(total), k=n)) # sample with replacement (allows for upsampling)
    i = 0
    last_line = None
    for j, num in enumerate(sampled):
        # same as previous, output last line
        if j > 0 and last_line != None and num == sampled[j-1]:
            print(last_line)
        else:
            # read all lines until i reaches num
            while i < num:
                last_line = sys.stdin.readline().strip()
                i += 1 # increment the line in the filex
            print(last_line)

        
def temperature_sampling_get_n(lang2number, temp=1.5):
    total = sum(lang2number.values()) # total numberof sentences
    lang2fraction = {}
    lang2sampled_number = {}
    # first calculate the number of sentences / total for each lang
    for lang in lang2number:
        q = lang2number[lang] / float(total)
        lang2fraction[lang] = q ** (1/temp)
    #os.sys.stderr.write(str(lang2fraction) + '\n')
    # then calculate the sampled number (using the temperature) for each lang
    for lang in lang2number:
        p = lang2fraction[lang]/ sum(lang2fraction.values())
        lang2sampled_number[lang] = p            

    # print out
    for lang in lang2sampled_number:
        print(lang + '\t' + str(lang2sampled_number[lang]))
