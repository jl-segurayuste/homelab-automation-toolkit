<?php
// Conexion a la base de datos a partir de la configuracion (config.php / entorno).
// Reemplaza al antiguo 'conexionindex.php' que tenia credenciales incrustadas.
$configFile = __DIR__ . '/config.php';
$cfg = file_exists($configFile)
    ? require $configFile
    : require __DIR__ . '/config.example.php';

$conn = new mysqli($cfg['host'], $cfg['user'], $cfg['pass'], $cfg['name']);

if ($conn->connect_error) {
    http_response_code(500);
    die('Conexion fallida con la base de datos.');
}
