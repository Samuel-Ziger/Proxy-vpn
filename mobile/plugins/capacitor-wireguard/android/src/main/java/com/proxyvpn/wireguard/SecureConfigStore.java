package com.proxyvpn.wireguard;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;

import java.io.IOException;
import java.security.GeneralSecurityException;

final class SecureConfigStore {
    private static final String PREFS_FILE = "ghosttunnel_secure_config";
    private static final String KEY_CONFIG = "wg_config_json";

    private SecureConfigStore() {}

    static void save(Context context, String json) throws GeneralSecurityException, IOException {
        getPrefs(context).edit().putString(KEY_CONFIG, json).apply();
    }

    static String load(Context context) throws GeneralSecurityException, IOException {
        return getPrefs(context).getString(KEY_CONFIG, null);
    }

    static void clear(Context context) throws GeneralSecurityException, IOException {
        getPrefs(context).edit().remove(KEY_CONFIG).apply();
    }

    private static SharedPreferences getPrefs(Context context)
            throws GeneralSecurityException, IOException {
        MasterKey masterKey = new MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build();

        return EncryptedSharedPreferences.create(
                context,
                PREFS_FILE,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        );
    }
}
