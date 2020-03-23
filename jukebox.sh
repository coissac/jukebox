#!/bin/bash
#
# Ce script a pour but de préparer un Rasberry Pi pour le transformer en 
# serveur video / audio multiroom.
#

####
#
# Options de configuration
#

##
## Paramettre system
##

HOSTNAME=pizzicato           # Nom de la machine sur le réseau local
ACTIVER_SSH_SERVEUR=1        # Si 1 le serveur ssh d'acces distant est activé

##
## Paramettre kodi
##

GPU_MEMORY=300               # Kodi a besoin que le GPU dispose de suffisament de
                             # mémoire. Sur une machine avec 1Go de mémoire (PI3B+)
                             # 300Go assure une bonne fluidité

        # Licences de décodage matériel des codec Vidéo
        
DECODE_MPG2=""               # Indiquer ici la clé de licence pour le decodage MPEG2
DECODE_WVC1=""               # Indiquer ici la clé de licence pour le decodage VC1


##
## Paramettres Squeezelite
##

SQUEEZELITE_USER=squeezelite     # Nom de l'utilisateur faisant tourner les client LMS
SQUEEZENAME=$HOSTNAME
OUTPUT=USB

###########################################################################
#####                                                                 #####
##### NE PAS EDIITER CI-DESSOUS SAUF SI VOUS SAVEZ CE QUE VOUS FAITES #####
#####                                                                 #####
###########################################################################

####
#
# fonctions utilitaires
#

function change_hostname() {
  local newname=$1
  local tmp=$(mktemp)
  
  echo "$newname" > /etc/hostname
  
  sudo cp /etc/hosts /etc/hosts.ori.$(date '+%Y%m%d_%k%M')
  
  awk -v hostname="$newname" \
      'BEGIN        {OFS="\t"} \
       /^127.0.1.1/ {$NF=hostname} \
                    {print $0}' /etc/hosts \
    > "$tmp"
    
  mv "$tmp" /etc/hosts
}

function edit_config() {
  local parametre=$1
  shift
  local value=$*
  local tmp=$(mktemp)

  awk -v date="$(date '+%d/%m/%Y at %k:%M')" \
          '/^ *'${parametre}' *=.*$/ {print; \
                                      print "# commented out by Jukebox.sh on",date; \
                                      printf("# ")} \
           {print $0}' /boot/config.txt \
    | awk -v date="$(date '+%d/%m/%Y at %k:%M')" \
          -v param="${parametre}" \
          -v value="${value}" \
          '{print $0} \
           END {print "#"; \
                print "# Edited on",date,"by Jukebox.sh"; \
                print "#"; \
                print param"="value; \
                print }' > "${tmp}"
                
  mv "${tmp}" /boot/config.txt
  chown root:root /boot/config.txt
}


function download_url() {
  local url="$1"
  local tmp=$(mktemp)
  
  local filename=$(basename "$url")
  
  if [[ "$filename" == "download" ]] ; then
    filename=$(basename $(dirname $SQUEEZE_URL) )
  fi
  
  wget -O "${filename}" "$url" 
  
  echo ${filename}
}

####
#
# Remise à jour du système
#

apt-get update
apt-get dist-upgrade -y

###
#
# Changement du nom de l'hote
#

change_hostname "${HOSTNAME}"

####
#
# Activation du serveur SSH
#

if (( ACTIVER_SSH_SERVEUR == 1 )) ; then
  systemctl enable ssh
fi  

####
#
# Modification du fichier /boot/config.txt
#
#   - Ajouter la part de la mémoire dédiée au GPU
#   - Ajouter les eventuelles licences pour les 
#     accellerations materielles des codecs video 

sudo cp /boot/config.txt /boot/config.txt.ori.$(date '+%Y%m%d_%k%M')

if [ ! -z "${GPU_MEMORY}" ] ; then
   edit_config gpu_mem "${GPU_MEMORY}"
fi
   
if [ ! -z "${DECODE_MPG2}" ] ; then
   edit_config decode_MPG2 "${GPU_MEMORY}"
fi

if [ ! -z "${DECODE_WVC1}" ] ; then
   edit_config decode_WVC1 "${GPU_MEMORY}"
fi  
 
   
 ####
 #
 # Installation du client CEC
 #
 
apt install -y cec-utils 

####
#
# Installation du Logitech Media Server
#
#

# Installation des dépendances...

apt-get install -y libio-socket-ssl-perl \
                   libnet-libidn-perl    \
                   libnet-ssleay-perl    \
                   perl-openssl-defaults \
                   libsox-fmt-all        \
                   libflac-dev

# Récuperation de l'URL du dernier 'night build' de la version 7.0

URL_LMS=$(curl http://downloads.slimdevices.com/nightly/?ver=7.9 \
             | egrep '_arm.deb' \
             | sed -E 's@.*href="(.*_arm\.deb)".*$@http://downloads.slimdevices.com/nightly/\1@')
             
# Téméchargement et installation du package
LMS_PKG=$(download_url "${URL_LMS}")
dpkg -i "${LMS_PKG}"


####
#
# Installation de squeezelite
#
#

# Installation des dépendances...

apt-get install -y libasound2-dev libflac-dev \
                   libmad0-dev libvorbis-dev \
                   libfaad-dev libmpg123-dev \
                   liblircclient-dev libncurses5-dev
  
mkdir -p ~/softwares/squeezelite
pushd ~/softwares/squeezelite

SQUEEZE_URL=$(curl https://sourceforge.net/projects/lmsclients/files/squeezelite/linux/ \
               | egrep href \
               | egrep 'armv6hf.tar.gz' \
               | sed -E 's@.*href="([^"]+)".*$@\1@' \
               | grep download \
               | sort \
               | tail -1)
               
               
if [[ ! -d /usr/local/bin ]] ; then 
   mkdir -p /usr/local/bin
   chown root:root /usr/local/bin
fi

SQUEEZE_PKG=$(download_url "${SQUEEZE_URL}")
tar -xzf "${SQUEEZE_PKG}"
mv squeezelite /usr/local/bin/squeezelite
chown root:root /usr/local/bin/squeezelite

popd

adduser --disabled-login \
        --no-create-home \
        --system  "$SQUEEZELITE_USER"
        
##
## Création du fichier de config pour Squeezelite
##

DEVICE=$(squeezelite -l | grep "${OUTPUT}" | grep hardware | awk '{print $1}')

echo selected audio device : $(squeezelite -l | grep "${OUTPUT}" | grep hardware)

cat << EOF > /etc/squeezlite.conf
DEVICE=$DEVICE
HOSTENAME=$SQUEEZENAME
EXTRA_OPTIONS=
EOF

##
##  Création du fichier de service systeme pour Squeezelite
##

cat << EOF > /etc/systemd/system/squeezelite.service
[Unit]
Description=Squeezelite
After=network.target

[Service]
User=squeezelite
Group=squeezelite
EnvironmentFile=/etc/squeezlite.conf
ExecStart=/usr/local/bin/squeezelite -o \$DEVICE -n \$HOSTENAME \$EXTRA_OPTIONS

[Install]
WantedBy=multi-user.target
EOF
