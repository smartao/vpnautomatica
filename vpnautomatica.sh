#!/bin/bash
# Autores: Nelys Santos e Sergei Armando Martao
# Data: 23/06/2017
#
# Resumo: 
#	Script usado para criar uma contingencia pela internet em caso de falha de um link P2P que conecte dois sites distantes
#	o script utiliza o pacote opensan para fazer um VPN ipsec e manter a comunicacao funcionando com segurança
#
# Funcionamento basico:
#	Script que le os arquivos *.redes do mesmo diretorio e baseado no que estiver escrito na linha left, cria automaticamente arquivos de ipsec para fazer uma rede
# que é interligada via um link interna (ex: mpls) possa se comunicar via internet usando a VPN ipsec pelo software openswan assim fornecendo uma maneira 
# rapida e pratica de contingencia multisites atravez da internet.
#
# Premissas para funcionamento:
# O servidor que o script estiver precisa conectar em todos os servidores de ipsec usando chave publica, sem pedir senha
# O usuario de execucao do script (linha 110, USER=usuario) precisa existir em todos os servidores e ter permissoes de sudo sem precisar de senha
# Ter o openswan instalado em todos os servidores VPN
# Deve ser criado um arquivo .redes para cada localidade de contingencia e seguir a nomenclatura a risca
# Ex. Numero.Descricao.redes
# 	1.riodejaneiro.redes
# 	2.saopaulo.redes
# 
# Exemplo do conteudo de um arquivo .redes
#linux=1 
#left=200.2.2.2
#leftnexthop=200.2.2.1
#172.16.10.0/24#INTERNASITEA
#10.10.10.0/24#CLIENTEXPTOA1
#
# linux=1
# Caso o servidor vpn seja um linux usando openswan, caso contrário deve usar linux=0
#
# left=200.2.2.2
# IP valido do left peer, usado para conectar e fechar a vpn
#
# leftnexthop=200.2.2.1
# Proximo salto do left peer, utilizado para direcionar por onde o pacote vpn saira
# 
# 172.16.10.0/24#INTERNASITEA
# Rede que sera feita a contingencia em caso de queda, redes internas devem ter a comentario INTERNA no minimo para identificado
# pode-se adicionar quantas redes internas forem preciso contingenciar
#
# 10.10.10.0/24#CLIENTEXPTOA1
# Rede que o siteA possui, exemplo um link P2P com esse cliente e sera feita a contingencia, nesse caso NAO colocar INTERNA
# Assim evitando fechar a VPN entre clientes diferentes, ex CLIENTEXPTOA1 com o CLIENTEXPTOB1 (que esta em outra localidade)

