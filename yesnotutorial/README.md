# yesnodocker tutorial [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This tutorial is edited from https://github.com/keighrim/kaldi-yesno-tutorial/blob/master/README.md

This tutorial will guide you some basic functionalities and operations of [Kaldi](http://kaldi-asr.org/) ASR toolkit.

First of all, run a Kaldi docker image  
```
docker run -it -v <path_to_backup_folder>:/data burin010n/kaldi /bin/bash
```
By running this command, path_to_backup_folder in the host machine will be mounted to /data in the docker container.
First time will take a long time because you have to pull the image (2.77 GB) from DockerHub. After extraction, the image will has size 12.4 GB.


You can go the the recipe in Kaldi by

```bash
cd /kaldi/egs/yesno/s5/
```

## Step 1 - Data preparation

This section will cover how to prepare data formats to train and test Kaldi recognizer.

### Data description

First download the data by

```bash
wget http://www.openslr.org/resources/1/waves_yesno.tar.gz
tar -xvzf waves_yesno.tar.gz
rm waves_yesno/README*
```

Our dataset for this tutorial has 60 `.wav` files, sampled at 8 kHz.
All audio files are recorded by an anonymous male contributor of the Kaldi project and included in the project for a test purpose. 

In each file, the individual says 8 words; each word is either *"ken"* or *"lo"* (*"yes"* and *"no"* in Hebrew), so each file is a random sequence of 8 yes's or no's.
The names of files represent the word sequence, with 1 for *yes* and 0 for *no*.

```bash
waves_yesno/1_0_1_1_1_0_1_0.wav
waves_yesno/0_1_1_0_0_1_1_0.wav
...
```
This is all we have as our raw data. Now we will deform these `.wav` files into data format that Kaldi can read in.


### Data preparation

Let's start with formatting data. We will split 60 wave files roughly in half: 31 for training, the rest for testing. Create a directory `data` and,then two subdirectories `train_yesno` and `test_yesno` in it. 

We will prototype a python script to generate necessary input files. Open `local/prepare_data.sh`. It 

1. reads up the list of files in `waves_yesno`.
1. generates two list, one stores names of files that start with 0's, the other keeps names starting with 1's, ignore the rest of files.

Now, for each dataset (train, test), we need to generate these files representing our raw data - the audio and the transcripts.

* `text`
    * Essentially, transcripts.
    * An utterance per line, `<utt_id> <transcript>` 
        * e.g. `0_0_1_1_1_1_0_0 NO NO YES YES YES YES NO NO`
    * We will use filenames without extensions as utt_ids for now.
    * Although recordings are in Hebrew, we will use English words, YES and NO, to avoid complicating the problem.
* `wav.scp`
    * Indexing files to unique ids. 
    * `<file_id> <wave filename with path OR command to get wave file>`
        * e.g. `0_1_0_0_1_0_1_1 waves_yesno/0_1_0_0_1_0_1_1.wav`
    * Again, we can use file names as file_ids.
* `utt2spk`
    * For each utterance, mark which speaker spoke it.
    * `<utt_id> <speaker_id>`
        * e.g. `0_0_1_0_1_0_1_1 global`
    * Since we have only one speaker in this example, let's use "global" as speaker_id
* `spk2utt`
    * Simply inverse indexed `utt2spk` (`<speaker_id> <all_hier_utterences>`)
    * Can use a Kaldi utility to generate
    * `utils/utt2spk_to_spk2utt.pl data/train_yesno/utt2spk > data/train_yesno/spk2utt`
* (optional) `segments`: *not used for this data.*
    * Contains utterance segmentation/alignment information for each recording. 
    * Only required when a file contains multiple utterances, which is not this case.
* (optional) `reco2file_and_channel`: *not used for this data. *
    * Only required when audios were recorded in dual channels for conversational setup.
* (optional) `spk2gender`: not used for this data. 
    * Map from speakers to their gender information. 
    * Used in vocal tract length normalization. 

To call the script do
```bash
local/prepare_data.sh waves_yesno
```

Run to generate each set of 4 files for the training and test set (`data/train_yesno`, `data/test_yesno`).

Kaldi has a scrip that clean up any possible errors in the data. Run

```bash
utils/fix_data_dir.sh data/train_yesno/
utils/fix_data_dir.sh data/test_yesno/
```


If you're done with the code, your data directory should look like this, at this point. 
```
data
├───train_yesno
│   ├───text
│   ├───utt2spk
│   ├───spk2utt
│   └───wav.scp
└───test_yesno
    ├───text
    ├───utt2spk
    ├───spk2utt
    └───wav.scp
```
## Step 2 - Dictionary preparation

This section will cover how to build language knowledge - lexicon and phone dictionaries - for Kaldi recognizer.

### Before moving on

From here, we will use several Kaldi utilities (included in `steps` and `utils` directories) to process further. To do that, Kaldi binaries should be in your `$PATH`. 
However, Kaldi is a huge framework, and there are so many binaries distributed over many different directories, depending on their purpose. 
So, we will use a script, `path.sh` to add all of them to `$PATH` of the subshell every time a script runs (we will see this later).
All you need to do right now is to open the `path.sh` file and edit the `$KALDI_ROOT` variable to point your Kaldi Installation location. 

### Defining blocks of the toy language: Lexicon

Next we will build dictionaries. Let's start with creating intermediate `dict` directory at the root.

```bash
mkdir -p data/local/dict
```

In this toy language, we have only two words: YES and NO. For the sake of simplicity, we will just assume they are one-phone words: Y and N.

```bash
echo -e "Y\nN" > data/local/dict/phones.txt            # phones dictionary
echo -e "YES Y\nNO N" > data/local/dict/lexicon.txt    # word-pronunciation dictionary
```

However, in real speech, there are not only human sounds that contributes to a linguistic expression, but also silence and noises. 
Kaldi calls all those non-linguistic sounds "*silence*".
For example, even in this small, controlled recordings, we have pauses between each word. 
Thus we need an additional phone "SIL" representing silence. And it can be happening at end of of all words. Kaldi calls this kind of silence "*optional*".

```bash
echo "SIL" > data/local/dict/silence_phones.txt
echo "SIL" > data/local/dict/optional_silence.txt
mv data/local/dict/phones.txt data/local/dict/nonsilence_phones.txt
```

Now amend lexicon to include the silence as well.

```bash
cp data/local/dict/lexicon.txt data/local/dict/lexicon_words.txt
echo "<SIL> SIL" >> data/local/dict/lexicon.txt 
```
**Note** that "\<SIL\>" will also be used as our OOV token later.

Your `dict` directory should end up with these 5 files:

* `lexicon.txt`: full list of lexeme-phone pairs
* `lexicon_words.txt`: list of word-phone pairs
* `silence_phones.txt`: list of silent phones
* `nonsilence_phones.txt`: list of non-silent phones
* `optional_silence.txt`: list of optional silent phones (here, this looks the same as `silence_phones.txt`)

Finally, we need to convert our dictionaries into a data structure that Kaldi would accept - finite state transducer (FST). Among many scripts Kaldi provides, we will use `utils/prepare_lang.sh` to generate FST-ready data formats to represent our language definition.

```bash
utils/prepare_lang.sh --position-dependent-phones false <RAW_DICT_PATH> <OOV> <TEMP_DIR> <OUTPUT_DIR>
```
We're using `--position-dependent-phones` flag to be false in our tiny, tiny toy language. There's not enough context, anyways. For required parameters we will use: 

* `<RAW_DICT_PATH>`: `data/local/dict`
* `<OOV>`: `"<SIL>"`
* `<TEMP_DIR>`: Could be anywhere. I'll just put a new directory `tmp` inside `dict`.
* `<OUTPUT_DIR>`: This output will be used in further training. Set it to `data/lang`.


### Defining sequence of the blocks: Language model

We are given a sample uni-gram language model for the yesno data. 
You'll find a `arpa` formatted language model inside `data/local` directory. 
However, again, the language model also needs to be converted into a FST.
For that, Kaldi also comes with a number of programs.
In this example, we will use the script, `local/prepare_lm.sh`.
It will generate properly formatted LM FST and put it in `data/lang_test_tg`.

## Step 3 - Feature extraction and training

This section will cover how to perform MFCC feature extraction and GMM modeling.

### Feature extraction

Once we have all data ready, it's time to extract features for GMM training.

First extract mel-frequency cepstral coefficients.

```bash
steps/make_mfcc.sh --nj <N> <INPUT_DIR> <LOG_DIR> <OUTPUT_DIR> 
```

* `--nj <N>` : number of processors, defaults to 4. Kaldi splits the processes by speaker information. Therefore, `nj` must be lesser than or equal to the number of speakers in `<INPUT_DIR>`. For this simple tutorial which has 1 speaker, `nj` must be 1.
* `<INPUT_DIR>` : where we put our 'data' of training set
* `<LOG_DIR>` : directory to dumb log files. Let's put output to `exp/make_mfcc/train_yesno`, following Kaldi recipes convention
* `<OUTPUT_DIR>` : Directory to put the features. The convention uses `mfcc/train`

Now normalize cepstral features using Cepstral Mean Normalization just like we did in our previous homework. This step also does an extra variance normalization. Thus, the process is called Cepstral Mean and Variance Normalization (CMVN).

```bash
steps/compute_cmvn_stats.sh <INPUT_DIR> <LOG_DIR> <OUTPUT_DIR>
```
`<INPUT_DIR>`, `<LOG_DIR>`, and `<OUTPUT_DIR>` are the same as above.

The two scripts will create `wav.scp` and `cmvn.scp` which specifies where the computed MFCC and CMVN are. `wav.scp` and `cmvn.scp` are just text files with just `<utt_id> <path_to_data>` for each line. With this setup, by passing the `data/train` directory to a Kaldi script, you are passing various information, such as the transcription, the location of the wav file, or the MFCC features.

**Note** that these shell scripts (`.sh`) are all pipelines through Kaldi binaries with trivial text processing on the fly. To see which commands were actually executed, see log files in `<LOG_DIR>`. Or even better, see inside the scripts. For details on specific Kaldi commands, refer to [the official documentation](http://kaldi-asr.org/doc/tools.html).

### Monophone model training

We will train a monophone model, since we assume that, in our toy language, phones are not context-dependent. 
(which is, of course, an absurd assumption)

```bash 
steps/train_mono.sh --nj <N> --cmd <MAIN_CMD> --totgauss 400 <DATA_DIR> <LANG_DIR> <OUTPUT_DIR>
```
* `--cmd <MAIN_CMD>`: To use local machine resources, use `"utils/run.pl"` pipeline.
* `--totgauss : limits the number of gaussian mixtures to 400
* `--nj <N>`: Utterances from a speaker cannot be processed in parallel. Since we have only one, we must use 1 job only. 
* `<DATA_DIR>`: Path to our training 'data'
* `<LANG_DIR>`: Path to language definition (output of the `prepare_lang` script)
* `<OUTPUT_DIR>`: like the previous, use `exp/mono`.

When you run the command, you will notice it doing EM. Each iteration does an alignment stage and an update stage. 

This will generate FST-based lattice for acoustic model. Kaldi provides a tool to see inside the model (which may not make any sense now).

```bash
/path/to/kaldi/src/fstbin/fstcopy 'ark:gunzip -c exp/mono/fsts.1.gz|' ark,t:- | head -n 20
```
This will print out first 20 lines of the lattice in human-readable(!!) format (Each column indicates: Q-from, Q-to, S-in, S-out, Cost)

## Step 4 - Decoding and testing

This section will cover decoding of the model we trained.

### Graph decoding

Now we're done with acoustic model training. 
For decoding, we need a new input that goes over our lattices of AM & LM. 
In step 1, we prepared separate testset in `data/test_yesno` for this purpose. 
Now it's time to project it into the feature space as well.
Use `steps/make_mfcc.sh` and `steps/compute_cmvn_stats.sh` .

Then, we need to build a fully connected FST (HCLG) network. 

```bash
utils/mkgraph.sh --mono data/lang_test_tg exp/mono exp/mono/graph_tgpr
```
This will build a connected HCLG in `exp/mono/graph_tgpr` directory. 

Finally, we need to find the best paths for utterances in the test set, using decode script. Look inside the decode script, figure out what to give as its parameter, and run it. Write the decoding results in `exp/mono/decode_test_yesno`.

```bash 
steps/decode.sh 
```

This will end up with `lat.N.gz` files in the output directory, where N goes from 1 up to the number of jobs you used (which must be 1 for this task). These files contain lattices from utterances that were processed by N’th thread of your decoding operation.


### Looking at results

If you look inside the decoding script, it ends with calling the scoring script (`local/score.sh`), which generates hypotheses and computes word error rate of the testset 
See `exp/mono/decode_test_yesno/wer_X` files to look the WER's, and `exp/mono/decode_test_yesno/scoring/X.tra` files for transcripts. 
`X` here indicates language model weight, *LMWT*, that scoring script used at each iteration to interpret the best paths for utterances in `lat.N.gz` files into word sequences. (Remember `N` is #thread during decoing operartion)
You can deliberately specify the weight using `--min_lmwt` and `--max_lmwt` options when `score.sh` is called, if you want. 
(See lecture slides on decoding to refresh what LMWT is, if you are not sure)

Or if you are interested in getting word-level alignment information for each reocoding file, take a look at `steps/get_ctm.sh` script.

