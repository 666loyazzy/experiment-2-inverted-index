import collections
import json
import pathlib
import re
import sys

documents = sorted(pathlib.Path(sys.argv[1]).glob('document*.txt'))
stopwords = set(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8').split())
expected = collections.defaultdict(dict)
token_count = 0
removed = 0
per_document = []
for document in documents:
    tokens = re.findall(r'[a-z]+', document.read_text(encoding='utf-8').lower())
    counts = collections.Counter(token for token in tokens if token not in stopwords)
    token_count += len(tokens)
    removed += len(tokens) - sum(counts.values())
    per_document.append({'document': document.name, 'bytes': document.stat().st_size,
                         'tokens': len(tokens), 'indexed': sum(counts.values()), 'vocabulary': len(counts)})
    for word, count in counts.items():
        expected[word][document.name] = count

actual = {}
for line in pathlib.Path(sys.argv[3]).read_text(encoding='utf-8').splitlines():
    word, postings = line.split('\t', 1)
    assert re.fullmatch(r'[a-z]+', word) and word not in actual, line
    assert re.fullmatch(r'(?:<document[0-9]+\.txt,[1-9][0-9]*>;)+<total,[1-9][0-9]*>\.', postings), line
    pairs = re.findall(r'<([^,]+),([0-9]+)>', postings)
    entries, total = pairs[:-1], int(pairs[-1][1])
    names = [name for name, _ in entries]
    assert names == sorted(set(names)), line
    counts = {name: int(count) for name, count in entries}
    assert sum(counts.values()) == total, line
    actual[word] = counts
assert list(actual) == sorted(actual), 'Words are not sorted'
assert dict(expected) == actual, 'Index differs from independent document counts'
indexed = sum(sum(counts.values()) for counts in actual.values())
assert indexed + removed == token_count
summary = {'passed': True, 'documents': len(documents), 'stopwords': len(stopwords),
           'tokens': token_count, 'removed': removed, 'indexed': indexed,
           'vocabulary': len(actual), 'postings': sum(map(len, actual.values())),
           'per_document': per_document}
print(json.dumps(summary, indent=2))
