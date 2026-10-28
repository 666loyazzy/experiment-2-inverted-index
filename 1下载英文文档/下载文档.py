import datetime
import hashlib
import html.parser
import json
import pathlib
import re
import urllib.request

BASE = 'https://hadoop.apache.org/docs/r3.4.3/'
PAGES = [
    ('Single Node Setup', 'hadoop-project-dist/hadoop-common/SingleCluster.html'),
    ('Cluster Setup', 'hadoop-project-dist/hadoop-common/ClusterSetup.html'),
    ('HDFS Architecture', 'hadoop-project-dist/hadoop-hdfs/HdfsDesign.html'),
    ('HDFS User Guide', 'hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html'),
    ('File System Shell', 'hadoop-project-dist/hadoop-common/FileSystemShell.html'),
    ('MapReduce Tutorial', 'hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html'),
    ('YARN Architecture', 'hadoop-yarn/hadoop-yarn-site/YARN.html'),
    ('Hadoop Streaming', 'hadoop-streaming/HadoopStreaming.html'),
    ('Hadoop Archives', 'hadoop-archives/HadoopArchives.html'),
    ('Hadoop DistCp', 'hadoop-distcp/DistCp.html'),
]

class ContentParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.parts = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            if self.depth:
                self.depth += 1
            elif dict(attrs).get('id') == 'contentBox':
                self.depth = 1
        if self.depth:
            if tag in ('script', 'style'):
                self.skip += 1
            if tag in ('p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'pre', 'tr', 'br'):
                self.parts.append('\n')

    def handle_endtag(self, tag):
        if self.depth:
            if tag in ('script', 'style'):
                self.skip -= 1
            if tag in ('p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'pre', 'tr'):
                self.parts.append('\n')
            if tag == 'div':
                self.depth -= 1

    def handle_data(self, data):
        if self.depth and not self.skip:
            self.parts.append(data)

root = pathlib.Path(__file__).resolve().parent
destination = root / 'corpus'
destination.mkdir(exist_ok=True)
manifest = []
for number, (title, path) in enumerate(PAGES, 1):
    url = BASE + path
    request = urllib.request.Request(url, headers={'User-Agent': 'Hadoop-Inverted-Index-Lab/1.0'})
    with urllib.request.urlopen(request, timeout=60) as response:
        raw = response.read()
    parser = ContentParser()
    parser.feed(raw.decode('utf-8'))
    lines = [re.sub(r'\s+', ' ', line).strip() for line in ''.join(parser.parts).splitlines()]
    text = '\n'.join(line for line in lines if line) + '\n'
    assert len(re.findall('[A-Za-z]+', text)) >= 100, url
    name = f'document{number:02d}.txt'
    data = text.encode('utf-8')
    (destination / name).write_bytes(data)
    manifest.append({'document': name, 'title': title, 'url': url, 'bytes': len(data),
                     'downloaded_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                     'sha256': hashlib.sha256(data).hexdigest(),
                     'html_sha256': hashlib.sha256(raw).hexdigest()})
    print(name, title, len(data), flush=True)
(root / '文档来源.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
