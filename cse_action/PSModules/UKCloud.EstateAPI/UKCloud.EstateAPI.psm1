
Function Read-SintApiKey {
	Param(
	[Parameter(Mandatory)]$ImpactLevel
	)
	If ($ImpactLevel -match "Assured"){
		$securedValue = Read-Host -Prompt "Please enter your Assured SINT API Key:" -AsSecureString
	}
	ElseIf ($ImpactLevel -match "Elevated"){
		$securedValue = Read-Host -Prompt "Please enter your Elevated SINT API Key:" -AsSecureString
	}
	ElseIf ($ImpactLevel -match "Combined"){
		$securedValue = Read-Host -Prompt "Please enter your Elevated SINT API Key:" -AsSecureString
	}
	$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securedValue)
	$Global:SintAPIKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

###########################################################################################################################

Function Get-EApiCreds{
Param(
	$Change
)
	if($env:USERDOMAIN -match "IL2" -or $Global:Answer -match "Assured"){
		$Global:Answer = "Assured"
		if (!$SintAPIKey){
			Read-SintAPIKey -ImpactLevel $Global:Answer
		}
		if ($Change -match "True"){
			$Username,$Password = Get-SintCreds -CI "oss00001i2" -Username "cse-account-update" -Answer $Global:Answer -SintAPIKey $SintAPIKey
		}
		else{
			$Username,$Password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured" -Answer $Global:Answer -SintAPIKey $SintAPIKey
		}
	}
	elseif($env:USERDOMAIN -match "IL3" -or $Global:Answer -match "Elevated"){
		$Global:Answer = "Elevated"
		if (!$SintAPIKey){
			Read-SintAPIKey -ImpactLevel $Global:Answer
		}
		$Username,$Password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated" -Answer $Global:Answer -SintAPIKey $SintAPIKey
	}
	ElseIf ($Global:Answer -match "Combined"){
		Write-Host "Selected: Combined"
		if (!$SintAPIKey){
			Read-SintAPIKey -ImpactLevel $Global:Answer
		}
		$Username,$Password = Get-SintCreds -CI "oss00001" -Username "internal-users-combined" -Answer $Global:Answer -SintAPIKey $SintAPIKey
	}
	else{
		$Global:Answer = Invoke-MultiSelectForm  -message "Please select a Security Domain:" -title "Pick an option:" -objects "Assured", "Elevated", "Combined"
		If ($Global:Answer -match "Assured"){
			Write-Host "Selected: Assured"
			if (!$SintAPIKey){
				Read-SintAPIKey -ImpactLevel $Global:Answer
			}
			$Username,$Password = Get-SintCreds -CI "oss00001i2" -Username "internal-user-assured" -Answer $Global:Answer -SintAPIKey $SintAPIKey
		}
		ElseIf ($Global:Answer -match "Elevated"){
			Write-Host "Selected: Elevated"
			if (!$SintAPIKey){
				Read-SintAPIKey -ImpactLevel $Global:Answer
			}
			$Username,$Password = Get-SintCreds -CI "oss00001" -Username "internal-user-elevated" -Answer $Global:Answer -SintAPIKey $SintAPIKey
		}
		ElseIf ($Global:Answer -match "Combined"){
			Write-Host "Selected: Combined"
			if (!$SintAPIKey){
				Read-SintAPIKey -ImpactLevel $Global:Answer
			}
			$Username,$Password = Get-SintCreds -CI "oss00001" -Username "internal-users-combined" -Answer $Global:Answer -SintAPIKey $SintAPIKey
		}
	}
	[PSCustomObject]@{
	Username = $username
	Password = $password
	}
}

###########################################################################################################################

Function Get-EApiToken {
Param (
	[Parameter(Mandatory,ValueFromPipelineByPropertyName)]$Username,
	[Parameter(Mandatory,ValueFromPipelineByPropertyName)]$Password
)
	$URL1 = "https://keycloak.combined.local/auth/realms/estate-api/protocol/openid-connect/token"
	$Body = @{
		grant_type = "client_credentials"
		client_id = $Username
		client_secret = $Password
	}
	$Raw = Invoke-RestMethod -Uri $URL1 -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
	$global:Token = $Raw.access_token
}

