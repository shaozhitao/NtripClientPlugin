package com.example.ntripclient;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.Socket;
import java.util.Base64;
import java.util.concurrent.TimeUnit;


public class NtripSocketClientPlugin extends CordovaPlugin {
    private static final int RECONNECT_DELAY_SECONDS = 5; // 重连延迟时间，单位：秒
    private static final int MAX_RECONNECT_ATTEMPTS = 10; // 最大重连尝试次数

    private Socket socket;
    private OutputStream outputStream;
    private boolean isConnected = false;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        switch (action) {
            case "startNtripClient":
                String ip = args.getString(0);
                int port = args.getInt(1);
                String username = args.getString(2);
                String password = args.getString(3);
                String gngga = args.getString(4);
                startNtripClient(ip, port, username, password, gngga, callbackContext);
                return true;
            case "stopNtripClient":
                stopNtripClient(callbackContext);
                return true;
            case "getConnectionStatus":
                getConnectionStatus(callbackContext);
                return true;
            case "getConnectionInfo":
                getConnectionInfo(callbackContext);
                return true;
            case "sendGngga":
                String newGngga = args.getString(0);
                sendGngga(newGngga, callbackContext);
                return true;
            default:
                return false;
        }
    }

    private void startNtripClient(final String ip, final int port, final String username, final String password, final String gngga, final CallbackContext callbackContext) {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                int reconnectAttempts = 0;
                while (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
                    try {
                        socket = new Socket(ip, port);
                        outputStream = socket.getOutputStream();
                        InputStream inputStream = socket.getInputStream();
                        BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));

                        // 生成基本认证的头部
                        String authString = username + ":" + password;
                        String base64Auth = Base64.getEncoder().encodeToString(authString.getBytes());

                        // 构建 NTRIP 请求
                        StringBuilder request = new StringBuilder();
                        request.append("GET /RTCM32_GGB HTTP/1.1\r\n");
                        request.append("User-Agent: NTRIP Java Client\r\n");
                        request.append("Host: ").append(ip).append("\r\n");
                        request.append("Authorization: Basic ").append(base64Auth).append("\r\n");
                        request.append("Accept: */*\r\n");
                        request.append("Connection: close\r\n\r\n");

                        // 发送请求
                        String testRequest = request.toString();
                        System.out.println("发送数据: " + testRequest);
                        System.out.println("--------------------");
                        outputStream.write(request.toString().getBytes());
                        outputStream.flush();

                        // 读取响应头
                        String line;
                        boolean statusOk = false;
                        while ((line = reader.readLine()) != null) {
                            if (line.isEmpty()) {
                                break;
                            }
                            System.out.println("服务器响应头: " + line); // 打印响应头
                            if (line.startsWith("HTTP/1.1 200 OK") || line.startsWith("ICY 200 OK")) {
                                statusOk = true;
                            }
                        }

                        if (statusOk) {
                            System.out.println("成功连接到 NTRIP 服务器");
                            isConnected = true;
                            reconnectAttempts = 0; // 连接成功，重置重连尝试次数
                            byte[] buffer = new byte[4096];
                            int bytesRead;

                            // 发送 GNGGA 消息
                            outputStream.write(gngga.getBytes());
                            outputStream.flush();
                            System.out.println("发送 GNGGA 消息: " + gngga);

                            while ((bytesRead = inputStream.read(buffer)) != -1) {
                                byte[] receivedData = new byte[bytesRead];
                                System.arraycopy(buffer, 0, receivedData, 0, bytesRead);
                                String hexData = bytesToHex(receivedData);
                                callbackContext.success(hexData);
                            }
                        } else {
                            System.out.println("连接失败，服务器未返回 200 OK 状态码");
                            callbackContext.error("连接失败，服务器未返回 200 OK 状态码");
                        }
                    } catch (IOException e) {
                        System.err.println("发生网络错误: " + e.getMessage());
                        reconnectAttempts++;
                        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
                            System.out.println("尝试第 " + reconnectAttempts + " 次重连，将在 " + RECONNECT_DELAY_SECONDS + " 秒后进行...");
                            try {
                                TimeUnit.SECONDS.sleep(RECONNECT_DELAY_SECONDS);
                            } catch (InterruptedException ie) {
                                Thread.currentThread().interrupt();
                            }
                        } else {
                            System.out.println("达到最大重连尝试次数，停止重连。");
                            callbackContext.error("达到最大重连尝试次数，停止重连。");
                        }
                    }
                }
            }
        });
    }

    private void stopNtripClient(CallbackContext callbackContext) {
        try {
            if (socket != null && !socket.isClosed()) {
                socket.close();
                isConnected = false;
                callbackContext.success("NTRIP 客户端已停止");
            } else {
                callbackContext.error("NTRIP 客户端未连接或已停止");
            }
        } catch (IOException e) {
            callbackContext.error("停止 NTRIP 客户端时发生错误: " + e.getMessage());
        }
    }

    private void getConnectionStatus(CallbackContext callbackContext) {
        callbackContext.success(isConnected ? "已连接" : "未连接");
    }

    private void getConnectionInfo(CallbackContext callbackContext) {
        try {
            JSONObject info = new JSONObject();
            if (socket != null) {
                info.put("ip", socket.getInetAddress().getHostAddress());
                info.put("port", socket.getPort());
            }
            callbackContext.success(info);
        } catch (JSONException e) {
            callbackContext.error("获取连接信息时发生错误: " + e.getMessage());
        }
    }

    private void sendGngga(String gngga, CallbackContext callbackContext) {
        if (isConnected && outputStream != null) {
            try {
                outputStream.write(gngga.getBytes());
                outputStream.flush();
                System.out.println("发送 GNGGA 消息: " + gngga);
                callbackContext.success("GNGGA 消息发送成功");
            } catch (IOException e) {
                callbackContext.error("发送 GNGGA 消息时发生错误: " + e.getMessage());
            }
        } else {
            callbackContext.error("NTRIP 客户端未连接，无法发送 GNGGA 消息");
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02X ", b));
        }
        return result.toString();
    }
}