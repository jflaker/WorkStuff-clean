# Import participants from CSV
$participants = Import-Csv "santas.csv"

# Function to generate Secret Santa pairs
function Get-SecretSantaPairs {
    $shuffled = $participants | Sort-Object {Get-Random}
    $matches = @{}

    # Keep shuffling until no one is assigned themselves
    do {
        $shuffled = $participants | Sort-Object {Get-Random}
        $valid = $true

        for ($i = 0; $i -lt $participants.Count; $i++) {
            if ($participants[$i].Name -eq $shuffled[$i].Name) {
                $valid = $false
                break
            }
        }
    } until ($valid)

    # Assign pairs
    for ($i = 0; $i -lt $participants.Count; $i++) {
        $matches[$participants[$i].Name] = $shuffled[$i]
    }

    return $matches
}

# Generate assignments
$matches = Get-SecretSantaPairs

# Send emails
foreach ($pair in $matches.GetEnumerator()) {
    $subject = "Your Secret Santa Assignment!"
    $body = "Hello $($pair.Key), you are Secret Santa for $($pair.Value.Name)! Happy gifting! 🎁"
    $recipient = $participants | Where-Object { $_.Name -eq $pair.Key } | Select-Object -ExpandProperty Email
    
    Send-MailMessage -To $recipient -From "your-email@example.com" -Subject $subject -Body $body -SmtpServer "smtp.example.com"
}

Write-Output "Secret Santa assignments have been emailed!"
