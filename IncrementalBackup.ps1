function SendMail
{
    $emailSmtpServer = "mail.domain.ru"
    $emailSmtpServerPort = "25" 
    $emailFrom = "backup@domain.ru"
	$emailTo = "admin@domain.ru"
	
    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.To.Add($emailTo)
    $emailMessage.From = $emailFrom
    $Day = Get-Date -Format dd.MM.yyyy
    $emailMessage.Subject = "инкрементальный бэкап  " + $Day

    $SMTPClient = New-Object System.Net.Mail.SmtpClient( $emailSmtpServer , $emailSmtpServerPort )
    $SMTPClient.EnableSsl = $false
    $SMTPClient.Send($emailMessage)
}


$Last24Hours  = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)				# Будем выбирать файлы старше этой даты
$Long = "\\?\"																	# Потребуется чтобы найти файлы с очень длинным путем более 256 символов
$StoragePath = "D:\Storage\"													# Источник где хранятся файлы и будет производиться поиск
$BackupPath = "D:\IncrementalBackup"											# Место назначения где будут храниться инкрементальные бэкапы по каждым дням
$CurrentBackup = Join-Path -Path $BackupPath -ChildPath (Get-Date).AddDays(-1).ToString("dd-MM-yyyy")
New-Item -ItemType Directory -Path $CurrentBackup -ErrorAction Continue			# Создаем папку с вчерашней датой куда будем сохранять файлы

$Date = (Get-Date).AddDays(-1).ToString("dd-MM-yyyy")
$RobocopyLog = "D:\IncrementalBackup\logs\robocopy\$Date.txt"

# Папки дирекций
$FoldersPath = Get-ChildItem -Path $StoragePath -Directory | select Name, Fullname

$FilesToCopy = @()
$SubPath = Join-Path -Path $Long -ChildPath $StoragePath  #получаем вот такую строку "\\?\D:\Storage\"
for($i=0; $i -lt $FoldersPath.Count; $i++)
# for($i=0; $i -lt 3; $i++)
{
    $LongPath = Join-Path -Path $Long -ChildPath $FoldersPath[$i].Fullname			#получаем вот такую строку "\\?\D:\Storage\IT"
    #  свойство PSIsContainer объекта System.IO.FileSystemInfo, чтобы определить, является ли элемент файлом или папкой. Это свойство возвращает значение True, если элемент является папкой, и значение False, если элемент является файлом.
    $Files = Get-ChildItem -Path $LongPath -Recurse | select Name, FullName, CreationTime, LastWriteTime, DirectoryName, PSIsContainer | Where-Object {!$_.PSIsContainer}
    
    foreach($File in $Files)
    {
        if(($File.CreationTime -ge $Last24Hours) -or ($File.LastWriteTime -ge $Last24Hours))
        {
            
            $FolderStructure = $File.DirectoryName.Substring($SubPath.Length)  # убираем из пути начало  "\\?\D:\Storage\"
            $FolderStructure = Join-Path -Path $CurrentBackup -ChildPath $FolderStructure  # получаем такой путь D:\backup\19-04-2023\Common\1. ПАПКИ... 
			
			# Copy-Item не может копировать файлы если длина пути больше 256 символов. По этому используем робокопи
			
            # if(-not (Test-Path -Path $FolderStructure))     # проверяем если ли такая папка. Создаем если ее нет
            # {
            #     New-Item -Path $FolderStructure -ItemType Directory -ErrorAction Continue -Force
            #     Start-Sleep -Seconds 1
            # }
            # Copy-Item -Path $File.FullName -Destination $FolderStructure -Force -ErrorAction Continue    # Копируем файл в созданную папку
			
            $sours = $File.DirectoryName.Substring($Long.Length)
            robocopy $sours $FolderStructure $File.Name /Z /B /S /J /V /NP /NDL /COPYALL /R:2 /W:2 /LOG+:$RobocopyLog



            $FilesToCopy += [pscustomobject]@{
                                Name=$File.Name; 
                                FullName=$File.FullName; 
                                CreationTime=$File.CreationTime; 
                                LastWriteTime=$File.LastWriteTime; 
                                DirectoryName=$File.DirectoryName;
                                PSIsContainer=$File.PSIsContainer

                        }
        }
    }
}


$FilesToCopy | Export-Csv -Path "D:\IncrementalBackup\logs\$Date.csv" -Encoding UTF8 -Delimiter ";" -NoTypeInformation


SendMail
