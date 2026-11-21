<?php
/**
 * Nilly Dynamic QR Redirector — Hostinger Ultra-Light Engine (<30ms on iPhone/Android)
 * Never expires, zero monthly fees, zero database required.
 *
 * created by Nilly graphics (Sotiris Christos)
 * https://nillygraphics.com/
 */

declare(strict_types=1);

$dataFile = __DIR__ . '/links.json';
$slug = trim((string)($_GET['s'] ?? ''), "/ \t\n\r\0\x0B");

if ($slug === '' || !preg_match('/^[a-zA-Z0-9_-]{1,64}$/', $slug)) {
    header('Location: https://nillygraphics.com/', true, 302);
    exit;
}

if (!is_file($dataFile)) {
    http_response_code(404);
    echo 'QR link not found.';
    exit;
}

$fp = fopen($dataFile, 'c+');
if (!$fp) {
    http_response_code(500);
    exit;
}

$target = null;
if (flock($fp, LOCK_EX)) {
    $raw = stream_get_contents($fp);
    $links = json_decode($raw ?: '{}', true);
    if (is_array($links) && isset($links[$slug]['url'])) {
        $url = (string)$links[$slug]['url'];
        if (preg_match('#^https?://#i', $url)) {
            $target = $url;
            $links[$slug]['scans'] = (int)($links[$slug]['scans'] ?? 0) + 1;
            $links[$slug]['last_scan'] = gmdate('Y-m-d H:i:s') . 'Z';
            rewind($fp);
            ftruncate($fp, 0);
            fwrite($fp, json_encode($links, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
            fflush($fp);
        }
    }
    flock($fp, LOCK_UN);
}
fclose($fp);

if ($target !== null) {
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    header('Location: ' . $target, true, 302);
    exit;
}

http_response_code(404);
echo '<!doctype html><meta charset="utf-8"><title>QR Not Found — Nilly Graphics</title><body style="background:#0B0F17;color:#E2E8F0;font-family:sans-serif;text-align:center;padding:60px"><h2>QR Link Not Found</h2><p><a href="https://nillygraphics.com/" style="color:#38BDF8">created by Nilly graphics (Sotiris Christos) — https://nillygraphics.com/</a></p></body>';
