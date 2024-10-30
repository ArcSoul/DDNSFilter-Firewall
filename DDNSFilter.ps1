# Obtener la ruta del script para manejar rutas relativas
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Leer archivo .ini de configuración
function Leer-Configuracion
{
    param (
        [string]$configFile
    )
    $config = @{
        dominios = @{ }
        puertos = @{ }
        reglas = @{ }
        intervaloVerificacion = 600
        rutaLogs = "logs"
        archivoIPs = "IP_DB.txt"
        correo = @{
            servidorSMTP = ""
            puertoSMTP = 587
            usuarioSMTP = ""
            claveSMTP = ""
            correoRemitente = ""
            correoDestinatario = ""
        }
    }

    if (Test-Path $configFile)
    {
        try
        {
            $iniContent = Get-Content $configFile
            $currentSection = ""

            foreach ($linea in $iniContent)
            {
                $linea = $linea.Trim()

                # Ignorar líneas vacías o comentarios
                if ($linea -match "^\s*($|;|#)")
                {
                    continue
                }

                # Detectar secciones
                if ($linea -match '^\[(.+)\]$')
                {
                    $currentSection = $matches[1]
                    continue
                }

                # Separar claves y valores
                if ($linea -match '^(.*?)=(.*)$')
                {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()

                    switch ($currentSection)
                    {
                        "General" {
                            if ($key -eq "intervaloVerificacion")
                            {
                                $config.intervaloVerificacion = [int]$value
                            }
                            if ($key -eq "rutaLogs")
                            {
                                $config.rutaLogs = $value
                            }
                            if ($key -eq "archivoIPs")
                            {
                                $config.archivoIPs = $value
                            }
                        }
                        "Dominios" {
                            $config.dominios[$key] = $value
                        }
                        "Puertos" {
                            $config.puertos[$key] = [int]$value
                        }
                        "Reglas" {
                            # Separar clave en dominio, puerto y accion
                            $parts = $key -split '\.'
                            $dominio = $parts[0]
                            $puerto = $parts[1]
                            $accion = $parts[2]

                            # Obtener el dominio y puerto a partir de las referencias
                            $dominioValor = $config.dominios[$dominio]
                            $puertoValor = $config.puertos[$puerto]

                            # Almacenar la regla usando dominio, puerto y acción
                            $config.reglas["$dominioValor@@$puertoValor"] = $value
                        }
                        "Correo" {
                            if ($key -eq "servidorSMTP")
                            {
                                $config.correo.servidorSMTP = $value
                            }
                            if ($key -eq "puertoSMTP")
                            {
                                $config.correo.puertoSMTP = [int]$value
                            }
                            if ($key -eq "usuarioSMTP")
                            {
                                $config.correo.usuarioSMTP = $value
                            }
                            if ($key -eq "claveSMTP")
                            {
                                $config.correo.claveSMTP = $value
                            }
                            if ($key -eq "correoRemitente")
                            {
                                $config.correo.correoRemitente = $value
                            }
                            if ($key -eq "correoDestinatario")
                            {
                                $config.correo.correoDestinatario = $value
                            }
                        }
                    }
                }
            }
        }
        catch
        {
            # Manejo de errores y registro en logs
            $errorDetails = $_.Exception.Message
            Escribir-Log "Error leyendo el archivo de configuración: $errorDetails" "error"
        }
        return $config
    }
    else
    {
        Escribir-Log "Archivo de configuración no encontrado: $configFile" "error"
    }
}

