import sys

def quote(s):
    return '"' + s + '"'

def quotes(array, indexes):
    for i in indexes:
        array[i] = quote(array[i])
    return array

def transform(indexes):
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        print ','.join(quotes(line.split('|')[:-1], indexes))