###########################################################################################################################

Function Set-EApiHeaders {
	$Global:URL = "https://estate-api.combined.local/api"
	$Global:Headers = @{}
	$Global:Headers.Add("Authorization",$Global:Token)
}

###########################################################################################################################

Function Select-EApiSecurityDomain {
	if ($Global:Answer){
		Clear-Variable Answer -Scope Global
	}
	if ($Global:SintAPIKey){
		Clear-Variable SintAPIKey -Scope Global
	}
	Get-EApiCreds | Get-EApiToken
	Set-EApiHeaders
}

###########################################################################################################################

Function Invoke-EApiQuery {
Param(
[Parameter(Mandatory,ValueFromPipeline)]$Body,
$Change
)
	if ($Change){
		Get-EApiCreds -Change "True" | Get-EApiToken
		Set-EApiHeaders
		Invoke-RestMethod -Uri $Global:URL -Headers $Global:Headers -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 600
		Get-EApiCreds | Get-EApiToken
		Set-EApiHeaders
	}
	else{
		Try{
			Invoke-RestMethod -Uri $Global:URL -Headers $Global:Headers -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 600
		}Catch{
			Get-EApiCreds | Get-EApiToken
			Set-EApiHeaders
			Invoke-RestMethod -Uri $Global:URL -Headers $Global:Headers -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 600
		}
	}
}

###########################################################################################################################

Function Get-EApiService {
	Param (
		[Parameter(ValueFromPipelineByPropertyName)]$CompanyDomainIdentifier,
		[Parameter(ValueFromPipelineByPropertyName)]$AccountDomainIdentifier
	)
	Process{
		If (($CompanyDomainIdentifier) -and ($AccountDomainIdentifier)){
			$Body = @{
			query = "query findServiceByAccountIDAndDomainId(
				`$companyId: [Int!],
				`$accountId: [Int!]
				) {
				services(
				companyDomainIdentifier: `$companyId,
				accountDomainIdentifier: `$accountId){
	 				name
					accountServiceId
				    account{
						domainIdentifier
				      	name
						securityDomain
				  		company{
	  						domainIdentifier			
							name
							securityDomain
							internal
							blueLight
							partner
							id
						}
						limited
						id
				    } 
					salt
					vendorInstanceIdentifier
					vendorEntity
					vendorEntityUrn
					vcloudOrg {id, name}
					type
					id
				  }
				}";variables = '{"companyId":' + $CompanyDomainIdentifier + ', "accountId":' + $AccountDomainIdentifier + '}'}
			$Raw = $Body | Invoke-EApiQuery
			$Output = $Raw.Data.Services
		}	
		elseif($CompanyDomainIdentifier){
			$Body = @{
			query = "query findServiceByCompanyId(
				`$companyId: [Int!]
				) {
				services(
				companyDomainIdentifier: `$companyId,){
	 				name
					accountServiceId
				    account{
						domainIdentifier
				      	name
						securityDomain
				  		company{
	  						domainIdentifier			
							name
							securityDomain
							internal
							blueLight
							partner
							id
						}
						limited
						id
				    } 
					salt
					vendorInstanceIdentifier
					vendorEntity
					vendorEntityUrn
					vcloudOrg {id, name}
					type
					id
				  }
				}";variables = '{"companyId":' + $CompanyDomainIdentifier + '}'}
			$Raw = $Body | Invoke-EApiQuery
			$Output = $Raw.Data.Services
		}
		elseif ($AccountDomainIdentifier){
			$Body = @{
				query = "query findServiceByAccountId(
					`$accountId: [Int!]
					) {
					services(
					accountDomainIdentifier: `$accountId){
		 				name
						accountServiceId
					    account{
							domainIdentifier
					      	name
							securityDomain
					  		company{
		  						domainIdentifier			
								name
								securityDomain
								internal
								blueLight
								partner
								id
							}
							limited
							id
					    } 
						salt
						vendorInstanceIdentifier
						vendorEntity
						vendorEntityUrn
						vcloudOrg {id, name}
						type
						id
					  }
					}";variables = '{"accountId":' + $AccountDomainIdentifier + '}'}
				$Raw = $Body | Invoke-EApiQuery
				$Output = $Raw.Data.Services
		}
		Else{
			$Body = @{
			query = "{
				services{
				    name
					accountServiceId
				    account{
						domainIdentifier
				      	name
						securityDomain
				  		company{
	  						domainIdentifier			
							name
							securityDomain
							internal
							blueLight
							partner
							id
						}
						limited
						id
				    } 
					salt
					vendorInstanceIdentifier
					vendorEntity
					vendorEntityUrn
					vcloudOrg {id, name}
					type
					id
				  }
				}"
			}
			$Raw = $Body | Invoke-EApiQuery
			$Output = $Raw.data.services
		}
		$Output | Add-Member -NotePropertyName ObjectType -NotePropertyValue EApi.Service.Full
		$Output
	}
}

