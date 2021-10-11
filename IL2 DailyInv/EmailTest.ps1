If ($env:USERDOMAIN -like "*il2*"){
Send-MailMessage -To noc@ukcloud.com -Bcc dandrews@ukcloud.com -From emailaddressIL2@ukcloud.com -Subject "Emails are working on Assured" -Body "Look at the body on this" -BodyAsHtml -SmtpServer rly00001i2
}
Else {
Send-MailMessage -To noc@ukcloud.com -Bcc dandrews@ukcloud.com -From emailaddressIL3@ukcloud.com -Subject "Emails are working on Elevated" -Body "Look at the body on this" -BodyAsHtml -SmtpServer 10.72.81.30
}