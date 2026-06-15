package com.proxyvpn.wireguard;

import com.wireguard.android.backend.Tunnel;

public class SimpleTunnel implements Tunnel {
    private final String tunnelName;

    public SimpleTunnel(String tunnelName) {
        this.tunnelName = tunnelName;
    }

    @Override
    public String getName() {
        return tunnelName;
    }

    @Override
    public void onStateChange(State newState) {
        // no-op
    }
}
