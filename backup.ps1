#
# versao 0.1
#
# INFORMAÇÕES
#   copia_email.sh         
#
# DESCRICAO
#    Script para Fazer backup em discos especificados pelo ID do volume;
#    Verifica o status da replicação de VM - Peguei essa função aqui: https://goo.gl/LHVqax 
#    Envia e-mail com o relatório do backup e avisos
#
# NOTA
#   Testado e desenvolvido em Windows 2012 R2
#   
#  DESENVOLVIDO_POR
#  Valdenir Luíz Mezadri Junior			- valdenirmezadri@live.com
#
#  MODIFICADO_POR		(DD/MM/YYYY)
#
############## Variáveis do Backup  #################################################################
$VM=(Get-VM).Name -join ',';  #Pega todas as VM

$USB1="\\?\Volume{1744d4e6-b67d-4b6e-970f-069ce80a61cc}\";  #disco de backup1
$USB2="\\?\Volume{ff86805f-4b3c-48a1-bcae-54b952666762}\"; #disco de Backup2
$USB3="\\?\Volume{a6dc80e2-8df5-49a8-b8c9-e2beab5a670b}\";  #disco de backup3

################### Variáveis de e-mail #############################################################
   
$emailFrom = "email@dominio.com.br";
$emailTo = "junior@hardtec.srv.br,cliente@dominio.com.br";
$subject = "Cliente - Backup das Máquinas virtuais replicadas";
$body = "Relatório de replicação dos dados";
$smtpServer = "mail.dominio.com.br";

#################### Não alterar a partir daqui  ####################################################
$Dir_local = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition);
$LOG="$Dir_local\log\log.txt";
$ANEXO=$LOG;

$USB1_CHECK=Get-Volume -ObjectId $USB1;
$USB2_CHECK=Get-Volume -ObjectId $USB2;
$USB3_CHECK=Get-Volume -ObjectId $USB3;

#Testa se tem alguma inconsistência na replicação 

function ReplicacaoStatus() {
    $VMs_All = Get-VMReplication;
    
    # Verifica se a replicação de VM está habilitada
    If ($VMs_All.length -gt 0) {
        # VMs com replicação encontrada
        
        # Documentando VM replication health
        ForEach ($VM in $VMs_All) {
            If (($VM.ReplicationHealth -eq "Warning") -or ($VM.ReplicationHealth -eq "Critical")) {
                # VM´s com problemas de replicação
                
                # Adiciona VM´s com problemas para o multidimensional array
                $VMs_Broken_Array += ,@($VM.VMName, $VM.ReplicationHealth);
            }
            # Adiciona VM's para multidimensional array
            $VMs_All_Array += ,@($VM.VMName, $VM.ReplicationHealth);
        }
        
        # Generate output part 1/2 and MAX RemoteManagement exit codes
        If ($VMs_Broken_Array.length -eq 0) {
            # VM replication issues not found
            
           echo "Replicação OK. Não foi encontrado nenhum erro de replicação. Detalhes:";
                
            # Set exit code to pass MAX RemoteManagement check
            $ExitCode = 0;
        } Else {
            # VM replication issues found
            
            echo "FALHA NA REPLICAÇÃO. Foi encontrado erros na replicação. Detalhes:";
            $script:subject2="FALHA NA REPLICAÇÃO!!! - ";
            # Set exit code to fail MAX RemoteManagement check
            $ExitCode = 1;
        }
        
        # Convert from 1-based index to 0-based index for array alignment (not actually relevant since use of multiline)
        $VMs_All_Array_loopLength = $VMs_All_Array.length - 1;
        
        # Generate output part 2/2
        For ($i = 0; $i -ne $VMs_All_Array.length; $i++) {
            $Output = 'VM "' + $VMs_All_Array[$i][0] + '" replication health "' + $VMs_All_Array[$i][1] + '"';
            
            echo $Output;
        }
    } Else {
        # Found no VMs with replication enabled
        
        echo "Não foi encontrado máquinas virtuais com replicação ativa.";
            
        # Set exit code to pass MAX RemoteManagement check
        $ExitCode = 0;
    }

  return $subject2;
}

function SelecionaUSB(){
    if($USB1_CHECK){
        echo "USB1 Encontrada... Iniciando Backup!!!"
        $DESTINO=$USB1;
        backup;
        }elseif($USB2_CHECK){
            echo "USB2 Encontrada... Iniciando Backup!!!"
            $DESTINO=$USB2;
            backup;
            }elseif($USB3_CHECK){
                echo "USB3 Encontrada... Iniciando Backup!!!"
                $DESTINO=$USB3;
                backup;
    }else{
    echo "Nenhum disco USB para Backup encontrado!"
    } 
}

#faz o backup, é chamado dentro da função SelecionaBackup
function backup() {
$DESTINO=$DESTINO.TrimEnd('\')
wbadmin start backup -backuptarget:"""$DESTINO""" -allcritical -vssFull -hyperv:"""$VM""" -quiet
}


function sendEmail([string]$emailFrom, [string]$emailTo, [string]$subject,[string]$body,[string]$smtpServer,[string]$filePath)
{
#initate message
$email = New-Object System.Net.Mail.MailMessage 
$email.From = $emailFrom
$email.To.Add($emailTo)
$email.Subject = $subject
$email.Body = $body
# initiate email attachment 
$emailAttach = New-Object System.Net.Mail.Attachment $filePath
$email.Attachments.Add($emailAttach) 
#initiate sending email 
$smtp = new-object Net.Mail.SmtpClient($smtpServer, 25)
$smtp.Send($email)
}
#Chama a função para enviar o e-mail

#Limpa variáveis
function limpa(){
    if(Test-Path variable:\subject2){Remove-Variable -Scope global  subject2;}
}

ReplicacaoStatus;
SelecionaUSB;
sendEmail $emailFrom $emailTo $subject2$subject $body $smtpServer $ANEXO;
limpa


