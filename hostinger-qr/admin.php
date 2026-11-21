<?php
/**
 * Nilly Dynamic QR Admin Panel — Self-Hosted on Hostinger
 * Edit any printed client QR destination anytime without reprinting!
 *
 * created by Nilly graphics (Sotiris Christos)
 * https://nillygraphics.com/
 */

declare(strict_types=1);
session_start();

// Create config.php with: <?php define('ADMIN_PASS_HASH', password_hash('YOUR_STRONG_PASSWORD', PASSWORD_DEFAULT));
$configFile = __DIR__ . '/config.php';
$dataFile   = __DIR__ . '/links.json';
if (is_file($configFile)) {
    require_once $configFile;
}

$configured = defined('ADMIN_PASS_HASH') && ADMIN_PASS_HASH !== '';
$err = '';

if ($configured && isset($_POST['login_pass'])) {
    if (password_verify((string)$_POST['login_pass'], ADMIN_PASS_HASH)) {
        $_SESSION['nilly_qr_auth'] = true;
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
        header('Location: admin.php');
        exit;
    }
    $err = 'Λάθος κωδικός.';
}

if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: admin.php');
    exit;
}

$authed = $configured && !empty($_SESSION['nilly_qr_auth']);
$links = is_file($dataFile) ? (json_decode((string)file_get_contents($dataFile), true) ?: []) : [];

if ($authed && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    if (!hash_equals((string)($_SESSION['csrf'] ?? ''), (string)($_POST['csrf'] ?? ''))) {
        http_response_code(403);
        exit('Invalid CSRF token');
    }
    $slug = strtolower(preg_replace('/[^a-zA-Z0-9_-]/', '', (string)($_POST['slug'] ?? '')));
    if ($_POST['action'] === 'save' && $slug !== '') {
        $url = trim((string)($_POST['url'] ?? ''));
        $client = trim((string)($_POST['client'] ?? ''));
        if (preg_match('#^https?://#i', $url)) {
            $links[$slug] = [
                'client'    => $client ?: $slug,
                'url'       => $url,
                'scans'     => (int)($links[$slug]['scans'] ?? 0),
                'last_scan' => $links[$slug]['last_scan'] ?? '-',
                'updated'   => gmdate('Y-m-d H:i') . 'Z',
            ];
            file_put_contents($dataFile, json_encode($links, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), LOCK_EX);
        } else {
            $err = 'Το URL πρέπει να ξεκινά με https:// ή http://';
        }
    } elseif ($_POST['action'] === 'delete' && isset($links[$slug])) {
        unset($links[$slug]);
        file_put_contents($dataFile, json_encode($links, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), LOCK_EX);
    }
}

