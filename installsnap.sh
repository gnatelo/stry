#!/bin/bash

# Function for outputting steps
log() {
    echo -e "\e[1;32m$1\e[0m"
}

log "hello IP"

#Download and apply Story and Geth snapshots
log "Downloading Story and Geth snapshots..."
cd $HOME
rm -f Story_snapshot.lz4 Geth_snapshot.lz4
aria2c -x 16 -s 16 -k 1M https://story.josephtran.co/Story_snapshot.lz4
aria2c -x 16 -s 16 -k 1M https://story.josephtran.co/Geth_snapshot.lz4

log "Applying snapshots..."
cp $HOME/.story/story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup
rm -rf $HOME/.story/story/data
rm -rf $HOME/.story/geth/iliad/geth/chaindata

sudo mkdir -p $HOME/.story/story/data
lz4 -d -c Story_snapshot.lz4 | pv | sudo tar xv -C $HOME/.story/story/ > /dev/null
cp $HOME/.story/priv_validator_state.json.backup $HOME/.story/story/data/priv_validator_state.json

sudo mkdir -p $HOME/.story/geth/iliad/geth/chaindata
lz4 -d -c Geth_snapshot.lz4 | pv | sudo tar xv -C $HOME/.story/geth/iliad/geth/ > /dev/null

#Reload and start story-geth and story services
log "Reloading systemd and starting story-geth and story services..."
sudo systemctl daemon-reload

sudo systemctl start story-geth
sudo systemctl enable story-geth
sudo systemctl status story-geth

sudo systemctl start story
sudo systemctl enable story
sudo systemctl status story

log "FIN: checking sync status..."
curl localhost:26657/status | jq