function MAIN(){
	# Criar funcao para mostrar o que seja fazer 1 para subir contingencia 2 para desativar
	DATA # Pegando a data atual
	CONFCOR # Configurando as variaveis com cor
	CARREGACONF # Carregando as configuracoes iniciais
	m1=0 # variavel para testar o primeiro while do primeiro meno
	while [ $m1 -ne 1 ]
	do
		MENU1 # funcao que chama o primeiro menu
		case $M1 in # validando a resposta dada ao menu1
		1) # Opcao para subir a contingencia
			m2=0 # variavel para testar o segundo while
			tipo="ATIVAR" # variavel para mostrar ATIVA no menu2
			while [ $m2 -ne 1 ]
			do
				CAPTURASITES #Capturando os sites disponiveis no diretorio 
				MENU2 # Mostrando o menu 2
				VALIDAOPCAO2 # validando a opcao digida
			done
			for((a=1;a<=${#SITE[@]};a++)); # For para subir a contingencia entre os sites
			do
				if [ ${SITE[$a]} != ${SITE[$CAIDO]} ];then # if para impedir de fechar um tunel com o proprio site
					CONFVARIAVEIS # carregando as variavies basicas conforme o site
					CRIACONEXAO # criando o arquivo de ipsec
					COPIAARQUIVOS # copiando os arquivos ipsec entre os sites
					RESTARTIPSEC # reiniciando o ipsec
				fi
			done
			m1=1 # variavel para saindo do primeiro while 
			;;
		2) # Opcao para desativar a contingencia
			m2=0 # funcao funcia exatamente como a de cima
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
					DELETAARQUIVOS # Funcao para deletar os arquivos ipsec de cada servidor vpn
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
                        MSGOPCAOINVALIDA # Apenas para mostrar que a opcao e invalida
                        ;;
		esac
	done
	MSGFIM # Mensagem mostranda no final do programa 
}

function CARREGACONF(){
	USER=brqssh # Usuario para executar as funcoes nos servidores precisa estar sudoers
	PORTA=22 # Porta SSH para conexcao 
	TIME=5 # Tempo de timeout em caso de falha
	DIRLOG=logs # Diretorio de logs
	ARQLOG=$DIRLOG/vpnautomatica.$DIA.log # Arquivo de logs
	mkdir -p $DIRLOG > /dev/null 2>&1 # Criando o diretorio de logs
}

function MENU1(){
	clear
	echo "#----------------- Script de VPN automatica ------------------#" | tee -a $ARQLOG
	echo -e "#--------------------$CAM $DATA $CF----------------------#" | tee -a $ARQLOG
	echo "#---------------------- MENU PRINCIPAL -----------------------#" | tee -a $ARQLOG
	echo "#-------------------------------------------------------------#" | tee -a $ARQLOG
	echo "# O que voce deseja fazer?                                     " | tee -a $ARQLOG
	echo "# 1 - Ativar a contigência em um site                          " | tee -a $ARQLOG
	echo "# 2 - Remover a contigência em um site                         " | tee -a $ARQLOG
	echo "# 3 - Sair                                                     " | tee -a $ARQLOG
	read -p "# R: " M1 # capturando o que digitar na tela
	echo "# R: $M1" >> $ARQLOG 
}

function MENU2(){
	clear
	echo "" | tee -a $ARQLOG
	echo "#-------------------------------------------------------------#" | tee -a $ARQLOG
	echo "# Por favor informe o site que deseja $tipo a contingencia     " | tee -a $ARQLOG
        for((a=1;a<=${#SITE[@]};a++));
        do
		echo "# [$a] ${SITE[$a]}" | tee -a $ARQLOG # Mostrando as opcoes disponiveis
        done
	read -p "# R: " CAIDO
	echo "# R: $CAIDO" >> $ARQLOG # capturando o que digitar na tela
	echo "" | tee -a $ARQLOG		
}

function MSGFIM(){
	DATA
	echo ""	| tee -a $ARQLOG
	echo "#-------------------- Script Finalizado ----------------------#" | tee -a $ARQLOG
	echo -e "#--------------------$CAM $DATA $CF----------------------#" | tee -a $ARQLOG # Mostrando a data na tela
	echo ""	| tee -a $ARQLOG
}

function CAPTURASITES(){ 
	a=1
	for i in `ls *.redes` # Capturar todos os arquivos com final .redes transoformando em opcao
	do
		SITE[$a]=$i
		let a=$a+1
	done
}

function VALIDAOPCAO2(){ # Validando o que foi digitado no menu 2
	for((a=1;a<=${#SITE[@]};a++));
        do
		if [ $CAIDO == $a ];then # se o numero digitado estiver dentro do contado do vetor
		 	m2=1 # entao ele sai do segundo while
		fi
        done
	if [ $m2 != 1 ];then # Caso tenha digita uma opcao invalida
		MSGOPCAOINVALIDA
	fi
} 
function MSGOPCAOINVALIDA(){
	echo -e "\nEntre com uma opcao valida!" | tee -a $ARQLOG 
	echo -e "Precione qualquer tecla para voltar..." | tee -a $ARQLOG
	read 
}

function CONFVARIAVEIS(){
	FROM=${SITE[$CAIDO]} # O site caido sempre sera o FROM, ex 1.fw01.redes
	TO=${SITE[$a]} # Os sites para fechar a vpn, ex, 2.fw01.redes
	LEFTHOST=`ls $FROM | cut -d. -f2` # usado para nomear o arquivo de vpn, ex: fw01
	RIGHTHOST=`ls $TO | cut -d. -f2` # usado para nomear o arquivo de vpn, ex: fw02
	ARQUIVOVPN=ipsec.$LEFTHOST-to-$RIGHTHOST # arquivo de ipsec sera ipsec.fw01-to-fw02
	LEFT=`grep left= $FROM`; # IP do left peer, ex 200.2.2.2
	RIGHT=`grep left= $TO|sed 's/left/right/g'`; # IP do right peer, ex 189.9.9.9, é feito a troca pois ó controle é feito pelo leftnexthop
	LEFTNEXTHOP=`grep leftnexthop= $FROM`; # capturando o IP do left next hop, ex 200.200.200.1 
	LEFTIP=`echo $LEFT|cut -d= -f2` # capturando o IP do peer left, ex 200.200.200.2
	RIGHTIP=`echo $RIGHT|cut -d= -f2` # capturando o IP do peer right, ex 187.8.8.8
	LEFTTYPE=`grep -i linux $FROM | cut -d= -f2` # capturando se o left e linux ou nao, 0 ou 1
	RIGHTTYPE=`grep -i linux $TO | cut -d= -f2` # capturando se o right e linux ou nao, 0 ou 1
}

function CRIACONEXAO(){ # Criando o arquivo de ipsec
	rm -f $ARQUIVOVPN 2>/dev/null; # Removendo Arquivos de VPN Anteriroes
	rm -f $ARQUIVOVPN-from 2>/dev/null; # Removendo Arquivos de VPN Anteriroes

	for e in `cat $FROM|grep INTERNA` # filtrando apenas as redes com nome internal
	do
		leftconn=`echo $e|cut -d# -f2`; # capturando o nome da leftconn
		leftsubnet=`echo $e|cut -d# -f1`; # caputrando a left subnet para a vpn
		for j in `cat $TO|grep \#` # capturando qualquer lihha que tenha #
		do
			rightconn=`echo $j|cut -d# -f2`; # capturando o nome do rightcoon 
			rightsubnet=`echo $j|cut -d# -f1`; # capturando a right subnet para a vpn
			CONFIPSEC # criando o arquivo de ipsec
		done	
	done
	
	for e in `cat $TO|grep INTERNA` # Mesmo procesimento a cima no entando apenas para as redes nao internas
	do # usado para impedir de fechar a VPN com duas redes não internas ex, dois clientes em lugares diferentes
		leftconn=`echo $e|cut -d# -f2`;
		rightsubnet=`echo $e|cut -d# -f1`;
		for k in `cat $FROM|grep \#|grep -v INTERNA`
		do
			leftsubnet=`echo $k|cut -d# -f1`
			rightconn=`echo $k|cut -d# -f2`;
			CONFIPSEC
		done
	done
	rightnexthop=`grep leftnexthop= $TO|cut -d= -f2`; # capturando o rightnethop
	sed "s/$LEFTNEXTHOP/rightnexthop=$rightnexthop/g" $ARQUIVOVPN >$ARQUIVOVPN-from; #criando o segundo arquivo de vpn para o site remoto
}

function CONFIPSEC(){ #Configuracoes basicas do ipsec, caso precise alterar criptografia ou tempos edite as linhas a baixo
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

function COPIAARQUIVOS(){ # funcao para copiar e mover os arquivos de ipsec
	if [ $LEFTTYPE -eq 1 ];then # Caso seja linux
		timeout $TIME scp -P $PORTA $ARQUIVOVPN $USER@$LEFTIP:/tmp > /dev/null 2>&1 # copia o arquivo de ipsec para o $LEFTIP
		T=$?; FASELOG=1; LOGTELA # valida o resultado 
	else # caso nao seja linux sera ignorado, ex localidade com firewall de algum fabricante
		T=2; FASELOG=1; LOGTELA # T=2 para nao linux
	fi
	if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME scp -P $PORTA $ARQUIVOVPN-from $USER@$RIGHTIP:/tmp > /dev/null 2>&1 #copiar o arquivo de ipsec para o $RIGHTIP
		T=$?; FASELOG=2; LOGTELA
	else	
		T=2; FASELOG=2; LOGTELA
	fi
	
	if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo mv /tmp/$ARQUIVOVPN /etc/ipsec.d/ > /dev/null 2>&1 # move o arquivo do /tmp/ para o diretorio do ipsec
		T=$?; FASELOG=3; LOGTELA
	else	
		T=2; FASELOG=3; LOGTELA
	fi
	if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo mv /tmp/$ARQUIVOVPN-from /etc/ipsec.d/ > /dev/null 2>&1 
		T=$?; FASELOG=4; LOGTELA
	else
		T=2; FASELOG=4; LOGTELA
	fi
		
}

function RESTARTIPSEC(){ # funcao para reinciar o ipsec em ambas as pontas
	if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo /etc/init.d/ipsec restart > /dev/null 2>&1 
		T=$?; FASELOG=5; LOGTELA
	else
		T=2; FASELOG=5; LOGTELA
	fi
	if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo /etc/init.d/ipsec restart > /dev/null 2>&1 
		T=$?; FASELOG=6; LOGTELA
	else
		T=2; FASELOG=6; LOGTELA
	fi
}

function DELETAARQUIVOS(){ # Funcao para deletar os arquivos de ipsec em ambas as pontas
	if [ $LEFTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$LEFTIP sudo rm /etc/ipsec.d/$ARQUIVOVPN >>/dev/null 2>&1
		T=$?; FASELOG=7; LOGTELA
	else
		T=2; FASELOG=7; LOGTELA
	fi
	if [ $RIGHTTYPE -eq 1 ];then
		timeout $TIME ssh -p $PORTA $USER@$RIGHTIP sudo rm /etc/ipsec.d/$ARQUIVOVPN-from >>/dev/null 2>&1
		T=$?; FASELOG=8; LOGTELA
	else
		T=2; FASELOG=8; LOGTELA
	fi
	rm $ARQUIVOVPN $ARQUIVOVPN-from > /dev/null 2>&1 # Deletando arquivos ipsec localmente
}

function LOGTELA(){ # funcao para mostrar log em tela e salvar no arquivo
	case $FASELOG in
		1) 
			TESTAT # funcao que valida o valor de T
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
			echo "OPCAO NAO INVALIDA" | tee -a $ARQLOG
			;;
	esac

}

function TESTAT(){ #Validando o valor de T
	case $T in	
		"0") # caso 0 quer dizer que funcionou
			echo -ne "[$CVD OK $CF]\t\t " | tee -a $ARQLOG			
			;;
		"2") # caso 2 quer dizer que a ponta nao é linux
			echo -ne "[$CAM IGNORADO $CF]\t " | tee -a $ARQLOG			
			;;
		*) # qualquer outro valor quer dizer que houve erro na execucao
			echo -ne "[$CVE FALHA $CF]\t " | tee -a $ARQLOG			
			;;
	esac
}

function DATA(){ # Configurando data para a tela e log
	DIA=`date "+%y%m%d"` > /dev/null # Data yymmdd
	HORA=`date "+%H:%M:%S"` > /dev/null # Hora hh:mm:ss
	DATA="$DIA - $HORA" # Juntando DIA e HORA
}

function CONFCOR(){ # Configurando variaveis com cor
	CVE='\e[1;31m' # Red Bold
	CVD='\e[1;32m' # Verde Bold
	CAM='\e[1;33m' # Yellow Bold
	CF='\e[0m'    # Tag end
}

MAIN #Funcao principal que inicia o script
exit;
