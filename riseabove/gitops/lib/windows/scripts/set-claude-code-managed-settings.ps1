# Writes Claude Code managed settings to HKLM\SOFTWARE\Policies\ClaudeCode, which standard users
# can't change. Same settings as lib/macos/configuration-profiles/claude-code-managed-settings.mobileconfig;
# keep the two in sync. Fleet replaces $FLEET_SECRET_CLAUDE_OTEL_TOKEN before the script runs.
# Re-run it after changing the settings; Fleet Free can't re-run it automatically.
$ErrorActionPreference = 'Stop'

$token = '$FLEET_SECRET_CLAUDE_OTEL_TOKEN'
if ($token.StartsWith('$')) {
    throw "Fleet secret CLAUDE_OTEL_TOKEN wasn't substituted."
}

$serial = [uri]::EscapeDataString((Get-CimInstance Win32_BIOS).SerialNumber.Trim())

$settings = [ordered]@{
    env = [ordered]@{
        CLAUDE_CODE_ENABLE_TELEMETRY    = '1'
        OTEL_METRICS_EXPORTER           = 'otlp'
        OTEL_EXPORTER_OTLP_PROTOCOL     = 'http/protobuf'
        OTEL_EXPORTER_OTLP_ENDPOINT     = 'https://otel.riseabovereality.com'
        OTEL_EXPORTER_OTLP_HEADERS      = "Authorization=Bearer $token"
        OTEL_METRICS_INCLUDE_SESSION_ID = 'false'
        OTEL_RESOURCE_ATTRIBUTES        = "host.serial=$serial"
    }
}
$json = $settings | ConvertTo-Json -Compress -Depth 5

$key = 'HKLM:\SOFTWARE\Policies\ClaudeCode'
if (-not (Test-Path $key)) {
    New-Item -Path $key -Force | Out-Null
}
New-ItemProperty -Path $key -Name 'Settings' -PropertyType String -Value $json -Force | Out-Null
Write-Output "Wrote Claude Code managed settings to $key"
