# Kaldi Gstreamer Tutorial [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This part of the tutorial describes how setup and use [kaldi-gstreamer-server](https://github.com/alumae/kaldi-gstreamer-server). kaldi-gstreamer is a real-time speech recognition server based on Kaldi.

First, download the image for the server (~900 MB)

```bash
docker pull jcsilva/docker-kaldi-gstreamer-server
```

This image contains the minimum things to run the recognition server. It only contains some parts of Kaldi.

## Step 1 - Setting up the server

The instance can launch multiple recognition workers. Each worker can be configured to use the Kaldi model of your choice. An example configuration file is provided.

Open `sample_nnet2.yaml`

In there you will see several paramters, here are some parts of interest

* Model location part
    * `word-syms` : Path to `words.txt` in your graph directory. This maps HCLG output symbols to words in the vocabulary.
    * `fst` : Path to the `HCLG.fst` in your graph directory that you generated.
    * `mfcc-config` : Path to `mfcc.conf` under the `conf` directory in your Kaldi model.
    * `ivector-extraction-config` : Path to `ivector_extractor.conf` under the `conf` directory in your Kaldi model.
* Decoding paramters part
    * `max-active` : maximum active nodes in beam search. Effects run-time performance.
    * `beam` : Beam size for pruning in beam search.
    * `acoustic-scale` : Acoustic Model Weight. This should corresponds to the configuration that gives the best WER. For example, if LMWT = 11 gives the best WER for your HCLG on your dev set, use AMWT = 1/11 = 0.09091
    * `num-nbest` : number of outputs n-best you want as the recognition output. Recall that the recognizer can output not just the best hypothesis but the top n best hypothesis.

Put `sample_nnet2.yaml` and the ASR models (`HCLG.fst` and `words.txt` you generated and the AM provided in the previous tutorial) into a `model` folder. We will mount it to the recognition server instance.

```bash
docker run -it -p 8080:80 -v <path_to_model>:/opt/models jcsilva/docker-kaldi-gstreamer-server:latest /bin/bash
```

The option `-p` publish the ports to the host machine running the instance. So the host can talk to the machine via that port. This is how we will ask the recognition server to give us ASR outputs.

Edit `sample_nnet2.yaml` to points to the correct files. Also edit `ivector_extractor.conf` so that it points to the correct files in the recognition server.

Now we can finally start the server,

```bash
/opt/start.sh -y /opt/models/sample_nnet2.yaml
```

Check if the process starts successfully by looking at the log file at `/opt/worker.log` see it starts sucessfully. Usually it will fails if you put the wrong paths to some files.

## Step 2 - Sending decoding requests

In this part you will need the client code to send requests. Get the client here [client.py](https://raw.githubusercontent.com/alumae/kaldi-gstreamer-server/master/kaldigstserver/client.py)

To run the client code you will need a couple python packages, including ws4py version 0.3.2. This can be done by using `pip install --user ws4py==0.3.2`. You may also need simplejson and pyaudio which can be also installed using pip.

Now try passing a wavefile to the server.

```bash
python client.py -u ws://localhost:8080/client/ws/speech -r 32000 <testfile>.wav
```

where `-r` specifies the byte rate per second of the wavefile (or mp3). We use 16000 Hz sampling rate with 16 bits per sample, so the byte rate is 16/8*16000=32000.

This is how you hook-up any application to Kaldi running on a Server

There are other use cases. If you are interested, see

Tamel's repository at https://github.com/alumae/kaldi-gstreamer-server for details.

Other links:

* Docker gstreamer repository https://github.com/jcsilva/docker-kaldi-gstreamer-server
