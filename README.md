# 实验二 文档倒排索引算法实现

使用Java编写Hadoop MapReduce程序，为10篇英文技术文档建立包含文档词频和总词频的倒排索引。

## 文件

- `src/InvertedIndex.java`：Mapper、Combiner、Reducer与作业入口。
- `corpus/`：从Apache Hadoop官网正文提取的10篇英文文档。
- `sources.json`：文档题目、公开网址、下载时间、字节数和SHA-256。
- `stopwords.txt`：停词表，每行一个单词。
- `fetch_corpus.py`：重新下载网页并提取正文，仅使用Python标准库。
- `build.sh`：使用Hadoop自带依赖编译并打包。
- `run.sh`：上传语料和停词表，提交MapReduce作业，下载并校验结果。
- `verify.py`：重新扫描全部本地文档，独立统计并逐项核对完整索引。

## 环境与运行

需要Linux、JDK 11、Hadoop 3.4.3以及Python 3。先启动HDFS和YARN，并把Hadoop的bin目录加入PATH。

```bash
python3 fetch_corpus.py
bash run.sh
```

仓库已包含下载后的语料，复现实验时可以直接运行`bash run.sh`。重新下载会以当时的网页正文更新语料与来源清单，应使用同一版本的语料核对结果。

每次运行使用独立的HDFS目录，输出保存在`results/`，不会覆盖之前的实验结果。

## 处理方法

统一转换为小写，以连续的英文字母`[a-z]+`作为单词，数字和标点均作为分隔符。删除停词表中的完整单词，不进行词干提取。所有输入文件使用唯一的文件名。

Mapper以单词为键、文档名和计数1为值。Combiner在每个Map任务内合并相同单词在同一文档中的计数。Reducer汇总每个文档的词频，按文档名排列，并在末尾追加总词频。停词表通过Hadoop分布式缓存传入每个Mapper。

输出格式：

```text
word<TAB><document01.txt,n1>;<document02.txt,n2>;<total,n1+n2>.
```

使用一个Reducer保证单个输出文件中的单词按字典序排列。每个单词只保留包含它的文档，词频使用64位整数。

## 文档来源

语料采用Apache Hadoop 3.4.3的英文官方文档：Single Node Setup、Cluster Setup、HDFS Architecture、HDFS User Guide、File System Shell、MapReduce Tutorial、YARN Architecture、Hadoop Streaming、Hadoop Archives和Hadoop DistCp。文件名依次为`document01.txt`至`document10.txt`。详细来源见`sources.json`。

Apache文档遵循其原有许可，见[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)。
