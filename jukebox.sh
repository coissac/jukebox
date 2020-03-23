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

###########################################################################
#####                                                                 #####
##### NE PAS EDIITER CI-DESSOUS SAUF SI VOUS SAVEZ CE QUE VOUS FAITES #####
#####                                                                 #####
###########################################################################
####
#
# Remise à jour du système
#
sudo apt-get update
yes Y | sudo apt-get dist-upgrade

####
#
# Activation du serveur SSH
#

if (( ACTIVER_SSH_SERVEUR == 1 )) ; then
  sudo systemctl enable ssh
fi  
