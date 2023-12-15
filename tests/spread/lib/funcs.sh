
export PATH=/snap/bin:$PROJECT_PATH/tests/spread/lib/tools:$PATH
export CONTROLLER_NAME="craft-test-$PROVIDER"


install_lxd() {
    snap install lxd --channel "$LXD_CHANNEL"
    lxd waitready
    lxd init --auto
    chmod a+wr /var/snap/lxd/common/lxd/unix.socket
    lxc network set lxdbr0 ipv6.address none
    usermod -a -G lxd "$USER"

    # Work-around clash between docker and lxd on jammy
    # https://github.com/docker/for-linux/issues/1034
    iptables -F FORWARD
    iptables -P FORWARD ACCEPT
}


install_microk8s() {
    snap install microk8s --channel "$MICROK8S_CHANNEL"
    snap refresh microk8s --channel "$MICROK8S_CHANNEL"

    # microk8s needs some additional things done to ensure
    #it's ready for Juju.
    microk8s status --wait-ready

    if [ ! -z "$MICROK8S_ADDONS" ]; then
        microk8s enable $MICROK8S_ADDONS
    fi

    local version=$(snap list microk8s | grep microk8s | awk '{ print $2 }')

    # workarounds for https://bugs.launchpad.net/juju/+bug/1937282
    retry microk8s kubectl -n kube-system rollout status deployment/coredns
    retry microk8s kubectl -n kube-system rollout status deployment/hostpath-provisioner

    retry microk8s kubectl auth can-i create pods
}


install_juju() {
    snap install juju --classic --channel "$JUJU_CHANNEL"
    mkdir -p "$HOME"/.local/share/juju
}


bootstrap_juju() {
    juju bootstrap --verbose "$PROVIDER" "$CONTROLLER_NAME" \
      $JUJU_BOOTSTRAP_OPTIONS $JUJU_EXTRA_BOOTSTRAP_OPTIONS \
      --bootstrap-constraints=$JUJU_BOOTSTRAP_CONSTRAINTS
}


restore_juju() {
     juju controllers --refresh ||:
     juju destroy-controller -v --no-prompt --show-log \
       --destroy-storage --destroy-all-models "$CONTROLLER_NAME"
}


install_tools() {
    snap install jq
    snap install charm --classic --channel "$CHARM_CHANNEL"
    snap install charmcraft --classic --channel "$CHARMCRAFT_CHANNEL"
    snap install juju-bundle --classic --channel "$JUJU_BUNDLE_CHANNEL"
    snap install juju-crashdump --classic --channel "$JUJU_CRASHDUMP_CHANNEL"
}