# Función para escribir en el log (tanto en consola como en archivo)
function Escribir-Log
{
    param (
        [string]$mensaje,
        [string]$tipo = "info"
    )
    # Establecer la codificación de salida de la consola a UTF-8
    [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()


    # Asegurarse de que PowerShell use UTF-8 para la consola
    chcp 65001 > $null

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$tipo] $mensaje"

    # Verificar si la ruta de logs está definida
    if (-not $config.rutaLogs)
    {
        [Console]::WriteLine("Error: 'rutaLogs' no está definido en el archivo de configuración.")
        return
    }

    # Verificar y crear la carpeta de logs si no existe
    if (-not (Test-Path "$scriptPath\$( $config.rutaLogs )"))
    {
        try
        {
            New-Item -Path "$scriptPath\$( $config.rutaLogs )" -ItemType Directory | Out-Null
            [Console]::WriteLine("Carpeta de logs creada en: $scriptPath\$( $config.rutaLogs )")
        }
        catch
        {
            [Console]::WriteLine("Error al crear la carpeta de logs: $_")
            return
        }
    }

    try
    {
        # Escribir en el archivo correspondiente según el tipo de log, con codificación UTF8
        if ($tipo -eq "error")
        {
            Add-Content -Path "$scriptPath\$( $config.rutaLogs )\errors.txt" -Value $logEntry -Encoding UTF8
        }
        else
        {
            Add-Content -Path "$scriptPath\$( $config.rutaLogs )\logs.txt" -Value $logEntry -Encoding UTF8
        }
    }
    catch
    {
        [Console]::WriteLine("Error al escribir en el archivo de logs: $_")
    }

    [Console]::WriteLine($logEntry)
}

# Función para enviar notificaciones por correo utilizando la configuración del archivo .ini
function Enviar-NotificacionCorreo
{
    param (
        [string]$asunto,
        [string]$cuerpo
    )

    try
    {
        $smtpServer = $config.correo.servidorSMTP
        $puertoSMTP = $config.correo.puertoSMTP
        $usuarioSMTP = $config.correo.usuarioSMTP
        $claveSMTP = $config.correo.claveSMTP
        $from = $config.correo.correoRemitente
        $to = $config.correo.correoDestinatario

        $securePassword = ConvertTo-SecureString $claveSMTP -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $usuarioSMTP, $securePassword

        Send-MailMessage -SmtpServer $smtpServer -Port $puertoSMTP -Credential $credential -From $from -To $to -Subject $asunto -Body $cuerpo -UseSsl
    }
    catch
    {
        # Manejo de errores y registro en logs
        $errorDetails = $_.Exception.Message
        Escribir-Log "Error al enviar la notificación por correo: $errorDetails" "error"
    }
}

# Guardar las IPs actuales en el archivo de texto, separando dominio y puerto con un espacio
function Guardar-IPsPrevias
{
    param (
        [hashtable]$ipsAnteriores,
        [string]$ipsFile
    )

    $lines = @()
    foreach ($key in $ipsAnteriores.Keys)
    {
        foreach ($ip in $ipsAnteriores[$key])
        {
            # Separamos el dominio y el puerto por un espacio
            $parts = $key -split '-'
            $dominio = $parts[0]
            $puerto = $parts[1]
            $lines += "$dominio $puerto $ip"
        }
    }
    $lines | Set-Content -Path $ipsFile
}

# Función para mover los logs a una subcarpeta si el día ha cambiado
function Mover-Logs-Si-Cambio-Dia
{
    param (
        [string]$rutaLogs
    )

    try
    {
        # Obtener la fecha actual
        $newDate = Get-Date -Format "dd-MM-yyyy"

        # Verificar si la variable $currentDate ya existe (se debe inicializar en alguna parte del script)
        if (-not (Test-Path "$rutaLogs\currentDate.txt"))
        {
            # Crear un archivo temporal que mantenga la fecha actual
            Set-Content -Path "$rutaLogs\currentDate.txt" -Value $newDate
            $currentDate = $newDate
            Escribir-Log "Archivo currentDate.txt creado con fecha actual: $currentDate" "info"
        }
        else
        {
            # Leer la fecha guardada en el archivo
            $currentDate = Get-Content "$rutaLogs\currentDate.txt"
        }

        # Si la fecha ha cambiado, movemos los logs
        if ($newDate -ne $currentDate)
        {
            $subcarpeta = "$rutaLogs\$currentDate"
            if (-not (Test-Path $subcarpeta))
            {
                New-Item -Path $subcarpeta -ItemType Directory | Out-Null
                Escribir-Log "Subcarpeta de logs creada: $subcarpeta" "info"
            }

            # Mover logs actuales a la subcarpeta con la fecha anterior
            if (Test-Path "$rutaLogs\logs.txt")
            {
                Move-Item "$rutaLogs\logs.txt" "$subcarpeta\logs.txt"
                Escribir-Log "Moviendo logs.txt a $subcarpeta" "info"
            }

            if (Test-Path "$rutaLogs\errors.txt")
            {
                Move-Item "$rutaLogs\errors.txt" "$subcarpeta\errors.txt"
                Escribir-Log "Moviendo errors.txt a $subcarpeta" "info"
            }

            # Actualizar la fecha para el nuevo día
            Set-Content -Path "$rutaLogs\currentDate.txt" -Value $newDate
            Escribir-Log "Actualizando archivo currentDate.txt con la nueva fecha: $newDate" "info"
        }
        else
        {
            Escribir-Log "El día no ha cambiado. No se mueven los logs." "info"
        }

    }
    catch
    {
        # Manejo de errores y registro en logs
        $errorDetails = $_.Exception.Message
        Escribir-Log "Error al mover los logs o crear subcarpetas: $errorDetails" "error"
    }
}

