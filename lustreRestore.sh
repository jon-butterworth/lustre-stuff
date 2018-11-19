#!/bin/bash
##
## A script to recover Lustre following a failure.

#*******SET THIS...!!!!!!*******
#########################
export META_SRV="meta2"##
#########################

export COLOUR_LGREEN='\033[01;32m'
export COLOUR_CYAN='\033[00;36m'
export COLOUR_RED='\033[00;31m'
export COLOUR_NC='\e[0m'
export oss_list="hablockh1-1 hablockh1-2 hablockh2-1 hablockh2-2 hablocki1-1 hablocki1-2 hablocki2-1 hablocki2-2 hablockd1-1 hablockd1-2"

#FUNCTIONS
colourise() {
    text=$1
    colour=$2

    if [[ -n "$DISABLE_COLOURS"]]; then
        echo "$text"
    else
        echo -e "${colour}${text}$COLOUR_NC"
    fi
}
info() {
   text=$1
   colourise "[INFO] $text" "$COLOUR_CYAN"
}
success() {
    text=$1
    colourise "[++++] $text" "$COLOUR_LGREEN"
}
error() {
    text=$1
    colourise "[ERROR] $text" "$COLOUR_RED"
}
unmountAll() {
    local node=$1
    if [[ "$node" == "" ]]; then
        echo "${FUNCNAME[0]}: missing node name"
        return 10
    fi

    info "unmounting all OST's..."

    ssh $node "for mount in $(mount | awk '/lustre/{ print \$1 }'); do umount $mount; done"

    if [[ $? -eq "0" ]]; then # This is going to need testing... I suspect we'll get the return code from the ssh command... so will give false positives?
      success "...OSTs unmounted."
    else
      error "There is a problem!"
    fi
}
e2fsckAll() {
    local node=$1
    if [[ "$node" == "" ]]; then
        echo "${FUNCNAME[0]}: missing node name"
        return 20
    fi

    info "running e2fsck on all OSTs..."

    local osts=$(ssh $node 'mount | awk "/ost/{ print $1 }"')

    for mount in $(echo $osts | tr ' ' '\n'); do
        ssh $node 'umount $mount'
    done
}
disableQuotasAll() {
    local node=$1
    if [[ "$node" == "" ]]; then
        echo "${FUNCNAME[0]}: missing node name"
        return 10
    fi

    info "Disabling quotas on all OSTs"

    local osts=$(ssh $node 'mount | awk "/ost/{ print $1 }"')

    for mount in $(echo $osts | tr ' ' '\n'); do
        ssh $node 'tune2fs -Q ^usrquota $mount'
        ssh $node 'tune2fs -Q ^grpquota $mount'
    done
}
mountAll() {
  #If time allows I'll revisit this module and make it more agnostic, I would like to add a data-map to pull the OST/OSS mappings from, it would make other modules easier also.
  local node=$1
  if [[ "$node" == "" ]]; then
      echo "${FUNCNAME[0]}: missing node name"
      return 10
  fi

  info "Mounting all OSTs to begin recovery"

  ssh hablockh1-1 'mount -t lustre /dev/mapper/ost0 /mnt/lustre-ost0;  mount -t lustre /dev/mapper/ost1 /mnt/lustre-ost1;  mount -t lustre /dev/mapper/ost2 /mnt/lustre-ost2;'
  ssh hablockh1-2 'mount -t lustre /dev/mapper/ost3 /mnt/lustre-ost3;  mount -t lustre /dev/mapper/ost4 /mnt/lustre-ost4;  mount -t lustre /dev/mapper/ost5 /mnt/lustre-ost5;'
  ssh hablockh2-1 'mount -t lustre /dev/mapper/ost6 /mnt/lustre-ost6;  mount -t lustre /dev/mapper/ost7 /mnt/lustre-ost7;  mount -t lustre /dev/mapper/ost8 /mnt/lustre-ost8;'
  ssh hablockh2-2 'mount -t lustre /dev/mapper/ost9 /mnt/lustre-ost9;  mount -t lustre /dev/mapper/ost10 /mnt/lustre-ost10;  mount -t lustre /dev/mapper/ost11 /mnt/lustre-ost11;'
  ssh hablocki1-1 'mount -t lustre /dev/mapper/ost12 /mnt/lustre-ost12;  mount -t lustre /dev/mapper/ost13 /mnt/lustre-ost13;  mount -t lustre /dev/mapper/ost14 /mnt/lustre-ost14;'
  ssh hablocki1-2 'mount -t lustre /dev/mapper/ost15 /mnt/lustre-ost15;  mount -t lustre /dev/mapper/ost16 /mnt/lustre-ost16;  mount -t lustre /dev/mapper/ost17 /mnt/lustre-ost17;'
  ssh hablocki2-1 'mount -t lustre /dev/mapper/ost18 /mnt/lustre-ost18;  mount -t lustre /dev/mapper/ost19 /mnt/lustre-ost19;  mount -t lustre /dev/mapper/ost20 /mnt/lustre-ost20;'
  ssh hablocki2-2 'mount -t lustre /dev/mapper/ost21 /mnt/lustre-ost21;  mount -t lustre /dev/mapper/ost22 /mnt/lustre-ost22;  mount -t lustre /dev/mapper/ost23 /mnt/lustre-ost23;'
  ssh hablockd1-1 'mount -t lustre /dev/mapper/ost24 /mnt/lustre-ost24; mount -t lustre /dev/mapper/ost25 /mnt/lustre-ost25;  mount -t lustre /dev/mapper/ost26 /mnt/lustre-ost26;'
  ssh hablockd1-2 'mount -t lustre /dev/mapper/ost27 /mnt/lustre-ost27; mount -t lustre /dev/mapper/ost28 /mnt/lustre-ost28;  mount -t lustre /dev/mapper/ost29 /mnt/lustre-ost29;'
  ssh $META_SRV 'mount -t lustre /dev/mapper/mdt /mnt/lustre/mdt1'
}
chkRecovery() {
  local node=$1
  if [[ "$node" == "" ]]; then
      echo "${FUNCNAME[0]}: missing node name"
      return 10
  fi

  info "Ensure recovery is complete..."

  complete=$(ssh $node 'cat /proc/fs/lustre/*/*/recovery_status | grep status')
  if grep "RECOVERING" $complete; then
      info "$node is still recovering"
  elif grep "COMPLETE" $complete; then
      info "$node has completed recovery"
  fi
}
