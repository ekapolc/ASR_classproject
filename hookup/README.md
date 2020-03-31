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
cd KaldiWebrtcServer/docker
```

The final directory structure of danijel3 repository contains three parts,
* `kaldi` contains description of a Kaldi image which contains only decoding parts
* `web` A website plug with a real-time speech recognizer service
* `model` contains description of how to build image of 
   * `model` Our model will be listed here
      * `graph` You had generated this at `exp/chain/tree_a_sp/graph`
         * HCLG.fst
         * words.txt : This maps HCLG output symbols to words in the vocabulary
      * `model` This is an AM we provided you `exp/chain/tdnn1p_sp_online`
         * final.mdl
         * tree
         * conf/
         * ivectror_extractor/

At first, we have to create folder `model/model/`.
```bash
mkdir -p model/model/graph && mkdir -p model/model/model
```
Then, copy files mentioned above into the directory.

Paths inside `ivector_extractor.conf` and `online.conf`, in `model/conf/` directory, have to be corrected.
For example, `/kaldi/egs/librispeech/s5/exp/chain/tdnn1p_sp_online/ivector_extractor/final.ie` should be changed to `/model/model/ivector_extractor/final.ie`. Make sure everything paths point at the right location.

## Step 2 - Building model image

After finish step1, go inside model folder
```bash
cd model
```
`Dockerfile` lists decoding parameters. Some interesting are explained below,
* `min-active` : minimum active nodes in beam search. Effects run-time performance.
* `max-active` : maximum active nodes in beam search. Effects run-time performance.
* `beam` : Beam size for pruning in beam search.
* `acoustic-scale` : Acoustic Model Weight. This should corresponds to the configuration that gives the best WER. For example, if LMWT = 11 gives the best WER for your HCLG on your dev set, use AMWT = (1/11) \* 10 = 0.9091.

#### Attention!!!
An AM we provided you, has a special model structure.
To make it run correctly, you have to add `"--frame-subsampling-factor=3"` inside the ENTRYPOINT list. Put it somewhere before `port-num`. The following command will do this for you,
```bash
cp  Dockerfile  Dockerfile.tmp
sed 's/"--port-num/"--frame-subsampling-factor=3","--port-num/' Dockerfile.tmp > Dockerfile
rm Dockerfile.tmp
```

After you finish the configurations, try to build an image
```bash
docker build -t mymodel .
```

## Step 3 - Sending decoding requests
You can test by 
1. run the image individually and nc (netcat) the raw wav file inside it.
```bash
docker run --rm -p 5050:5050 mymodel
```
Open a new terminal and run `sox example_audio.wav -t raw - | nc localhost 5050`. For simplicity, you can also test with `nc localhost 5050 < example_audio.wav` but I'm not guarantee will it works.

If you do this way, closing a terminal will not stop the running server. To stop it, you can run `docker stop <CONTAINER ID>`.
You can found `CONTAINER ID` from runnning `docker ps`.


2. run the website and use an audio recoder there.
```bash
cd ..
cp  docker-compose.yml  docker-compose.yml.tmp
sed 's/\danijel3\/kaldi-online-tcp:aspire/mymodel/' docker-compose.yml.tmp > docker-compose.yml
rm docker-compose.yml.tmp
docker-compose up -d
```

The web is available at `localhost:8080`. 
Once it's running, you can run `docker-compose logs -f` to monitor the logs of the running servers.
At any time you can run `docker-compose stop` to temporarily shutdown and `docker-compose start` to restart the service. Finally, you can run `docker-compose down` to stop and remove the containers altogether.

If you change anythings, you have to remove model server, rebuild the image, and start a new one. Your change won't make any effects if you not rebuild the image.

Credits:

* Docker KaldiWebRTC repository https://github.com/danijel3/KaldiWebrtcServer
