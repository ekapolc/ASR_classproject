# Creating HCLG [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This part of the tutorial describes how to assemble HCLG fst from a lexicon file and a LM.arpa file.

For this part we will work in the LibriSpeech recipe.

```bash
cd /kaldi/egs/librispeech/s5/
```

First download the provided AM (`AM_chain.zip`) from the git repository. Copy it to `/kaldi/egs/librispeech/s5/` Then.

```bash
unzip AM_chain.zip
```

This is a neural network model trained on Gowajee corpus. To give you a sense of how good the AM is. This was trained on data from 2017, 2018, and 2019 ASR class groups and test on a not-in-train group. The WER is ~40%. You should aim for a smaller group of tasks so that the WER can be around 10-20%.

## Step 1 - Creating L and G fst

Download prepare_LG.sh from this git repository. To use it, do

```bash
./prepare_LG.sh <mylexicon.txt> <mylm.arpa> <exp/chain/tree_a_sp/phones.txt> <data/local/dict> <data/lang>
```

* `mylexicon.txt`
	* The lexicon you generated.
	* A pronunciation per line, `<word> <pronunciation>`
* `mylm.arpa`
	* The LM you generated using SRILM
	* Every word in the vocabulary must be in mylexicon.txt
* `exp/chain/tree_a_sp/phones.txt`
	* This file provides the setup of the trained AM we provided.
	* `phones.txt` lists all the phones the AM model supports.
	* All phones in mylexicon.txt must be in phones.txt
* Output : `data/local/dict`
	* Formatted lexicon.
* Output : `data/lang`
	* Directory containing `L.fst` and `G.fst`

If you get a permission denied error, try setting the permission using `chmod`

## Step 2 - Creating HCLG fst

Use the following command to construct HCLG in `exp/chain/tree_a_sp/graph`. H and C fst is already in `exp/chain/tree_a_sp/`

```bash
utils/mkgraph.sh \
  --self-loop-scale 1.0 data/lang \
  exp/chain/tree_a_sp exp/chain/tree_a_sp/graph
```

## Step 3 - Decoding

Construct a `data/test` and `data/dev` with your data. These two folders must have `wav.scp`, `utt2spk`, `spk2utt`, and `text`.

To run decoding on `data/dev` do,

```bash
steps/online/nnet3/decode.sh \          
  --acwt 1.0 --post-decode-acwt 10.0 --nj 4 \
  exp/chain/tree_a_sp/graph data/dev exp/chain/tdnn1g_sp_online/decode_dev
```

This will output results to `exp/chain/tdnn1r_sp_online/decode_dev`.
The `nj` flag splits the job into 4 parts, which can be executed in parallel. It must not exceed the number of speakers in the dev set. First let's look at the WER of our results

```bash
grep WER exp/chain/tdnn1r_sp_online/decode_dev/wer_*
```

This spits out the WER for each Language Model Weight (LMWT) and Word Insertion Penalty (WIP). For example, the file `wer_10_0.0` uses LMWT of 10 and WIP of 0. Note down which combination gives the best results. Depending on your language model, you might want to test more combinations. To do so add `--scoring-opts "--min-lmwt <min_weight> --max-lmwt <max_weight> --word_ins_penalty <list_of_penalty>"` when running `decode.sh`.

To look at individual outputs, try

```bash
utils/int2sym.pl -f 2- exp/chain/tree_a_sp/graph/words.txt \
   exp/chain/tdnn1r_sp_online/decode_dev/scoring/10.0.0.tra > answer.txt
```

`answer.txt` will have the best hypothesis at LMWT of 10 and WIP of 0. Are the answers reasonable? You might want to make your task simpler if the recognizer gives too many errors.
