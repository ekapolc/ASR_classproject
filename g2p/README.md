# Sequitur G2P tutorial [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This part of the tutorial describes how to train and use [Sequitur](https://www-i6.informatik.rwth-aachen.de/web/Software/g2p.html). Sequitur is already installed in your Kaldi docker image.

First add Sequitur commands (g2p.py) into your `$PATH` by

```bash
cd /kaldi/egs/wsj/s5/
source ./path.sh
```

## Step 1 - Training

Sequitur accepts the training data in a very simple format. One line for each pronunciation. Each line starts with a word followed by phonemes separated by spaces. We provide the file dic5k.formatted.txt as your training lexicon. The lexicon is modified from the lexicon provided in NECTEC's [Lotus Corpus](https://www.nectec.or.th/corpus/index.php?league=sa)

To train do
```bash
g2p.py --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-1
```

This trains a simple G2P model `model-1`. Looking at the logs output to STDOUT you can notice it reporting LL (the log likelihood or probability) of each iteration. As stated in class, Sequitur models are trained using Expectation Maiximization. Each iteration does an E-step which aligns the graphonemes. Then the M-step re-estimates the parameters. The `--devel 5%` flag tells the g2p to use 5% of the training data as development to minitor the performance of each iteration.

`model-1` is actually a very simple G2P model (unigram). Sequitur trains models in stages where the model gets increasingly more and more complex (higher order n-gram). To do this we repeat the process by using the `--ramp-up` flag.

```bash
g2p.py --model model-1 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-2
g2p.py --model model-2 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-3
g2p.py --model model-3 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-4
g2p.py --model model-4 --ramp-up --train dic5k.formatted.txt --devel 5% --encoding UTF-8 --write-model model-5
```

Let's test the performance of the g2p by seeing how it does on the training data

```bash
g2p.py --model model-5 --encoding UTF-8 --test dic5k.formatted.txt
```

This will report two types of error. The string error is the percentage of incorrect pronunciations. The symbol error is the percentage of incorrect phonemes. Using ASR as a metaphore, you can think of symbol error as the WER, while the string error is the sentence error rate.

From the report, you should see that the model has less than 1% error for both types.

### Using the G2P

To use the G2P do

```bash
g2p.py --model model-5 --encoding UTF-8 --apply testlex.txt > g2plex.txt
```

This will generate the most likely pronunciation for each word. To generate more than 1 pronunciations, do

```bash
g2p.py --model model-5 --encoding UTF-8 --apply testlex.txt --variants-number 3 > g2plex.txt
```

### Using in the project

Edit the G2P output manually so that the pronunciations are correct. The file should be in the format of 
``
<word1> <pronunciation1>
<word2> <pronunciation2>
``