$baseUrl = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'nillygraphics.com') . rtrim(dirname($_SERVER['SCRIPT_NAME']), '/') . '/';
?>
<!doctype html>
<html lang="el">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Nilly Dynamic QR Manager — created by Nilly graphics (Sotiris Christos)</title>
<style>
  body{margin:0;background:#0B0F17;color:#F1F5F9;font-family:system-ui,-apple-system,Segoe UI,sans-serif;padding:24px}
  .wrap{max-width:920px;margin:0 auto}
  .card{background:#131924;border:1px solid #1F293B;border-radius:12px;padding:18px;margin-bottom:16px}
  input,button{font:inherit;border-radius:8px;padding:9px 12px;border:1px solid #2C384D}
  input{background:#0B0F17;color:#F8FAFC;width:100%;box-sizing:border-box}
  button{background:#38BDF8;color:#072235;font-weight:700;cursor:pointer;border:none}
  button.del{background:#341821;color:#FDA4AF;border:1px solid #7F1D1D;padding:5px 10px}
  table{width:100%;border-collapse:collapse;font-size:13.5px}
  th,td{padding:10px 8px;border-bottom:1px solid #1F293B;text-align:left}
  th{color:#94A3B8;font-size:12px}
  a{color:#38BDF8;text-decoration:none}
  .grid{display:grid;grid-template-columns:1fr 1fr 2fr auto;gap:8px;align-items:end}
  @media(max-width:720px){.grid{grid-template-columns:1fr}}
  .foot{text-align:center;color:#64748B;font-size:12px;margin-top:24px}
</style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <h2 style="margin:0 0 4px">Nilly Dynamic QR Manager</h2>
    <div style="color:#94A3B8;font-size:13px">Επεξεργάσιμα QR Codes πελατών στον Hostinger server σου — 0 συνδρομές, δεν λήγουν ποτέ.</div>
  </div>

  <?php if (!$configured): ?>
    <div class="card">
      <h3>Πρώτη Ρύθμιση (1 λεπτό)</h3>
      <p>Δημιούργησε ένα αρχείο <code>config.php</code> στον ίδιο φάκελο στον Hostinger με περιεχόμενο:</p>
      <pre style="background:#0B0F17;padding:12px;border-radius:8px;overflow:auto">&lt;?php
define('ADMIN_PASS_HASH', '<?= htmlspecialchars(password_hash('ChangeMe2026!', PASSWORD_DEFAULT)) ?>');</pre>
      <p style="color:#94A3B8;font-size:12.5px">Αντικατάστησε το <code>ChangeMe2026!</code> τρέχοντας <code>php -r "echo password_hash('ΤΟ_PASSWORD_ΣΟΥ', PASSWORD_DEFAULT);"</code> ή γράψε το δικό σου hash.</p>
    </div>
  <?php elseif (!$authed): ?>
    <div class="card" style="max-width:380px">
      <form method="post">
        <label style="font-size:13px;color:#94A3B8">Κωδικός Διαχειριστή</label>
        <input type="password" name="login_pass" required style="margin:8px 0 12px">
        <?php if ($err): ?><div style="color:#FDA4AF;margin-bottom:10px"><?= htmlspecialchars($err) ?></div><?php endif; ?>
        <button type="submit" style="width:100%">Είσοδος</button>
      </form>
    </div>
  <?php else: ?>
    <div class="card">
      <form method="post" class="grid">
        <input type="hidden" name="csrf" value="<?= htmlspecialchars((string)$_SESSION['csrf']) ?>">
        <input type="hidden" name="action" value="save">
        <div><label style="font-size:11px;color:#94A3B8">Slug (π.χ. cafe-alpha)</label><input name="slug" required pattern="[a-zA-Z0-9_-]+"></div>
        <div><label style="font-size:11px;color:#94A3B8">Πελάτης</label><input name="client" placeholder="Όνομα πελάτη"></div>
        <div><label style="font-size:11px;color:#94A3B8">Τελικό URL (https://...)</label><input name="url" type="url" required placeholder="https://..."></div>
        <button type="submit">Αποθήκευση</button>
      </form>
      <?php if ($err): ?><div style="color:#FDA4AF;margin-top:8px"><?= htmlspecialchars($err) ?></div><?php endif; ?>
    </div>

    <div class="card">
      <table>
        <thead><tr><th>QR Link (βάλε αυτό στο QR Generator)</th><th>Πελάτης</th><th>Προορισμός</th><th>Scans</th><th></th></tr></thead>
        <tbody>
        <?php foreach ($links as $k => $v): ?>
          <tr>
            <td><a href="<?= htmlspecialchars($baseUrl . $k) ?>" target="_blank"><?= htmlspecialchars($baseUrl . $k) ?></a></td>
            <td><?= htmlspecialchars((string)($v['client'] ?? $k)) ?></td>
            <td style="word-break:break-all"><a href="<?= htmlspecialchars((string)$v['url']) ?>" target="_blank"><?= htmlspecialchars((string)$v['url']) ?></a></td>
            <td><strong><?= (int)($v['scans'] ?? 0) ?></strong></td>
            <td>
              <form method="post" onsubmit="return confirm('Διαγραφή;')">
                <input type="hidden" name="csrf" value="<?= htmlspecialchars((string)$_SESSION['csrf']) ?>">
                <input type="hidden" name="action" value="delete">
                <input type="hidden" name="slug" value="<?= htmlspecialchars($k) ?>">
                <button class="del" type="submit">Διαγραφή</button>
              </form>
            </td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
      <div style="margin-top:12px;text-align:right"><a href="?logout=1">Αποσύνδεση</a></div>
    </div>
  <?php endif; ?>

  <div class="foot">created by Nilly graphics (Sotiris Christos) — <a href="https://nillygraphics.com/" target="_blank">https://nillygraphics.com/</a></div>
</div>
</body>
</html>