###########################################################################################################################

Function Get-EApiCompany{
Param(
	[Parameter(ValueFromPipelineByPropertyName)]$CompanyDomainIdentifier,
	[Parameter(ValueFromPipelineByPropertyName)]$AccountDomainIdentifier,
	[Parameter(ValueFromPipeline)]$Account
)
	Begin {
		$Output = @()
	}
	Process{
		If ($Account){$AccountDomainIdentifier = $Account.domainIdentifier}
		If ($CompanyDomainIdentifier){
			$Body = @{
				query = "query findCompanyByDomainId(
					`$companyId: [Int!]
					)	{
				  			companies(domainIdentifier: `$companyId){
	  						domainIdentifier
	  						id
							name
							securityDomain
							internal
							blueLight
							accounts{
								domainIdentifier
								name
								securityDomain
								limited
								id		
							}
							partner
						}
			}";variables = '{"companyId":' + $CompanyDomainIdentifier + '}'}
			$Raw = $Body | Invoke-EApiQuery
			$Output += $Raw.Data.Companies
		}
		Elseif($AccountDomainIdentifier){
			foreach($AccountDomainIdentifier in $AccountDomainIdentifier){
				$Body = @{
					query = "query findCompanyByAccountId(
						`$accountId: [Int!]
						)	{
							accounts(
							domainIdentifier: `$accountId){
								company{
									domainIdentifier
									name
									securityDomain
									internal
									blueLight
									partner
									accounts{
										domainIdentifier
										name
										securityDomain
										limited
										id		
									}
									id
								}							
							}
				}";variables = '{"accountId":' + $AccountDomainIdentifier + '}'}
				$Raw = $Body | Invoke-EApiQuery
				$Output += $Raw.Data.Accounts.Company
			}	
		}
		Else{
			$Body = @{
				query = "{
					companies{
					  	domainIdentifier
						name
						securityDomain
						internal
						blueLight
						partner
						accounts{
							domainIdentifier
							name
							securityDomain
							limited
							id		
						}
						id
					}
				}"
			}
			$Raw = $Body | Invoke-EApiQuery
			$Output += $Raw.Data.Companies		
		}
	}
	End {
		$Final = $Output | Where-Object {$_}
		$Final | Add-Member -NotePropertyName ObjectType -NotePropertyValue EApi.Company.Full
		$Final
	}
}

###########################################################################################################################