# Función para obtener la IP actual de un dominio con reintentos
function Get-IPFromDomain
{
    param (
        [string]$domain,
        [int]$maxAttempts = 3
    )

    $attempt = 0
    $ip = $null

    while ($attempt -lt $maxAttempts -and $ip -eq $null)
    {
        try
        {
            # Obtener todas las direcciones IP asociadas con el dominio (IPv4)
            $ip = [System.Net.Dns]::GetHostAddresses($domain) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        }
        catch
        {
            Escribir-Log "Error al resolver el dominio $domain en el intento $attempt de $( $maxAttempts ): $_" "error"
        }

        Start-Sleep -Seconds 5  # Esperar antes de volver a intentar
        $attempt++
    }

    if ($ip -eq $null)
    {
        Escribir-Log "No se pudo resolver la IP para $domain después de $maxAttempts intentos." "error"
    }

    return $ip
}

# Función para verificar el tamaño del archivo de log y moverlo si excede un límite
function Verificar-Tamano-Logs
{
    param (
        [string]$logPath, # Ruta del archivo de log a verificar
        [int]$maxSizeMB = 10  # Tamaño máximo permitido en MB antes de mover
    )

    try
    {
        # Verificar si el archivo de log existe; si no, crearlo vacío
        if (-not (Test-Path $logPath))
        {
            Escribir-Log "El archivo de log $logPath no existe. Se creará uno nuevo." "info"
            New-Item -Path $logPath -ItemType File | Out-Null
        }

        $maxSizeBytes = $maxSizeMB * 1MB
        $logSize = (Get-Item $logPath).Length

        # Verificar si el tamaño del archivo excede el límite
        if ($logSize -gt $maxSizeBytes)
        {
            $newPath = "$logPath-$( Get-Date -Format 'yyyyMMdd_HHmmss' )"
            Move-Item $logPath $newPath
            Escribir-Log "El log ha sido movido a $newPath por exceder el tamaño de $maxSizeMB MB" "info"
        }
    }
    catch
    {
        Escribir-Log "Error al verificar o mover el archivo de log $( $logPath ): $_" "error"
    }
}

