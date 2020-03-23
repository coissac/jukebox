#!/bin/bash
#
# Ce script a pour but de préparer un Rasberry Pi pour le transformer en 
# serveur video / audio multiroom.
#

####
#
# Options de configuration
#

HOSTNAME=pizzicato

ACTIVER_SSH_SERVEUR=1

GPU_MEMORY=300

DECODE_MPG2=""
DECODE_WVC1=""


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



