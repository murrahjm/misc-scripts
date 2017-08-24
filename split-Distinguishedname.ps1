Function split-DistinguishedName {
    param(
        [switch]$Parent,
        [switch]$CN,
        [string]$dn
    )
    $parts = $dn -split '(?<![\\]),' 
    if ($Parent) {$parts[1..$($parts.Count-1)] -join ','}
    if ($CN) {$parts[0]}
}
