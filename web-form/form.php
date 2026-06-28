<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <title>Formulario</title>
        <link rel="stylesheet" href="form.css">
    </head> 
    <body>

        <h3>¡Anímate!</h3>
        <form action="procesar.php" method="post">
            <div class="form-group">
                <label for="username">
                <input type="text" name="name" placeholder="Nombre">
            </div>
            <div class="form-group">
                <label for="surname">
                <input type="text" name="surname" placeholder="Apellido">
            </div>
            <div class="form-group">
                <label for="address">
                <input type="text" name="address" placeholder="Dirección">
            </div>
            <div class="form-group">
                <label for="telephone">
                <input type="text" name="telephone" placeholder="Teléfono">
            </div>
            <div class="form-group">
                <label for="district">
                <input type="text" name="district" id="district" placeholder="Población">
            </div>
            <div class="form-group">
                <label for="state">
                <input type="text" name="state" placeholder="Provincia">
            </div>
            <input type="submit" name="submit" value="Enviar">
        </form>
    </body>
</html>