Function Get-EApiAccount {
Param(
	[Parameter(ValueFromPipelineByPropertyName)]$CompanyDomainIdentifier,
	[Parameter(ValueFromPipelineByPropertyName)]$AccountDomainIdentifier,
	[Parameter(ValueFromPipeline)]$Company
)
	Begin{
		$Output = @()
	}
	Process{
		if($Company){$CompanyDomainIdentifier = $Company.domainIdentifier}
		if ($CompanyDomainIdentifier){
			foreach ($CompanyDomainIdentifier in $CompanyDomainIdentifier) {
			$Body = @{
				query = "query findAccountByDomainId(
					`$companyId: [Int!]
					)	{
						companies(
						   domainIdentifier: `$companyId) {
								accounts {
									domainIdentifier
									name
									securityDomain
									company{
					  					domainIdentifier
										name
										securityDomain
										internal
										blueLight
										partner
										id								
									}
									limited
									id
								}
							}
						}
					";variables = '{"companyId":' + $CompanyDomainIdentifier + '}'}
				$Raw = $Body | Invoke-EApiQuery
				$Output += $Raw.Data.Companies.Accounts
			}
		}
		elseif ($AccountDomainIdentifier){
			Foreach ($AccountDomainIdentifier in $AccountDomainIdentifier){
				$Body = @{
					query = "query findAccountByAccountIdAndCompanyId(
						`$accountId: [Int!]
						)	{
							accounts(
							domainIdentifier: `$accountId){
					  			domainIdentifier
								name
								securityDomain
								company{
									domainIdentifier
									name
									securityDomain
									internal
									blueLight
									partner
									id
								}
								limited
								id
							}
				}";variables = '{"accountId":' + $AccountDomainIdentifier + '}'}
				$Raw = $Body | Invoke-EApiQuery
				$Output += $Raw.Data.Accounts
			}
		}
		Else{
			$Body = @{
				query = "{
					accounts{
				  		domainIdentifier
						name
						securityDomain
						company{
							domainIdentifier
							name
							securityDomain
							internal
							blueLight
							partner
							id
						}
						limited
						id
					}
				}"
			}
			$Raw = $Body | Invoke-EApiQuery
			$Output += $Raw.Data.Accounts
		}
	}
	End {
		$Final = $Output | Where-Object {$_}
		$Final | Add-Member -NotePropertyName ObjectType -NotePropertyValue EApi.Account.Full
		$Final
	}
}

###########################################################################################################################

Function Get-EApiVM {
Param(
	[Parameter(ValueFromPipelineByPropertyName)]$Name,
	[Parameter(ValueFromPipelineByPropertyName)]$vCenter
)
	if ($Name){
		$Body = @{
			query = "query findVmByVmName(
					`$name: [String!]
				){
				vcloudVms(
					name: `$name) {
					name
					urn
					description
					userName
					cpu
					memory
					vcloudVapp{
						name
						urn
						vcloudVdc{
							name
							urn
							vcloudOrg{
								name
								urn
								description
								mqCreatedAt
								mqUpdatedAt
								id
							}
							id
						}
						id
					}
					storageProfiles
					operatingSystem
					powerStatus
					eventUrn
					mqCreatedAt
					mqUpdatedAt
					data
					id
				}
		}";variables = '{"name":"' + $Name + '"}'}
		$Raw = $Body | Invoke-EApiQuery
		$Raw.data.vcloudVms	
	}
<#	elseif($vCenter){
		$Body = @{
			query = "query findVmByVCenter(
					`$vCenter: [String!]
				){
				vcloudVms(
					vcloudVcenterName: `$vCenter) {
					name
					urn
					description
					userName
					cpu
					memory
					vcloudVapp{
						name
						urn
						vcloudVdc{
							name
							urn
							vcloudOrg{
								name
								urn
								description
								mqCreatedAt
								mqUpdatedAt
								id
							}
							id
						}
						id
					}
					storageProfiles
					operatingSystem
					powerStatus
					eventUrn
					mqCreatedAt
					mqUpdatedAt
					data
					id
				}
		}";variables = '{"name":"' + $vCenter + '"}'}
		$Raw = $Body | Invoke-EApiQuery
		$Raw.data.vcloudVms	
	}
#>
	else{
		$Body = @{
			query = "{
				vcloudVms{
					name
					urn
					description
					userName
					cpu
					memory
					vcloudVapp{
						name
						urn
						vcloudVdc{
							name
							urn
							vcloudOrg{
								name
								urn
								description
								mqCreatedAt
								mqUpdatedAt
								id
							}
							id
						}
						id
					}
					storageProfiles
					operatingSystem
					powerStatus
					eventUrn
					mqCreatedAt
					mqUpdatedAt
					data
					id
				}
			}"
		}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudVms	
	}
}

###########################################################################################################################

