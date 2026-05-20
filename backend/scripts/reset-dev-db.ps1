param(
    [switch]$Empty,
    [switch]$AllowProduction
)

$arguments = @("run", "./cmd/resetdb", "--yes")

if ($Empty) {
    $arguments += "--empty"
}

if ($AllowProduction) {
    $arguments += "--allow-production"
}

go @arguments
