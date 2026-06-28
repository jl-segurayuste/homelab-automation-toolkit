<?php
// Plantilla de configuracion de la base de datos.
// Copia este archivo a 'config.php' (gitignored) y ajusta los valores,
// o define las variables de entorno correspondientes.
return [
    'host' => getenv('DB_HOST') ?: 'localhost',
    'user' => getenv('DB_USER') ?: 'app_user',
    'pass' => getenv('DB_PASS') ?: '',          // NUNCA dejar credenciales en el codigo
    'name' => getenv('DB_NAME') ?: 'app_demo',
];