Function Get-EApivApp {
	$Body = @{
		query = "{
			vcloudVapps{
				name
				urn
				vcloudVdc{
					name
					urn
					vcloudOrg{
						name
						urn
						description
						mqCreatedAt
						mqUpdatedAt
						id
					}
					id
				}
				vcloudVms{
					name
					urn
					description
					userName
					cpu
					memory
					storageProfiles
					operatingSystem
					powerStatus
					eventUrn
					mqCreatedAt
					mqUpdatedAt
					data
					id
				}
				id
			}	
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudVapps
}

###########################################################################################################################

Function Get-EApiVdc {
	$Body = @{
		query = "{
			vcloudVdcs{
				name
				urn
				vcloudPvdc{
					name
					urn
					vcloudVcenter{
						name
						urn
						id
					}
					id
				}
				vcloudOrg{
					name
					urn
					description
					service{
						name
						accountServiceId
						account{
							domainIdentifier
							name
							securityDomain
							company{
								domainIdentifier
								name
								securityDomain
								internal
								blueLight
								partner
								id
							}
							limited
							id
						}
						salt
						vendorInstanceIdentifier
						vendorEntity
						vendorEntityUrn
						type
						id
					}
					mqCreatedAt
					mqUpdatedAt
					id
				}
				vcloudVapps{
					name
					urn
					vcloudVms{
						name
						urn
						description
						userName
						cpu
						memory
						storageProfiles
						operatingSystem
						powerStatus
						eventUrn
						mqCreatedAt
						mqUpdatedAt
						data
						id
					}
					id
				}
				id
			}
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudVdcs
}

###########################################################################################################################

Function Get-EApiPvdc{
	$Body = @{
		query = "{
			vcloudPvdcs{
		    	name
		    	urn
				vcloudVdcs{
					name
					urn
					id
				}
				vcloudVcenter{
					name
					urn
					vcloud{
						name
						uri
						id
					}
					id
				}
				id
		  	}
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudPvdcs
}

###########################################################################################################################

Function Get-EApiVCenter{
	$Body = @{
		query = "{
			vcloudVcenters{
		    	name
		    	urn
				vcloudPvdcs{
					name
					urn
					id
				}
				vcloud{
					name
					uri
					id
				}
				id
		  	}
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudVcenters
}

###########################################################################################################################

Function Get-EApiOrg{
	$Body = @{
		query = "{
			vcloudOrgs{
		    	name
		    	urn
				vcloud{
					name
					uri
					id
				}
				vcloudVdcs{
					name
					urn
					id
				}
				service{
					name
					accountServiceId
					salt
					vendorInstanceIdentifier
					vendorEntity
					vendorEntityUrn
					type
					id	
				}
				mqCreatedAt
				mqUpdatedAt
				id
		  	}
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vcloudOrgs
}

###########################################################################################################################

Function Get-EApiVcloud{
	$Body = @{
		query = "{
			vclouds{
				name
				uri
				vcloudOrgs{
			    	name
			    	urn
					mqCreatedAt
					mqUpdatedAt
					id
			  	}
				vcloudVcenters{
			    	name
			    	urn
					id
				}
				id
			}
		}"
	}
	$Raw = $Body | Invoke-EApiQuery
	$Raw.data.vclouds	
}

###########################################################################################################################

Function Set-EApiAccountLimit{
Param(
	[Parameter(ValueFromPipeline)]$Accounts,
	$Limited
)
	Begin {
		$Limited = $Limited.ToLower()
	}
	Process {
		foreach ($Account in $Accounts){
			if ($Account.ObjectType -cmatch "EApi.Account.Full"){$AccountID = $Account.id}
			else {
				Write-Error "$Account`: Input object is not a valid Account"
				break
			}
			$Body = @{
				query = "mutation updateAccount(`$input: UpdateAccountInput!) {
				  updateAccount(input: `$input) {
				    account {
				      name
				      securityDomain
				      limited
				    }
				  }
				}";variables = '{"input": ' + '{ "id": ' + $AccountID + ', "limited": ' + $Limited +'}}'}
			$Body | Invoke-EApiQuery -Change "True"
		}
	}
}