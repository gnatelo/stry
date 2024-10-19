#!/bin/bash

# Function for outputting steps
log() {
    echo -e "\e[1;32m$1\e[0m"
}

log "hello IP"

# Ask for node moniker at the beginning
read -p "Enter the moniker: " MONIKER

# Step 1: Install dependencies
log "Updating package lists and installing required dependencies..."
sudo apt update && sudo apt-get update
sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y

# Step 2: Download Story-Geth binary v0.9.4
log "Downloading and installing Story-Geth binary..."
cd $HOME
wget https://github.com/piplabs/story-geth/releases/download/v0.9.4/geth-linux-amd64
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
fi
chmod +x geth-linux-amd64
mv $HOME/geth-linux-amd64 $HOME/go/bin/story-geth
source $HOME/.bash_profile
story-geth version

# Step 3: Download Story binary v0.11.0
log "Downloading and installing Story binary..."
cd $HOME
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.11.0-aac4bfe.tar.gz
tar -xzvf story-linux-amd64-0.11.0-aac4bfe.tar.gz
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.bash_profile
fi
sudo cp $HOME/story-linux-amd64-0.11.0-aac4bfe/story $HOME/go/bin
source $HOME/.bash_profile
story version

# Step 4: Initialize Iliad node
log "Initializing Story Iliad node with moniker: $MONIKER"
story init --network iliad --moniker "$MONIKER"

# Step 5: Create story-geth service file
log "Creating story-geth service file..."
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Create story service file
log "Creating story service file..."
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Step 7: Download and apply Story and Geth snapshots
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

# Step 8: Reload and start story-geth and story services
log "Reloading systemd and starting story-geth and story services..."
sudo systemctl daemon-reload
sudo systemctl start story-geth
sudo systemctl enable story-geth
sudo systemctl status story-geth

sudo systemctl start story
sudo systemctl enable story
sudo systemctl status story

# Step 9: Monitor logs
log "Monitoring story-geth logs..."
sudo journalctl -u story-geth -f -o cat

log "Monitoring story logs..."
sudo journalctl -u story -f -o cat

# Step 10: Check sync status
log "Checking sync status..."
curl localhost:26657/status | jq

# Step 11: Check block sync left
log "Checking block sync status..."
while true; do
    local_height=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height');
    network_height=$(curl -s https://archive-rpc-story.josephtran.xyz/status | jq -r '.result.sync_info.latest_block_height');
    blocks_left=$((network_height - local_height));
    echo -e "\033[1;38mYour node height:\033[0m \033[1;34m$local_height\033[0m | \033[1;35mNetwork height:\033[0m \033[1;36m$network_height\033[0m | \033[1;29mBlocks left:\033[0m \033[1;31m$blocks_left\033[0m";
    sleep 5;
done
