
function Export-InactiveAzureUsers {

    param(
        [Parameter (Mandatory = $false)] $filepath,
        [Parameter (Mandatory = $true)] $accounttype,
        [Parameter (Mandatory = $true)] $inactivemonths,
        [Parameter (Mandatory = $true)] $createddate

    )

        
        $getdate = (Get-Date).AddMonths(-$inactivemonths).ToString('yyyy-MM-dd')
        $creationdate = (Get-Date).AddMonths(-$createddate).ToString('yyyy-MM-dd')
        $userNames = @()


    ## GET PACKAGEPROVIDER
    $PackageProvider = "NuGet"
    if ((Get-PackageProvider -Name $PackageProvider -ListAvailable -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host -f yellow "- Installing PackageProvider $PackageProvider ..."
    if ((Install-PackageProvider -Name $PackageProvider -Force -ErrorAction SilentlyContinue) -eq $null) {
        Write-Host -f red "- Could not install PackageProvider $PackageProvider !!!"
        Write-Host -f red "ERROR"
        exit 1002
    }
    }
     
    else {
    Write-Host -f green "- PackageProvider $PackageProvider already installed ..."
    }

 

    ## GET MODULE AzureADPreview
    $ModuleName = "azureadpreview"
    if ((Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host -f yellow "- Installing Module $ModuleName ..."
    Install-Module -Name $ModuleName -Force
    } 

    else {
    Write-Host -f green "- Module $ModuleName already installed ..."
    }

 

    if ((Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host -f yellow "- Importing Module $ModuleName ..."
    Import-Module -Name $ModuleName -ErrorAction SilentlyContinue
    }

    else {
    Write-Host -f green "- Module $ModuleName already loaded ..."
    }

 

    if ((Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host -f red "- Could not load Module !!!"
    Write-Host -f red "ERROR"
    exit 1001
    }


    #Check if Already Connected to AzureAD  

    try { 
        $Tennantdetail = Get-AzureADTenantDetail 
    } 
        catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
        }

            if($Tennantdetail -eq $null){
            Write-Host "You're not connected to AzureAD";
            Connect-AzureAD | Out-Null
            }

            elseif($Tennantdetail -ne $null){
            $tennantname = $Tennantdetail.DisplayName 
            Write-Host "You are Connected to the folwoing Azure-AD Tennant: ${tennantname}" -ForegroundColor Yellow 
            $reconnect = $(write-host "If you wish to connect to a Other Tennant write [Yes]:" -ForegroundColor DarkYellow -NoNewline; Read-Host)
            }


                if($reconnect -eq "Yes"){

                Disconnect-AzureAD | Out-Null
                Connect-AzureAD | Out-Null
                
                }


        #Get all Singings for All AzureUsers and als AzureAD users

        $azadusers = Get-AzureADUser -top 1000 | Where-Object {$_.usertype -eq $accounttype}


        $signins = Get-AzureADAuditSignInLogs

        #Get all 

    foreach($azaduser in $azadusers){

        $azureaduser = $azaduser.objectid

        $getuserlogons = $signins | Where-Object {$_.userid -eq $azureaduser -and $_.createddatetime -eq $getdate} | Sort-Object createddatetime -Descending | Select-Object -First 1 

        if ($getuserlogons -ne $null){
            
            $UserNames += $getuserlogons.userid



        }

        elseif($getuserlogons -eq $null){

        $null += $getuserlogons.UserId

        }





    }

    #Compare Log an Users with eachother

    foreach($userName in $userNames){

        $users = $azadusers | Where-Object {$_.objectid -eq $userName -and $_.UserStateChangedOn -lt $creationdate} | Select-Object -Property displayname, Mail, UserStateChangedOn, objectid 
        
    }


    #export said Users 

    if($filepath -ne $null){

    $users | Export-Csv -Path $filepath -Encoding UTF8 -NoTypeInformation



    write-host "$($users.length) User wurden in ein CSV nach ${filepath} exportiert" -ForegroundColor Yellow

    }

    elseif($filepath -eq $null -and $users -ne $null){

    Write-Host "Folgende Benutzer vom Typ '${accounttype}' hat die Funktion gefunden:" -ForegroundColor DarkYellow
    $users | Write-Output 

    }

    elseif($users -eq $null){

    Write-Host "Es wurde kein Nutzer gefunden mit folgenden Suchvariablen:" -ForegroundColor Red
    Write-Host "Accounttyp: '${accounttype}'" -ForegroundColor Yellow
    Write-Host "Erstellungsdatum vor: '${creationdate}'" -ForegroundColor Yellow
    Write-Host "Inaktiv vor folgendem Datum: '${getdate}'" -ForegroundColor Yellow

    }

    else{
    Write-Host "Fehler beim Export oder bei Nutzersausgabe" -ForegroundColor DarkRed
    exit 1001
    }

}



