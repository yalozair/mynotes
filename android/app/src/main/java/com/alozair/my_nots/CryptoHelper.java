package com.alozair.my_nots;

import android.util.Base64;

import java.security.SecureRandom;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class CryptoHelper {
    private static final String TRANSFORMATION = "AES/CBC/PKCS5Padding";

    public static String encrypt(String value, byte[] keyBytes) {
        try {
            byte[] ivBytes = new byte[16];
            new SecureRandom().nextBytes(ivBytes);
            SecretKeySpec secretKey = new SecretKeySpec(keyBytes, "AES");
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new IvParameterSpec(ivBytes));
            byte[] encrypted = cipher.doFinal(value.getBytes("UTF-8"));
            return "v2:" + Base64.encodeToString(ivBytes, Base64.NO_WRAP) + ":" +
                    Base64.encodeToString(encrypted, Base64.NO_WRAP);
        } catch (Exception e) {
            return value;
        }
    }

    public static String decrypt(String value, byte[] keyBytes) {
        try {
            if (value != null && value.startsWith("v2:")) {
                String[] parts = value.split(":", 3);
                if (parts.length < 3) return value;
                byte[] ivBytes = Base64.decode(parts[1], Base64.NO_WRAP);
                byte[] cipherBytes = Base64.decode(parts[2], Base64.NO_WRAP);
                SecretKeySpec secretKey = new SecretKeySpec(keyBytes, "AES");
                Cipher cipher = Cipher.getInstance(TRANSFORMATION);
                cipher.init(Cipher.DECRYPT_MODE, secretKey, new IvParameterSpec(ivBytes));
                return new String(cipher.doFinal(cipherBytes), "UTF-8");
            }
            return value;
        } catch (Exception e) {
            return value;
        }
    }
}
