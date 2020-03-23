#!/bin/bash
#
# Ce script a pour but de préparer un Rasberry Pi pour le transformer en 
# serveur video / audio multiroom.
#

####
#
# Options de configuration
#

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


####
#
# Remise à jour du système
#

apt-get update
yes Y | apt-get dist-upgrade

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
 
   
 
   
