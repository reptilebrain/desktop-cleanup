#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$SourcePath = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -ErrorAction Stop

# Analyze production scripts only; never execute them. Do not filter Severity:
# parser errors must be included alongside the standard rule diagnostics.
$scripts = @(Get-ChildItem -LiteralPath $SourcePath -Filter '*.ps1' -File)
if ($scripts.Count -eq 0) { throw "No production scripts found in $SourcePath" }
$findings = @($scripts | ForEach-Object {
    Invoke-ScriptAnalyzer -Path $_.FullName -ErrorAction Stop
})
$findings | Format-Table ScriptName, Line, Severity, RuleName, Message -Wrap
$blocking = @($findings | Where-Object { $_.Severity -in @('Warning', 'Error', 'ParseError') })
if ($blocking.Count -gt 0) {
    throw "Code analysis failed: $($blocking.Count) warning(s), error(s), or parser error(s)."
}
Write-Output "Code analysis passed for $($scripts.Count) production scripts."