# Función para crear o actualizar una regla de firewall basada en IP
function CrearActualizarReglaFirewall
{
    param (
        [string]$ipAddress, # Dirección IP que queremos aplicar en la regla
        [string]$domain, # Nombre del dominio (utilizado en el nombre de la regla)
        [int]$puerto, # Puerto al que se aplicará la regla
        [string]$accion      # Acción a aplicar (allow o block)
    )

    try
    {
        # Verificar si ya existe una regla de firewall con el nombre basado en el dominio y puerto
        $existingRule = Get-NetFirewallRule -DisplayName "$domain-$puerto" -ErrorAction SilentlyContinue

        if ($existingRule)
        {
            # Obtener las direcciones remotas asociadas a la regla existente
            $existingRemoteAddresses = (Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $existingRule).RemoteAddress

            # Verificar si la IP ya está incluida en la regla
            if ($existingRemoteAddresses -contains $ipAddress)
            {
                Escribir-Log "La IP $ipAddress ya está configurada en la regla para $domain en el puerto $puerto. No es necesaria una actualización." "info"
                return
            }
            else
            {
                # Actualizar la regla existente con la nueva IP
                Set-NetFirewallRule -DisplayName "$domain-$puerto" -RemoteAddress $ipAddress
                Enviar-NotificacionCorreo -asunto "[Alerta] Firewall DDNS Filter: IP cambiada" -cuerpo "La IP para el dominio $domain ha cambiado."
                Escribir-Log "Actualizando la regla para $domain en el puerto $puerto con la nueva IP: $ipAddress" "info"
            }
        }
        else
        {
            # Si no existe la regla, crear una nueva
            if ($accion -eq "allow")
            {
                New-NetFirewallRule -DisplayName "$domain-$puerto" -Direction Inbound -RemoteAddress $ipAddress -Protocol TCP -LocalPort $puerto -Action Allow
                Escribir-Log "Creando nueva regla ALLOW para $domain en el puerto $puerto con la IP $ipAddress" "info"
            }
            elseif ($accion -eq "block")
            {
                New-NetFirewallRule -DisplayName "$domain-$puerto" -Direction Inbound -RemoteAddress $ipAddress -Protocol TCP -LocalPort $puerto -Action Block
                Escribir-Log "Creando nueva regla BLOCK para $domain en el puerto $puerto con la IP $ipAddress" "info"
            }
            else
            {
                Escribir-Log "Acción desconocida '$accion' para $domain en el puerto $puerto. No se creó ninguna regla." "error"
            }
        }

    }
    catch
    {
        # Capturar y registrar cualquier error
        $errorDetails = $_.Exception.Message
        Escribir-Log "Error al crear o actualizar la regla de firewall para $domain en el puerto $( $puerto ): $errorDetails" "error"
    }
}

# Generar reporte semanal
# Función para generar un reporte semanal solo para las reglas creadas por el script
function Generar-ReporteSemanal
{
    # Ruta del archivo que almacena la última fecha de generación de reporte
    $fechaReportePath = "$scriptPath\$( $config.rutaLogs )\ultimaFechaReporte.txt"

    # Obtener la fecha actual
    $fechaActual = Get-Date
    $ultimaFechaReporte = $null

    # Leer la última fecha de reporte si existe
    if (Test-Path $fechaReportePath)
    {
        $ultimaFechaReporte = Get-Content $fechaReportePath | Out-String
        $ultimaFechaReporte = [datetime]::ParseExact($ultimaFechaReporte.Trim(), "yyyy-MM-dd", $null)
    }

    # Calcular si ha pasado una semana desde el último reporte
    if (-not $ultimaFechaReporte -or ($fechaActual -gt $ultimaFechaReporte.AddDays(7)))
    {
        try
        {
            $reportePath = "$scriptPath\$( $config.rutaLogs )\reporte-semanal-$($fechaActual.ToString('yyyy-MM-dd') ).txt"

            # Filtrar las reglas que han sido creadas por el script (por ejemplo, aquellas que tienen el prefijo "DDNSFilter-")
            $reglasCreadas = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "DDNSFilter-*" }

            # Generar el contenido del reporte
            $reporte = "Reporte Semanal - Fecha: $fechaActual" + "`n`n"
            $reporte += "Reglas de firewall creadas por el script:" + "`n"
            $reporte += ($reglasCreadas | Format-Table -AutoSize | Out-String)

            # Guardar el reporte en un archivo de texto
            Add-Content -Path $reportePath -Value $reporte
            Escribir-Log "Reporte semanal generado en $reportePath" "info"

            # Actualizar la fecha del último reporte
            Set-Content -Path $fechaReportePath -Value $fechaActual.ToString("yyyy-MM-dd")
        }
        catch
        {
            # Manejo de errores
            $errorDetails = $_.Exception.Message
            Escribir-Log "Error al generar el reporte semanal: $errorDetails" "error"
        }
    }
    else
    {
        Escribir-Log "No ha pasado una semana desde el último reporte, no se genera nuevo reporte." "info"
    }
}

