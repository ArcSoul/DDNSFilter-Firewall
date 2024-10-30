# DDNS Filter Windows Firewall

## Descripción

Hola, este es un programa que ayuda permitir o bloquear ddns en el firewall de windows.
Muchos de nosotros no sabemos que es un ddns, y es que esto nos facilita
poder tener un dominio cuando nuestra ip es dinámica, ¿para qué nos serviría tener un
dominio?, pues nos puede servir para varias cosas, como encender una computadora a distancia,
acceder a algo con solo nuestra ddns que no podríamos también con nuestra ip dinámica, pero
tendríamos que estar cambiándola cada cierto tiempo y es una molestia, en especial cuando tienes
un vps. Existen servicios como No-Ip que nos facilitan los DDNS gratuitos.

## ¿Cómo funciona el script?

He dejado casi totalmente comentado, asi que no debería haber muchas partes donde te pierdas,
pero en resumen lo que hace es obtener tu ip desde el ddns, luego crear una regla de firewall,
con el siguiente nombre 'dominio-puerto', y cada cierto tiempo válido si la ip ha cambiado,
si cambia entonces se borra la regla anterior y se crea una nueva, los logs se guardan en la carpeta
'logs' y se envía un correo cada que cambia la ip para saber el estado del ddns. También se almacenan
en la carpeta 'logs' los archivos, currentDate.txt y ultimaFechaReporte.txt, donde en el primero se usa
para mantener la fecha actual de los logs y si cambia se archive en una carpeta por fechas, luego
el segundo es para guardar la fecha de los últimos reportes, estos reportes se hacen semanales
y es para saber los cambios en las reglas de ddns que hubo relacionado con la configuración proporcionada

## ¿Cómo funciona el archivo de configuración?

Existe un archivo de configuración donde vamos a poder configurar casi todo respecto al programa,
comencemos:

### General

```
intervaloVerificacion -> Tiempo en segundos que va a hacer la comprobación de la ip en los ddns
rutaLogs              -> Ruta relativa de la carpeta donde estaran los logs
```

### Dominios

```
dominio1  -> tu dominio DDNS o host name
dominio2  -> y asi sucesivamente hasta el que tu quieras
...
dominio99
```

### Puertos

```
puerto1 -> el puerto al que quieres acceder o bloquear
```

### Reglas

```
; Solo dos reglas estan permitidas allow y deny, allow para permitir acceso y deny para bloquear acceso.
dominio1.puerto1.accion -> esto esta compuesto del dominioX y puertoX, donde X viene a ser el numero que pusiste para referencia
```

### Correo

```
servidorSMTP       -> Servidor smtp ahi deje por defecto al de gmail  
puertoSMTP         -> Puerto smtp ahi deje por defecto de el gmail tambien
usuarioSMTP        -> el correo desde donde vas a enviar los correos 
claveSMTP          -> la clave de aplicaciones, OJO, no es la clave del correo, si tu manejas doble factor o cosas asi, la clave del correo te va a dar errores, por eso mejor maneja clave de aplicaciones
correoRemitente    -> correo desde donde dira que se envio el correo 
correoDestinatario -> correo donde queremos que nos llegue el correo
```

## Créditos

Anthony Rosas o gambasoxd
