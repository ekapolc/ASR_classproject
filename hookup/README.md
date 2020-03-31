# Kaldi WebRTC Tutorial [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This part of the tutorial describes how to setup and use [kaldi-webrtc-server](https://github.com/danijel3/KaldiWebrtcServer). kaldi-webrtc-server is a wrapper on-top of a real-time speech recognition server based on Kaldi.

First, download danijel3's repository
```bash
git clone https://github.com/danijel3/KaldiWebrtcServer.git
```

This repository shows an example of how to plug Kaldi real-time recognizer into a website.


## Step 1 - Setting up the model
We will emphasize [the instruction of how to use your model in the main repository](https://github.com/danijel3/KaldiWebrtcServer/tree/master/docker#making-your-own-kaldimodel-image).

For simplicity, we will use the docker part.
```bash
cd docker
```

The final directory structure of danijel3 repository contains three parts,
* `kaldi` contains description of a Kaldi image which contains only decoding parts
* `web` A website plug with a real-time speech recognizer service
* `model` contains description of how to build image of 
   * `model` Our model will be listed here
      * `graph` You had generated this at `exp/chain/tree_a_sp/graph`   
         * HCLG.fst
         * words.txt
      * `model` This is an AM we provided you `exp/chain/tdnn1p_sp_online`    
         * final.mdl
         * tree
         * conf/
         * ivectror_extractor/

At first, we have to create folder `model/model/`.
```bash
mkdir -p model/model/graph && mkdir -p model/model/model
```
Then, you copy files mentioned above into the directory.

Paths inside `ivector_extractor.conf` and `online.conf`, in `model/conf/` directory, have to be corrected.
For example, `/kaldi/egs/librispeech/s5/exp/chain/tdnn1p_sp_online/ivector_extractor/final.ie` should be changed to `/model/model/ivector_extractor/final.ie`. Make sure everything paths point at the right location.

## Step 2 - Building model image

After finish step1, we go back to the upper folder.
```bash
cd ..
```
`Dockerfile` lists  decoding parameters

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

In this part you will need the client code to send requests. Get the client here [client.py](https://raw.githubusercontent.com/alumae/kaldi-gstreamer-server/master/kaldigstserver/client.py) (python2)

To run the client code you will need a couple python packages, including ws4py version 0.3.2. This can be done by using `pip install --user ws4py==0.3.2`. You may also need simplejson and pyaudio which can be also installed using pip.

Now try passing a wavefile to the server by a websocket.

```bash
python client.py -u ws://localhost:8080/client/ws/speech -r 32000 <testfile>.wav
```

where `-r` specifies the byte rate per second of the wavefile (or mp3). We use 16000 Hz sampling rate with 16 bits per sample, so the byte rate is 16/8*16000=32000.

This is how you hook-up any application to Kaldi running on a Server

There are other use cases, such as [a javascript client](http://kaljurand.github.io/dictate.js), or a HTTP-based API. This way you can send audio via a PUT or POST request to `http://server:port/client/dynamic/recognize` and read the JSON ouput. If you are interested, see [Tamel's repository](https://github.com/alumae/kaldi-gstreamer-server) for details.

Credits:

* Docker gstreamer repository https://github.com/jcsilva/docker-kaldi-gstreamer-server