# Cargar configuración e IPs previas
$config = Leer-Configuracion -configFile "$scriptPath\config.ini"
$ipsAnteriores = @{ }

# Leer las IPs anteriores separando dominio y puerto
if (Test-Path "$scriptPath\$( $config.archivoIPs )")
{
    try
    {
        $lines = Get-Content "$scriptPath\$( $config.archivoIPs )"
        foreach ($line in $lines)
        {
            $parts = $line -split ' '
            $dominioPuerto = "$( $parts[0] )@@$( $parts[1] )"
            $ip = $parts[2]
            $ipsAnteriores[$dominioPuerto] = $ip
        }
    }
    catch
    {
        Escribir-Log "Error al leer el archivo de IPs previas: $_" "error"
    }
}

# Crear la carpeta de logs si no existe
if (-not (Test-Path "$scriptPath\$( $config.rutaLogs )"))
{
    try
    {
        New-Item -Path "$scriptPath\$( $config.rutaLogs )" -ItemType Directory | Out-Null
    }
    catch
    {
        Escribir-Log "Error al crear la carpeta de logs: $_" "error"
    }
}

# Variables para manejar la fecha actual
$currentDate = Get-Date -Format "dd-MM-yyyy"

# Comenzamos el bucle para ejecutar continuamente según el intervalo de verificación
while ($true)
{
    # Ejecutar una vez en lugar de un bucle infinito (para usar con Task Scheduler)
    Mover-Logs-Si-Cambio-Dia "$scriptPath\$( $config.rutaLogs )"

    foreach ($domain in $config.dominios.Values)
    {
        $currentIPs = Get-IPFromDomain -domain $domain
        if ($currentIPs)
        {
            foreach ($key in $config.reglas.Keys)
            {
                # Separar el dominio y puerto
                $parts = $key -split '@@'
                $puerto = [int]$parts[1]
                $accion = $config.reglas[$key]
                $previousIPs = $ipsAnteriores[$key]

                try
                {
                    # Si la IP ha cambiado o no hay IP almacenada
                    if ($previousIPs -ne $currentIPs)
                    {
                        if ($previousIPs)
                        {
                            Remove-NetFirewallRule -DisplayName "$domain-$puerto" -ErrorAction SilentlyContinue
                            Escribir-Log "Eliminando reglas anteriores para $domain en el puerto $puerto" "info"
                        }

                        foreach ($ip in $currentIPs)
                        {
                            CrearActualizarReglaFirewall -ipAddress $ip -domain $domain -puerto $puerto -accion $accion
                        }

                        $ipsAnteriores[$key] = $currentIPs
                        Guardar-IPsPrevias -ipsAnteriores $ipsAnteriores -ipsFile "$scriptPath\$( $config.archivoIPs )"
                    }
                    else
                    {
                        Escribir-Log "No hay cambios en las IPs para $domain en el puerto $puerto" "info"
                    }
                }
                catch
                {
                    # Guardamos el error en una variable temporal
                    $errorDetails = $_.Exception.Message

                    # Llamamos a la función Escribir-Log con la variable de error
                    Escribir-Log "Error durante la verificación o actualización de la IP para $( $domain ): $errorDetails" "error"
                }
            }
        }
        else
        {
            Escribir-Log "No se pudo resolver la IP para $domain" "error"
        }
    }

    Verificar-Tamano-Logs "$scriptPath\$( $config.rutaLogs )\logs.txt"
    Verificar-Tamano-Logs "$scriptPath\$( $config.rutaLogs )\errors.txt"

    # Generar el reporte semanal solo si corresponde
    Generar-ReporteSemanal

    # Pausar el script según el intervalo de verificación configurado
    Escribir-Log "Esperando $( $config.intervaloVerificacion ) segundos antes de la próxima verificación..." "info"
    Start-Sleep -Seconds $config.intervaloVerificacion
}