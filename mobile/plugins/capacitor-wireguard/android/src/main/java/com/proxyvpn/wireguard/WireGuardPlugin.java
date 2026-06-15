package com.proxyvpn.wireguard;

import android.app.Activity;
import android.content.Intent;
import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.wireguard.android.backend.Backend;
import com.wireguard.android.backend.GoBackend;
import com.wireguard.android.backend.Tunnel;
import com.wireguard.config.Config;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;

@CapacitorPlugin(name = "WireGuard")
public class WireGuardPlugin extends Plugin {
    private static final String TAG = "WireGuardPlugin";
    private static final int VPN_REQUEST_CODE = 51820;
    private static final String DEFAULT_TUNNEL_NAME = "ProxyVPN";

    private final java.util.concurrent.ExecutorService executor = Executors.newSingleThreadExecutor();
    private Backend backend;
    private SimpleTunnel tunnel;
    private PluginCall pendingCall;
    private String pendingConfig;
    private String pendingTunnelName = DEFAULT_TUNNEL_NAME;

    @PluginMethod
    public void connect(PluginCall call) {
        String configText = call.getString("config");
        if (configText == null || configText.trim().isEmpty()) {
            call.reject("Configuração WireGuard é obrigatória");
            return;
        }

        String tunnelName = call.getString("tunnelName", DEFAULT_TUNNEL_NAME);
        if (tunnelName == null || tunnelName.isEmpty()) {
            tunnelName = DEFAULT_TUNNEL_NAME;
        }

        if (Tunnel.isNameInvalid(tunnelName)) {
            call.reject("Nome do túnel inválido");
            return;
        }

        try {
            Config.parse(new ByteArrayInputStream(configText.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            call.reject("Configuração WireGuard inválida: " + e.getMessage());
            return;
        }

        Activity activity = getActivity();
        if (activity == null) {
            call.reject("Activity indisponível");
            return;
        }

        Intent prepareIntent = GoBackend.VpnService.prepare(activity);
        if (prepareIntent != null) {
            pendingCall = call;
            pendingConfig = configText;
            pendingTunnelName = tunnelName;
            startActivityForResult(call, prepareIntent, VPN_REQUEST_CODE);
            return;
        }

        startTunnel(call, configText, tunnelName);
    }

    @PluginMethod
    public void disconnect(PluginCall call) {
        Backend currentBackend = backend;
        SimpleTunnel currentTunnel = tunnel;

        if (currentBackend == null || currentTunnel == null) {
            resolveStatus(call, false);
            return;
        }

        executor.execute(() -> {
            try {
                currentBackend.setState(currentTunnel, Tunnel.State.DOWN, null);
                resolveStatus(call, false);
            } catch (Exception e) {
                Log.e(TAG, "disconnect failed", e);
                call.reject("Falha ao desconectar: " + e.getMessage());
            }
        });
    }

    @PluginMethod
    public void getStatus(PluginCall call) {
        Backend currentBackend = backend;
        SimpleTunnel currentTunnel = tunnel;

        if (currentBackend == null || currentTunnel == null) {
            resolveStatus(call, false);
            return;
        }

        executor.execute(() -> {
            try {
                Tunnel.State state = currentBackend.getState(currentTunnel);
                resolveStatus(call, state == Tunnel.State.UP);
            } catch (Exception e) {
                Log.e(TAG, "getStatus failed", e);
                resolveStatus(call, false);
            }
        });
    }

    @Override
    protected void handleOnActivityResult(int requestCode, int resultCode, Intent data) {
        super.handleOnActivityResult(requestCode, resultCode, data);

        if (requestCode != VPN_REQUEST_CODE) {
            return;
        }

        PluginCall call = pendingCall;
        String configText = pendingConfig;
        String tunnelName = pendingTunnelName;

        pendingCall = null;
        pendingConfig = null;
        pendingTunnelName = DEFAULT_TUNNEL_NAME;

        if (call == null || configText == null) {
            return;
        }

        if (resultCode != Activity.RESULT_OK) {
            call.reject("Permissão VPN negada pelo usuário");
            return;
        }

        startTunnel(call, configText, tunnelName);
    }

    private void startTunnel(PluginCall call, String configText, String tunnelName) {
        executor.execute(() -> {
            try {
                if (!(backend instanceof GoBackend)) {
                    backend = new GoBackend(getContext().getApplicationContext());
                }

                tunnel = new SimpleTunnel(tunnelName);
                Config config = Config.parse(new ByteArrayInputStream(configText.getBytes(StandardCharsets.UTF_8)));

                Tunnel.State newState = backend.setState(tunnel, Tunnel.State.UP, config);
                if (newState != Tunnel.State.UP) {
                    call.reject("Não foi possível ativar o túnel VPN");
                    return;
                }

                JSObject result = new JSObject();
                result.put("connected", true);
                result.put("tunnelName", tunnelName);
                call.resolve(result);
            } catch (Exception e) {
                Log.e(TAG, "connect failed", e);
                call.reject("Falha ao conectar: " + e.getMessage());
            }
        });
    }

    private void resolveStatus(PluginCall call, boolean connected) {
        JSObject result = new JSObject();
        result.put("connected", connected);
        result.put("tunnelName", tunnel != null ? tunnel.getName() : DEFAULT_TUNNEL_NAME);
        call.resolve(result);
    }
}
