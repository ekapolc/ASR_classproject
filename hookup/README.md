# Kaldi WebRTC Tutorial [![Apache2](http://img.shields.io/badge/license-APACHE2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)

This part of the tutorial describes how to setup and use [kaldi-webrtc-server](https://github.com/danijel3/KaldiWebrtcServer). kaldi-webrtc-server is a wrapper on-top of a real-time speech recognition server based on Kaldi.

First, download danijel3's repository
```bash
git clone https://github.com/danijel3/KaldiWebrtcServer.git
```

This repository shows an example of how to plug Kaldi real-time recognizer into a website.


## Step 1 - Setting up the model
This follows the steps in [denijel3's website](https://github.com/danijel3/KaldiWebrtcServer/tree/master/docker#making-your-own-kaldimodel-image) which uses docker.

In the KaldiWebrtcServer repository go to the docker folder
```bash
cd KaldiWebrtcServer/docker
```

The directory structure of `KaldiWebrtcServer/docker` contains three folders,
* `kaldi` contains the description of a Kaldi image which contains only the decoding executables
* `web` a docker containing a webserver that will interact with the kaldi decoding image
* `model` should the asr model (which we have to build) that the Kaldi image will use

Inside the `model` directory, you need to create **another** folder `model` which includes (you will need to provide this):
* `graph` a folder containing the FST. You had generated this at `exp/chain/tree_a_sp/graph` in the previous [tutorial](../scripts)
  * HCLG.fst
  * words.txt : This maps HCLG output symbols to words in the vocabulary
* `model` a folder contaning the AM. This is the AM we provided you `exp/chain/tdnn1p_sp_online`
  * final.mdl
  * tree
  * conf/
  * ivectror_extractor/

Paths inside `ivector_extractor.conf` and `online.conf`, in `model/conf/` directory have to be corrected.
For example, `/kaldi/egs/librispeech/s5/exp/chain/tdnn1p_sp_online/ivector_extractor/final.ie` should be changed to `/model/model/ivector_extractor/final.ie`. Make sure every path points to the right location.

## Step 2 - Building the model image

After finishing step 1, go inside the model folder
```bash
cd KaldiWebrtcServer/docker/model
```
The `Dockerfile` lists decoding parameters. You should take note of the ones below:
* `samp-freq` : sampling frequency. The AM we provided were traind on 16kHz. This should be set to 16000.
* `min-active` : minimum active nodes in beam search. This effects run-time performance. The higher the more resource required.
* `max-active` : maximum active nodes in beam search. This effects run-time performance. The higher the more resource required.
* `beam` : beam size for pruning in beam search.
* `acoustic-scale` : Acoustic model weight. This should correspond to the configuration that gives you the best WER. For example, if LMWT = 11 gives the best WER for your HCLG on your dev set, use AMWT = (1/11) = 0.09091. However, the chain model AM (the one we provided) provides an extra scaling factor of 10. Thus, your AMWT should also be multiplied by 10. If you get AMWT = 0.09091, then use 0.9091 for `acoustic-scale`.

After you finish the configurations, try to build an image and name it `mymodel`
```bash
docker build -t mymodel .
```

## Step 3 - Sending decoding requests
You can test by 
1. run the image individually and nc (netcat) the raw wav file inside it.
```bash
docker run --rm -p 5050:5050 mymodel
```
Open a new terminal and run `sox example_audio.wav -t raw - | nc localhost 5050`. For simplicity, you can also test with `nc localhost 5050 < example_audio.wav`, but this is not guaranteed to work.

To stop the docker image, you can run `docker stop <CONTAINER ID>`. You can find the `CONTAINER ID` by runnning `docker ps`.

2. run the website and use the audio recoder there.

This section uses docker-compose, it will run multiple docker containers and link them together. To use your model instead of the default English model, you have to change the `KaldiWebrtcServer/docker/docker-compose.yml` file to use your kaldi image.

Change `image: "danijel3/kaldi-online-tcp:aspire"` to `image: "mymodel"`
kaldi image in Dockerfile as `mymodel`.

Change the `samplerate` in `KaldiWebrtcServer/docker/servers.json` to 16000.

The following comamnds perform the changes if you have not done so.
```bash
cd ..
cp  docker-compose.yml  tmp && \
sed 's/\danijel3\/kaldi-online-tcp:aspire/mymodel/' tmp > docker-compose.yml && \
cp  servers.json  tmp && \
sed 's/8000/16000/' tmp > servers.json && \
rm tmp
```

After finishing the configurations, run
```bash
docker-compose up -d
```

The web will be available at `localhost:8080`. 
Once it is running, you can run `docker-compose logs -f` to monitor the logs of the running servers.
At any time you can run `docker-compose stop` to temporarily shutdown and `docker-compose start` to restart the service. Finally, you can run `docker-compose down` to stop and remove the containers altogether.

If you change anything, you have to remove the model server (that you built in step 2), rebuild the image, and start a new one. Your change will not take any effects if you do not rebuild the image.

Credits:

* Docker KaldiWebRTC repository https://github.com/danijel3/KaldiWebrtcServer
