#!/bin/bash
# A UNIX / Linux shell script to add ssh authentication between machines.
# This script permit ssh authentication without password to all users.
# You can run script when you add a new machine to the cluster.
# Script must run as root or configure permission via sudo.
#--------------------------------------------------------------------------
# http://cert.uni-stuttgart.de/doc/ssh-host-based.html
# http://itg.chem.indiana.edu/inc/wiki/software/openssh/189.html
# Nodos en /root/bin/machines
# -------------------------------------------------------------------------
# Copyright (c) 2012 David Trigo <david.trigo@gmail.com>
# This script is licensed under GNU GPL version 3.0 or above
# -------------------------------------------------------------------------
# Last updated on : June-2012 - Script created.
# -------------------------------------------------------------------------

echo -ne "Introduce el nombre de la nueva maquina (FQDN): \t"
read PC
echo "Has introducido el nombre de la nueva maquina: $PC"
echo "Si no es correcto, no continues (NO)"

#Exportamos la clave de root para tener acceso desde el master sin pass
if [ ! -f /root/.ssh/id_dsa.pub ];then
    ssh-keygen -t dsa -N "" -f /root/.ssh/id_dsa
fi

ssh-copy-id -i /root/.ssh/id_dsa.pub root@$PC

#Anadimos la maquina a la lista de hosts del cluster
echo $PC>>/root/bin/maquinas

#############################
#  Comandos en el servidor  #
#############################

#Agregamos la clave del host como conocida
ssh-keyscan -t rsa $PC >> /etc/ssh/ssh_known_hosts


#Agregamos el nombre de los hosts que tienen nombres identicos
cat /etc/ssh/ssh_known_hosts | cut -d" " -f1 > /etc/hosts.equiv

#Configuramos el servicio ssh
#Agregamos la posibilidad de acceso por host en la config del serv
grep ^HostbasedAuthentication /etc/ssh/sshd_config > /dev/null

if [ $? -ne 0 ];then
    echo "HostbasedAuthentication yes">>/etc/ssh/sshd_config
fi


grep ^RhostsRSAAuthentication /etc/ssh/sshd_config > /dev/null

if [ $? -ne 0 ];then
    echo "RhostsRSAAuthentication yes">>/etc/ssh/sshd_config
fi


#Permitimos tambien la conexion de root
grep ^IgnoreRhosts /etc/ssh/sshd_config > /dev/null

if [ $? -ne 0 ];then
    echo "IgnoreRhosts no">>/etc/ssh/sshd_config
fi

#Agregamos las lineas al cliente de SSH para que pueda conectarse el server tambien a los nodos
grep ^HostbasedAuthentication /etc/ssh/ssh_config > /dev/null

if [ $? -ne 0 ];then
    echo "HostbasedAuthentication yes">>/etc/ssh/ssh_config
fi

grep ^EnableSSHKeysign /etc/ssh/ssh_config > /dev/null

if [ $? -ne 0 ];then
    echo "EnableSSHKeysign yes">>/etc/ssh/ssh_config
fi

#Reiniciamos el servicio ssh
/etc/init.d/sshd restart


#Ponemos los permisos correctos
if [ -f /usr/lib64/ssh/ssh-keysign ];then
    chmod u+s /usr/lib64/ssh/ssh-keysign
else
    chmod u+s /usr/lib/ssh/ssh-keysign
fi


############################
#  Comandos en el cliente  #
############################

scp /etc/ssh/sshd_config $PC:/etc/ssh/
scp /etc/ssh/ssh_config $PC:/etc/ssh/

ssh $PC "if [ -f /usr/lib64/ssh/ssh-keysign ];then     chmod u+s /usr/lib64/ssh/ssh-keysign; else     chmod u+s /usr/lib/ssh/ssh-keysign; fi"


for NODE in `cat /root/bin/maquinas`
do
    echo $NODE:
    scp /etc/hosts.equiv $NODE:/etc/hosts.equiv
    scp /etc/ssh/ssh_known_hosts $NODE:/etc/ssh/ssh_known_hosts
    /etc/init.d/sshd restart
done

unset PC
unset NODE
