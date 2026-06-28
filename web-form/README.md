# web-form — formulario PHP didáctico

Ejemplo sencillo de formulario web en PHP: captura datos y los muestra de forma
segura. Pensado como material de aprendizaje (HTML + CSS + PHP + MySQL).

## Archivos

| Archivo | Función |
|---------|---------|
| `form.php` | Formulario HTML |
| `form.css` | Estilos |
| `procesar.php` | Procesa el envío y muestra los datos (salida escapada contra XSS) |
| `db.php` | Conexión a MySQL leyendo la configuración |
| `config.example.php` | Plantilla de configuración (copiar a `config.php`) |

## Uso

```bash
cp config.example.php config.php   # ajusta credenciales (o usa variables DB_*)
php -S localhost:8000              # servidor de desarrollo
# abre http://localhost:8000/form.php
```

## Notas de seguridad (buenas prácticas mostradas)

- **Sin credenciales en el código**: la conexión usa `config.php` (gitignored) o
  variables de entorno `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`.
- **Escape de salida** con `htmlspecialchars` para evitar XSS.
- Para persistir en BD, usa **sentencias preparadas** (`mysqli`/PDO), nunca
  concatenación de cadenas en SQL.
