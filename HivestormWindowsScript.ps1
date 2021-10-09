
##Asks for user input to change passwords##
$passwd = Read-Host "Enter a password for ALL users...use changeMe!123 as the password" -AsSecureString

##Gets list of all local users by Name##
$users = Get-LocalUser | Select Name


##Changes Password for ALL users##
ForEach ($entry in $users) {
    $username = ($entry.Name)
    
    Set-LocalUser -Name $username -Password $passwd
    Write-output "$username Password Updated!"

}


##Asks if you want to delete each user in the list##

Write-output " "
Write-output "BE CAREFUL WITH THIS NEXT SECTION, IT IS ASKING ABOUT DELETING ACCOUNTS!"
Write-output "DO NOT DELETE LOCAL DEFAULT/SYSTEM ACCOUNTS!!! EX. Administrator, defaultuser, etc."
Write-output " "
ForEach ($entry in $users) {
    $username = ($entry.Name)

    Write-Output " "

    $deleteUser = Read-Host "Delete $username account: Y/N"

    if ($deleteUser -eq "Y") {
        ##Confirms user deletion##
        $confirmDelete = Read-Host "Are you sure you want to delete $username ? Y/N"
        if ($confirmDelete -eq "Y"){
            Remove-LocalUser -Name $username
            Write-output "Account deleted"
        }
    }

}


##Gets a list of current admin users and asks if they should be local users instead##
Write-Output " "
Write-output "DO NOT REMOVE ADMIN PRIVILAGES FOR LOCAL DEFUALT/SYSTEM ACCOUNTS!!! Ex. Administrator"
Write-output " "
$adminUsers = Get-LocalGroupMember -Group "Administrators" | Select Name
ForEach ($entry in $adminUsers) {
    $username = ($entry.Name)

    Write-Output " "

    $makeLocalAdmin = Read-Host "Make $username a local account: Y/N"

    if ($makeLocalAdmin -eq "Y"){
    Remove-LocalGroupMember -Group "Administrators" -Member $username
    Write-output "$username is not an Admin"
    }

}

Write-output " "

##Change minimum password length setting to 12##
net accounts /minpwlen:12
Write-output "Minimum password length is now 12"

##Change maximum password age setting to 30##
net accounts /maxpwage:30
Write-output "Maximum password age is now 30 days"

##Change lockout duration setting to 60 minutes##
net accounts /lockoutduration:60
Write-output "Locout duration is now 60 minutes"

##Change lockout observation window to 60 minutes##
net accounts /lockoutwindow:60
Write-output "Lockout window is now 60 minutes"

##Change lockout threshold to 5##
net accounts /lockoutthreshold:5
Write-output "Lockout threshold is now 5"

##Change length of password history maintained to 5##
net accounts /uniquepw:12
Write-output "Length of password history maintained is now 5"

##Check for Firewall profiles...will probably be Domain, Private, Public##
Write-Output "Checking current status of Firewalls..."
Get-NetFirewallProfile | Format-Table Name, Enabled

##Enable Firewall for Domain, Private, and Public profiles##
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
Write-output "Firewalls enabled"

##Confirm Firewall is enabled...everything should have Enabled set to true##
Write-output "Double check Firewall status...all Enabled should be true"
Get-NetFirewallProfile | Format-Table Name, Enabled
