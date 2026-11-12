<!DOCTYPE html>
<html>
<head><title>Dev Environment (macOS)</title></head>
<body style="font-family: sans-serif; padding: 2rem;">
    <h2>Dev Environment Active (macOS)</h2>
    <p>Current PHP Version: <b><?php echo phpversion(); ?></b></p>
    <ul>
        <li><a href="http://localhost:8056">Port 8056 (PHP 5.6)</a></li>
        <li><a href="http://localhost:8074">Port 8074 (PHP 7.4)</a></li>
        <li><a href="http://localhost:8082">Port 8082 (PHP 8.2)</a></li>
        <li><a href="http://localhost:8083">Port 8083 (PHP 8.3)</a></li>
        <li><a href="http://localhost:8084">Port 8084 (PHP 8.4)</a></li>
    </ul>
    <hr>
    <?php phpinfo(); ?>
</body>
</html>
