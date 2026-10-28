import java.io.BufferedReader;
import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.input.FileSplit;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class InvertedIndex {
    public enum Count { TOKENS, STOPWORDS, INDEXED }

    public static class IndexMapper extends Mapper<LongWritable, Text, Text, Text> {
        private static final Pattern WORD = Pattern.compile("[a-z]+");
        private final Set<String> stopwords = new HashSet<>();
        private final Text word = new Text();
        private Text posting;

        @Override
        protected void setup(Context context) throws IOException {
            try (BufferedReader reader = Files.newBufferedReader(Paths.get("stopwords.txt"), StandardCharsets.UTF_8)) {
                String line;
                while ((line = reader.readLine()) != null) {
                    String value = line.trim().toLowerCase(Locale.ROOT);
                    if (!value.isEmpty()) stopwords.add(value);
                }
            }
            String document = ((FileSplit) context.getInputSplit()).getPath().getName();
            posting = new Text(document + "\t1");
        }

        @Override
        protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
            Matcher matcher = WORD.matcher(value.toString().toLowerCase(Locale.ROOT));
            while (matcher.find()) {
                String token = matcher.group();
                context.getCounter(Count.TOKENS).increment(1);
                if (stopwords.contains(token)) {
                    context.getCounter(Count.STOPWORDS).increment(1);
                } else {
                    context.getCounter(Count.INDEXED).increment(1);
                    word.set(token);
                    context.write(word, posting);
                }
            }
        }
    }

    private static TreeMap<String, Long> countDocuments(Iterable<Text> values) {
        TreeMap<String, Long> counts = new TreeMap<>();
        for (Text value : values) {
            String entry = value.toString();
            int separator = entry.lastIndexOf('\t');
            if (separator <= 0) throw new IllegalArgumentException("Invalid posting: " + entry);
            String document = entry.substring(0, separator);
            long count = Long.parseLong(entry.substring(separator + 1));
            if (count <= 0) throw new IllegalArgumentException("Nonpositive count");
            counts.merge(document, count, Math::addExact);
        }
        return counts;
    }

    public static class CountCombiner extends Reducer<Text, Text, Text, Text> {
        private final Text posting = new Text();

        @Override
        protected void reduce(Text word, Iterable<Text> values, Context context) throws IOException, InterruptedException {
            for (Map.Entry<String, Long> entry : countDocuments(values).entrySet()) {
                posting.set(entry.getKey() + "\t" + entry.getValue());
                context.write(word, posting);
            }
        }
    }

    public static class IndexReducer extends Reducer<Text, Text, Text, Text> {
        private final Text result = new Text();

        @Override
        protected void reduce(Text word, Iterable<Text> values, Context context) throws IOException, InterruptedException {
            StringBuilder postings = new StringBuilder();
            long total = 0;
            for (Map.Entry<String, Long> entry : countDocuments(values).entrySet()) {
                postings.append('<').append(entry.getKey()).append(',').append(entry.getValue()).append(">;");
                total = Math.addExact(total, entry.getValue());
            }
            result.set(postings.append("<total,").append(total).append(">.").toString());
            context.write(word, result);
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            System.err.println("Usage: InvertedIndex <input> <output> <stopwords>");
            System.exit(2);
        }
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "Document inverted index");
        job.setJarByClass(InvertedIndex.class);
        job.setMapperClass(IndexMapper.class);
        job.setCombinerClass(CountCombiner.class);
        job.setReducerClass(IndexReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        job.setNumReduceTasks(1);
        Path stops = new Path(args[2]);
        String location = stops.getFileSystem(conf).makeQualified(stops).toUri().toString();
        job.addCacheFile(new URI(location + "#stopwords.txt"));
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
