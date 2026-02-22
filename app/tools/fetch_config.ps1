# test_vpn_peer.ps1
# PowerShell 7 script to login, create peer, and fetch WireGuard config
$ErrorActionPreference = 'Stop'

# === Настройки ===
$baseUrl = "http://146.103.99.70:8000"
$email = "test+local@example.com"
$password = "Password1!"
$deviceName = "powershell-test-device"
$autoRegisterIfMissing = $true

# === Функции ===
function PrettyPrint($label, $obj) {
    Write-Host "---- $label ----"
    if ($null -eq $obj) { Write-Host "<null>"; return }
    try { $json = $obj | ConvertTo-Json -Depth 10; Write-Host $json } catch { Write-Host $obj.ToString() }
}

function DoRegister {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    try {
        $reg = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/register" -ContentType 'application/json' -Body $body -ErrorAction Stop
        PrettyPrint "REGISTER RESPONSE" $reg
        return $true
    } catch {
        Write-Host "REGISTER ERROR:"
        if ($_.Exception.Response) {
            $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
            $b = $sr.ReadToEnd()
            Write-Host "Status:" ($_.Exception.Response.StatusCode.value__)
            Write-Host "Body:" $b
        } else { Write-Host $_.Exception.Message }
        return $false
    }
}

# === LOGIN ===
$loginBody = @{ email = $email; password = $password } | ConvertTo-Json
try {
    $loginResp = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/login" -ContentType 'application/json' -Body $loginBody -ErrorAction Stop
    PrettyPrint "LOGIN RESPONSE" $loginResp
} catch {
    Write-Host "LOGIN ERROR:"
    if ($_.Exception.Response) {
        $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        $b = $sr.ReadToEnd()
        Write-Host "Status:" ($_.Exception.Response.StatusCode.value__)
        Write-Host "Body:" $b

        if ($autoRegisterIfMissing) {
            Write-Host "`nПопытка регистрации пользователя..."
            if (DoRegister) {
                Write-Host "Регистрация выполнена, пробуем логин ещё раз..."
                Start-Sleep -Seconds 1
                try {
                    $loginResp = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/login" -ContentType 'application/json' -Body $loginBody -ErrorAction Stop
                    PrettyPrint "LOGIN RESPONSE (after register)" $loginResp
                } catch {
                    Write-Host "Повторный login не удался:"
                    if ($_.Exception.Response) {
                        $sr2 = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                        Write-Host $sr2.ReadToEnd()
                    } else { Write-Host $_.Exception.Message }
                    exit 1
                }
            } else {
                Write-Host "Регистрация не удалась, прерываю."
                exit 1
            }
        } else { exit 1 }
    } else { Write-Host $_.Exception.Message; exit 1 }
}

# === Извлечение токена ===
$token = $null
if ($loginResp -is [System.Collections.IDictionary]) {
    if ($loginResp.ContainsKey('access_token')) { $token = $loginResp['access_token'] }
    elseif ($loginResp.ContainsKey('access')) { $token = $loginResp['access'] }
    elseif ($loginResp.ContainsKey('token')) { $token = $loginResp['token'] }
    elseif ($loginResp.ContainsKey('detail') -and $loginResp['detail'] -is [string]) { $token = $loginResp['detail'] }
} elseif ($loginResp -is [string]) { $token = $loginResp }

if (-not $token) { Write-Host "Не удалось получить access_token из ответа логина. Прерываю."; exit 1 }
Write-Host "---- TOKEN (truncated) ----"
Write-Host ($token.Substring(0, [Math]::Min(40, $token.Length)) + "...")

# === CREATE PEER ===
$peerBody = @{ device_name = $deviceName } | ConvertTo-Json
try {
    $peer = Invoke-RestMethod -Method Post -Uri "$baseUrl/vpn_peers/self" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body $peerBody -ErrorAction Stop
    PrettyPrint "PEER CREATED" $peer
} catch {
    Write-Host "PEER CREATE ERROR:"
    if ($_.Exception.Response) {
        $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        $b = $sr.ReadToEnd()
        Write-Host "Status:" ($_.Exception.Response.StatusCode.value__)
        Write-Host "Body:" $b
    } else { Write-Host $_.Exception.Message }
    exit 1
}

# === FETCH CONFIG ===
try {
    Write-Host "`nПопытка GET /vpn_peers/self/config ..."
    $cfgGet = Invoke-RestMethod -Method Get -Uri "$baseUrl/vpn_peers/self/config" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
    PrettyPrint "CONFIG (GET)" $cfgGet
} catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "CONFIG GET -> 404 (No stored config). Попробуем POST fallback..."
        try {
            $cfgPost = Invoke-RestMethod -Method Post -Uri "$baseUrl/vpn_peers/self/config" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $token" } -Body '{}' -ErrorAction Stop
            PrettyPrint "CONFIG (POST fallback)" $cfgPost
        } catch {
            Write-Host "CONFIG POST ERROR:"
            if ($_.Exception.Response) {
                $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $b = $sr.ReadToEnd()
                Write-Host "Status:" ($_.Exception.Response.StatusCode.value__)
                Write-Host "Body:" $b
            } else { Write-Host $_.Exception.Message }
            exit 1
        }
    } else {
        Write-Host "CONFIG GET ERROR:"
        if ($_.Exception.Response) {
            $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
            $b = $sr.ReadToEnd()
            Write-Host "Status:" ($_.Exception.Response.StatusCode.value__)
            Write-Host "Body:" $b
        } else { Write-Host $_.Exception.Message }
        exit 1
    }
}

Write-Host "`nСкрипт завершил выполнение."
