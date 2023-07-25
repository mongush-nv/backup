function SendMail
{
	# Функция отправляет письмо о результате копирования
	param(
        [String]$Subject
    )
	

    $emailSmtpServer = "mail.domain.ru"		# Адрес SMTP сервера
    $emailSmtpServerPort = "25"				# Порт SMTP сервера
    $emailFrom = "backup@domain.ru"			# От кого придет письмо
    $emailTo = "admin@domain.ru"			# Кому мы отправляем письмо 
	
    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.To.Add($emailTo)
    $emailMessage.From = $emailFrom
    $Day = Get-Date -Format dd.MM.yyyy
    $emailMessage.Subject = $Subject + $Day

    $SMTPClient = New-Object System.Net.Mail.SmtpClient( $emailSmtpServer , $emailSmtpServerPort )
    $SMTPClient.EnableSsl = $false
    $SMTPClient.Send($emailMessage)

}

function EnableOrDisableNetAdapter
{
	# Функция включает или отключает сетевой интерфейс
    param(
        [String]$EnableOrDisable
    )

    if($EnableOrDisable -eq "Enable")
    {
        Enable-NetAdapter -name Ethernet0 -Confirm:$false
    }

    if($EnableOrDisable -eq "Disable")
    {
        Disable-NetAdapter -name Ethernet0 -Confirm:$false
    }

}

function StartCopying
{
	
	$SourceServer = "srv-fs-01"						# Имя сервера источника где хранятся файлы которые надо скопировать
	$Username = "domain\backup"						# Учетная запись от имени которого будет запускаться скрипт
	$sourcePath = "\\srv-fs-01\storage\" 			# Адрес файловой шары которую будем копировать
	$destinationPath = "D:\Storage\"			    # Место назначения где будут храниться бекап

	$currentDate = Get-Date -Format d				# Берем текущую дату
	$logPath = "D:\robocopy logs\" +$currentDate	
	New-Item -Path $logPath -ItemType Directory -ErrorAction SilentlyContinue		# Создаем в директории с логами папку с текущей датой куда будем сохранять логи



	# $foldersName = (dir -Path $sourcePath | select name | Where-Object {$_.name -ne "Обмен"}).name			# Исключаем папку Обмен чтобы не копировать ее
	$foldersName = (dir -Path $sourcePath).name		
	for ($i=0; $i -lt $foldersName.Count; $i++)
	{
		# Закрываем все открытые файлы
		Invoke-Command -ComputerName $SourceServer -ScriptBlock {Get-SmbOpenFile | select ClientUserName | Where-Object ClientUserName -ne $Username | Close-SmbOpenFile -Force}
		$source = $sourcePath + $foldersName[$i]
		$destination = $destinationPath + $foldersName[$i]
		$log = $logPath + "\" + $foldersName[$i] +".txt"
		robocopy $source $destination /E /PURGE /COPYALL /Z /B /J /V /NP /NDL /R:5 /W:5 /REG /MT:5 /LOG+:$log
	}
}

function Main
{

    # Включаем сетевой адептер
	EnableOrDisableNetAdapter -EnableOrDisable "Enable"

	$flag = 0
	$count = 30
	$seconds = 10
	while($flag -ne $count)
	{
		
		if (Test-Path -Path "\\srv-fs-01\Storage") # Проверяем доступность сетевой папки. Если доступ есть, запускаем копирование
		{
			# Вызываем функцию копирования
			StartCopying
			SendMail -Subject "Успех. Бэкап сетевой папки "
			break
		}
		else
		{
			$flag += 1
			if($flag -eq $count)
			{
				# Пробуем отправить письмо о том что копирование не выполнилось
                SendMail -Subject "ОШИБКА. Бэкап сетевой папки "
				break
			}

			Start-Sleep -Seconds $seconds
			EnableOrDisableNetAdapter -EnableOrDisable "Enable"
		}

	}

	Start-Sleep -Seconds 100
    # Отключаем сетевой адаптер
	EnableOrDisableNetAdapter -EnableOrDisable "Disable"

	

}

main
