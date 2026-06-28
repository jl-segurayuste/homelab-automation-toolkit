<style><?php include __DIR__ . '/form.css'; ?></style>
<?php
// Procesa el envio del formulario. Escapa la salida con htmlspecialchars
// para evitar XSS (no confiar nunca en la entrada del usuario).
function campo(string $clave): string
{
    return htmlspecialchars($_POST[$clave] ?? '', ENT_QUOTES, 'UTF-8');
}

$campos = [
    'Nombre'    => 'name',
    'Apellido'  => 'surname',
    'Direccion' => 'address',
    'Telefono'  => 'telephone',
    'Localidad' => 'district',
    'Provincia' => 'state',
];

echo '<h3>Comprueba los datos enviados, por favor</h3>';
foreach ($campos as $etiqueta => $clave) {
    echo '<p>' . $etiqueta . ': <b>' . campo($clave) . '</b></p>';
}
