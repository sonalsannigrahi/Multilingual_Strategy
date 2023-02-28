#!/usr/bin/python
import sys, re

def byte_encode():
    for line in sys.stdin:
        encoded = ' '.join(map(str, list(bytes(line.strip().strip(), 'utf-8'))))
        print(encoded)

def byte_decode():
    for line in sys.stdin:
        decoded = bytes(map(int, line.strip().split(' '))).decode('utf-8')
        print(decoded)

def char_encode():
    for line in sys.stdin:
        chars = [char for char in re.sub(' +', '▁', line.strip())]
        print(' '.join(chars))

def sp_encode():
    1


def sp_encode():
    1


def sp_decode():
   1
