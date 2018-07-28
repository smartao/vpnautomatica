#!/bin/bash
# Script de contingencia automatica usando VPNs pela internet com o software openswan 

function MAIN(){
	# Criar funcao para mostrar o que seja fazer 1 para subir contingencia 2 para desativar
	DATA
	CONFCOR
	CARREGACONF
	m1=0
        while [ $m1 -ne 1 ]
	do
		MENU1
		case $M1 in
		1) # Opcao para subir a contingencia
			m2=0
			tipo="ATIVAR"
			while [ $m2 -ne 1 ]
			do
				CAPTURASITES
				MENU2
				VALIDAOPCAO2 
			done
			for((a=1;a<=${#SITE[@]};a++));
			do
				if [ ${SITE[$a]} != ${SITE[$CAIDO]} ];then
					CONFVARIAVEIS
					CRIACONEXAO
					COPIAARQUIVOS
					RESTARTIPSEC
				fi
			done
			m1=1
			;;
		2) # Opcao para desativar a contingencia
			m2=0
			tipo="DESATIVAR"
			while [ $m2 -ne 1 ]
			do
				CAPTURASITES
				MENU2
				VALIDAOPCAO2 
			done
			for((a=1;a<=${#SITE[@]};a++));
			do
				if [ ${SITE[$a]} != ${SITE[$CAIDO]} ];then
					CONFVARIAVEIS
					DELETAARQUIVOS
					RESTARTIPSEC
				fi
			done
			m1=1	
			;;
		3) # Opcao para sair do programa
			m1=1
			exit;
			;;
		*) # Caso digitar uma opcao invalida
                        MSGOPCAOINVALIDA
                        ;;
		esac
	done
	MSGFIM
}

function CARREGACONF(){
	USER=brqssh # Usuario para executar as funcoes nos servidores precisa estar sudoers
	PORTA=22 # Porta SSH para conexcao 
	TIME=5 # Tempo de timeout em caso de falha
	DIRLOG=logs
	ARQLOG=$DIRLOG/vpnautomatica.$DIA.log
	mkdir -p $DIRLOG > /dev/null 2>&1
}

function MENU1(){
	clear
	# ADICIONAR DATA DE EXECUCAO NESSA TELA e DATA DE TERMINO NA ULTIMA LINHA
        echo "#----------------- Script de VPN automatica ------------------#" | tee -a $ARQLOG
        echo -e "#--------------------$CAM $DATA $CF----------------------#" | tee -a $ARQLOG
        echo "#---------------------- MENU PRINCIPAL -----------------------#" | tee -a $ARQLOG
        echo "#-------------------------------------------------------------#" | tee -a $ARQLOG
        echo "# O que voce deseja fazer?                                     " | tee -a $ARQLOG
        echo "# 1 - Ativar a contigência em um site                          " | tee -a $ARQLOG
        echo "# 2 - Remover a contigência em um site                         " | tee -a $ARQLOG
        echo "# 3 - Sair                                                     " | tee -a $ARQLOG
        read -p "# R: " M1
	echo "# R: $M1" >> $ARQLOG 
}

function MENU2(){
        clear
	echo "" | tee -a $ARQLOG
	echo "#-------------------------------------------------------------#" | tee -a $ARQLOG
	echo "# Por favor informe o site que deseja $tipo a contingencia     " | tee -a $ARQLOG
        for((a=1;a<=${#SITE[@]};a++));
        do
                echo "# [$a] ${SITE[$a]}" | tee -a $ARQLOG
        done
	read -p "# R: " CAIDO
	echo "# R: $CAIDO" >> $ARQLOG 
	echo "" | tee -a $ARQLOG		
}

function MSGFIM(){
      	DATA
	echo ""	| tee -a $ARQLOG
        echo "#-------------------- Script Finalizado ----------------------#" | tee -a $ARQLOG
        echo -e "#--------------------$CAM $DATA $CF----------------------#" | tee -a $ARQLOG
	echo ""	| tee -a $ARQLOG
}

function CAPTURASITES(){ 
	a=1
	for i in `ls *.redes`
	do
		SITE[$a]=$i
		let a=$a+1
	done
}

function VALIDAOPCAO2(){
	for((a=1;a<=${#SITE[@]};a++));
        do
		if [ $CAIDO == $a ];then
		 	m2=1
		fi
        done
	if [ $m2 != 1 ];then # Caso tenha digita uma opcao invalida
		MSGOPCAOINVALIDA
	fi
} 
function MSGOPCAOINVALIDA(){
	echo -e "\nEntre com uma opcao valida!" | tee -a $ARQLOG 
        echo -e "Precione qualquer tecla para voltar..." | tee -a $ARQLOG
        #read -p "Precione qualquer tecla para voltar..."
	read 
}

function CONFVARIAVEIS(){
	FROM=${SITE[$CAIDO]}
	TO=${SITE[$a]}
	LEFTHOST=`ls $FROM | cut -d. -f2`
	RIGHTHOST=`ls $TO | cut -d. -f2`
	ARQUIVOVPN=ipsec.$LEFTHOST-to-$RIGHTHOST
	LEFT=`grep left= $FROM`;
	RIGHT=`grep left= $TO|sed 's/left/right/g'`; 
	LEFTNEXTHOP=`grep leftnexthop= $FROM`;
	LEFTIP=`echo $LEFT|cut -d= -f2` 
	RIGHTIP=`echo $RIGHT|cut -d= -f2`
	LEFTTYPE=`grep -i linux $FROM | cut -d= -f2`
	RIGHTTYPE=`grep -i linux $TO | cut -d= -f2`
}

function CONFIPSEC(){
	echo "conn $leftconn-TO-$rightconn" >> $ARQUIVOVPN;
	echo "   type=tunnel" >> $ARQUIVOVPN;
	echo "   $LEFT" >> $ARQUIVOVPN;
	echo "   $LEFTNEXTHOP" >> $ARQUIVOVPN;
	echo "   leftsubnet=$leftsubnet" >> $ARQUIVOVPN;
	echo "   $RIGHT" >> $ARQUIVOVPN;
	echo "   rightsubnet=$rightsubnet" >> $ARQUIVOVPN;
	echo "   authby=secret" >> $ARQUIVOVPN;
	echo "   auth=esp" >> $ARQUIVOVPN;
	echo "   keylife=24h" >> $ARQUIVOVPN;
	echo "   keyexchange=ike" >> $ARQUIVOVPN;
	echo "   ike=3des-md5-modp1024" >> $ARQUIVOVPN;
	echo "   esp=3des-md5-96" >> $ARQUIVOVPN;
	echo "   rekey=no" >> $ARQUIVOVPN;
	echo "   rekeymargin=9m" >> $ARQUIVOVPN;
	echo "   rekeyfuzz=25%" >> $ARQUIVOVPN;
        echo "   pfs=no" >> $ARQUIVOVPN;
        echo "   auto=start" >> $ARQUIVOVPN;
       	echo "" >> $ARQUIVOVPN;
}

function CRIACONEXAO(){
	rm -f $ARQUIVOVPN 2>/dev/null; # Removendo Arquivos de VPN Anteriroes
	rm -f $ARQUIVOVPN-from 2>/dev/null; # Removendo Arquivos de VPN Anteriroes

	for e in `cat $FROM|grep INTERNA` 
	do
		leftconn=`echo $e|cut -d# -f2`;
		leftsubnet=`echo $e|cut -d# -f1`;
		for j in `cat $TO|grep \#`
		do
			rightsubnet=`echo $j|cut -d# -f1`;
		        rightconn=`echo $j|cut -d# -f2`;
			CONFIPSEC
		done	
	done
	
	for e in `cat $TO|grep INTERNA`
	do
		leftconn=`echo $e|cut -d# -f2`;
		rightsubnet=`echo $e|cut -d# -f1`;
		for k in `cat $FROM|grep \#|grep -v INTERNA`
		do
			leftsubnet=`echo $k|cut -d# -f1`;
	        	rightconn=`echo $k|cut -d# -f2`;
			CONFIPSEC
		done
	done
	rightnexthop=`grep leftnexthop= $TO|cut -d= -f2`;
	sed "s/$LEFTNEXTHOP/rightnexthop=$rightnexthop/g" $ARQUIVOVPN >$ARQUIVOVPN-from;
}

function COPIAARQUIVOS(){
        if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME scp -P $PORTA $ARQUIVOVPN $USER@$LEFTIP:/tmp > /dev/null 2>&1  
		T=$?; FASELOG=1; LOGTELA
	else	
		T=2; FASELOG=1; LOGTELA
	fi
        if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME scp -P $PORTA $ARQUIVOVPN-from $USER@$RIGHTIP:/tmp > /dev/null 2>&1 
		T=$?; FASELOG=2; LOGTELA
	else	
		T=2; FASELOG=2; LOGTELA
	fi
	
        if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo mv /tmp/$ARQUIVOVPN /etc/ipsec.d/ > /dev/null 2>&1 #REATIVAR 2 TESTE # Redirect > /dev/null 2>&1
		T=$?; FASELOG=3; LOGTELA
	else	
		T=2; FASELOG=3; LOGTELA
	fi
        if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo mv /tmp/$ARQUIVOVPN-from /etc/ipsec.d/ > /dev/null 2>&1 #REATIVAR 2 TESTE # Redirect > /dev/null 2>&1
		T=$?; FASELOG=4; LOGTELA
	else
		T=2; FASELOG=4; LOGTELA
	fi
		
}

function RESTARTIPSEC(){
        if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo /etc/init.d/ipsec restart > /dev/null 2>&1 #REATIVAR 2 TESTE # Redirect > /dev/null 2>&1
		T=$?; FASELOG=5; LOGTELA
	else
		T=2; FASELOG=5; LOGTELA
	fi
        if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo /etc/init.d/ipsec restart > /dev/null 2>&1 #REATIVAR 2 TESTE
		T=$?; FASELOG=6; LOGTELA
	else
		T=2; FASELOG=6; LOGTELA
	fi
}

function DELETAARQUIVOS(){ 
        if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo rm /etc/ipsec.d/$ARQUIVOVPN >>/dev/null 2>&1 # REATIVAR2 TESTE
		T=$?; FASELOG=7; LOGTELA
	else
		T=2; FASELOG=7; LOGTELA
	fi
        if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo rm /etc/ipsec.d/$ARQUIVOVPN-from >>/dev/null 2>&1 # REATIVAR2 TESTE
		T=$?; FASELOG=8; LOGTELA
	else
		T=2; FASELOG=8; LOGTELA
	fi
	rm $ARQUIVOVPN $ARQUIVOVPN-from > /dev/null 2>&1 # Deletando arquivos ipsec
}

function LOGTELA(){
	case $FASELOG in # Mostrando o log da tela conforme a fase
	        1) 
			TESTAT 
			echo -ne "Copiado o arquivo $ARQUIVOVPN para HOST:$LEFTHOST IP:$LEFTIP \n" | tee -a $ARQLOG 
			;;
		2)
			TESTAT
			echo -ne "Copiado o arquivo $ARQUIVOVPN-from para HOST:$RIGHTHOST IP:$RIGHTIP \n" | tee -a $ARQLOG
			;;
		3)
			TESTAT
			echo -ne "Movido o arquivo $ARQUIVOVPN do diretorio /tmp/ para /etc/ipsec.d HOST:$LEFTHOST IP:$LEFTIP \n" | tee -a $ARQLOG
			;;
		4)	
			TESTAT
			echo -ne "Movido o arquivo $ARQUIVOVPN-from do diretorio /tmp/ para /etc/ipsec.d HOST:$RIGHTHOST IP:$RIGHTIP \n" | tee -a $ARQLOG
			;;
		5)
			TESTAT
			echo -ne "Reiniciado o servido do ipsec HOST:$LEFTHOST IP:$LEFTIP \n" | tee -a $ARQLOG
			;;
		6)	
			TESTAT
			echo -ne "Reiniciado o servido do ipsec HOST:$RIGHTHOST IP:$RIGHTIP \n" | tee -a $ARQLOG
			;;
		7)
			TESTAT
			echo -ne "Deletado o arquivo de ipsec $ARQUIVOVPN HOST:$LEFTHOST IP:$LEFTIP \n" | tee -a $ARQLOG
			;;
		8)
			TESTAT
			echo -ne "Deletado o arquivo de ipsec $ARQUIVOVPN-from HOST:$RIGHTTHOST IP:$RIGHTIP \n" | tee -a $ARQLOG
			;;
		*)
			echo "OPCAO NAO RECONHECIDA" | tee -a $ARQLOG
			;;
	esac

}

function TESTAT(){
	case $T in	
		"0")
			echo -ne "[$CVD OK $CF]\t\t " | tee -a $ARQLOG			
			;;
		"2")
			echo -ne "[$CAM IGNORADO $CF]\t " | tee -a $ARQLOG			
			;;
		*)
			echo -ne "[$CVE FALHA $CF]\t " | tee -a $ARQLOG			
			;;
	esac
}

function DATA(){ 
	DIA=`date "+%y%m%d"` > /dev/null # Data yy-mm-dd
        HORA=`date "+%H:%M:%S"` > /dev/null # Hora hh-mm-ss
	DATA="$DIA - $HORA"
}

function CONFCOR(){
        CVE='\e[1;31m' # Red Bold
        CVD='\e[1;32m' # Verde Bold
        CAM='\e[1;33m' # Yellow Bold
        CCA='\e[1;36m' # Cyan Bold
        CBR='\e[1;37m' # White Bold
         CF='\e[0m'    # Tag end
}

MAIN
exit;
