: <<COMMENT
Code realise sur clavier qwerty model us sans accent
*** MODE D'EMPLOI DU SCRIPT ***
1. Pour executer : source ./tp1.sh
2. Pour executer en arriere plan : source ./tp1.sh &
3. Pour acceder au panneau de commande : taper 'command' quand l'execution est en arriere plan
ou taper 'source ./tp1.sh command' quand le script n'est pas execute.
COMMENT

#Verifie que les dossiers et fichiers necessaire sont present et les creer au besoin
if ! [[ -d /sysadmins ]]; then
	sudo mkdir /sysadmins;
	sudo mkdir -m 777 /sysadmins/backup;
	sudo mkdir -m 777 /sysadmins/logs;
fi;

if ! [[ -e /sysadmins/fichier.conf ]]; then
	sudo touch /sysadmins/fichier.conf;
	sudo chown $USER: /sysadmins/fichier.conf;
	echo "srv=https://script-2-tp-1-api.0vxq7h.easypanel.host/5" >> /sysadmins/fichier.conf
	echo "courriel=dodolesingepremier@gmail.com" >> /sysadmins/fichier.conf
	echo "start=0" >> /sysadmins/fichier.conf
fi

#Creer la tache crontab pour les sauvegardes si elle n'est pas presente
if ! crontab -l | grep -q "sauvegarde"; then
	save="0 0 * * mon /home/arno/tp1.sh demarrerSauvegarde"
	(crontab -l ; echo "$save") | crontab -
fi

function tester () {
	code=$(curl -s -o /dev/null -w "%{http_code}" $serveur)
}

function verificationServeur () {
	erreur=false;
	num=0;
	for i in 1 2 3; do
		tester;
		if [[ $code -eq "200" ]]; then
			break;
		else
			((num++));
			if [[ $num -eq 3 ]]; then
				erreur=true;
			fi
		fi
		sleep 5
	done
}

function envoyerCourriel () {
	SENDGRID_API_KEY="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"
	FROM_EMAIL="arnaud@poussier.ca"
	TO_EMAIL="$mail"
	SUBJECT="ERREUR"
	BODY="Bonjour,\nNous vous informons qu'une tentative de communication avec le serveur a eu lieu le $date à $heure.\nCette tentative s'est soldée par un échec.\n\nCode d'erreur : $code"
	SENDGRID_API_URL="https://api.sendgrid.com/v3/mail/send"
	DATA='{
	"personalizations": [
	{
		"to": [
		{
			"email": "'"$TO_EMAIL"'"
		}
		],
		"subject": "'"$SUBJECT"'"
	}
	],
	"from": {
	"email": "'"$FROM_EMAIL"'"
},
"content": [
{
	"type": "text/plain",
	"value": "'"$BODY"'"
}
]
}'
curl -X POST \
	$SENDGRID_API_URL \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $SENDGRID_API_KEY" \
	-d "$DATA"
}

function command () {
	while true; do
		choix=""
		if [[ $invalid == false ]]; then
			echo "
 _______ _______  ______ _    _ _____ _______ _____ _______ _______ _______  _____   ______
 |______ |______ |_____/  \  /    |   |______   |   |       |_____|    |    |     | |_____/
 ______| |______ |    \_   \/   __|__ |       __|__ |_____  |     |    |    |_____| |    \_
                                                                                           
"
			echo "(a) Afficher la durée totale d'execution du script."
			echo "(b) Afficher le nombre d'erreurs depuis le début de l’exécution du script."
			echo "(c) Indiquer si le serveur est actuellement opérationnel."
			echo "(d) Supprimer toutes les sauvegardes (zip)."
			echo "(e) Changer le courriel dans le fichier de configuration."
			echo "(f) Sauvegarder les fichiers logs maintenant."
			echo "(k) Arreter l'execution du programme."
			echo "(q) Quitter."
			echo ""
		fi
		invalid=false
		while [[ $choix == "" ]]; do
			read -p "Entrer votre choix : " choix
		done
		case "$choix" in
			"a")
				afficherDuree
				;;
			"b")
				afficherErreur
				;;
			"c")
				verifierServeur
				;;
			"d")
				supprimerSauvegarde
				;;
			"e")
				changerCourriel
				;;
			"f")	
				sauvegarde
				;;
			"k")	
				stopper
				break
				;;
			"q")
				break
				;;
			*)
				echo "Veuillez entrer un choix valide."
				invalid=true
				;;
		esac
	done
}

function sauvegarde () {
	nblog=$(ls /sysadmins/logs/*.log 2>/dev/null | wc -l)
	nomErreurZip="backup_$(date +'%Y-%m-%d')_error.zip"
	nomZip="backup_$(date +'%Y-%m-%d').zip"
	if [[ $nblog != 0 ]]; then
		if ! [[ -e /sysadmins/backup/$nomErreurZip || -e /sysadmins/logs/$nomZip ]]; then
			demarrerSauvegarde
		else
			read -p "ATTENTION : il existe deja une sauvegarde pour cette date. Voulez-vous l'ecraser ? (y) pour oui, (n) pour non : " choix
			if [[ $choix == "y" ]]; then
				demarrerSauvegarde
			else
				return
			fi
		fi
		echo ""
		echo "$nblog fichier(s) sauvegarde(s) avec succes !"
		echo "Appuyez sur une touche pour continuer..."
		read -n 1 -s
		return
	fi
	echo "ERREUR : Auncuns fichiers logs ici."
}

function demarrerSauvegarde(){
	cd /sysadmins/logs
	sudo zip -r /sysadmins/backup/$nomErreurZip ./*.error.log
	sudo rm *.error.log 2>/dev/null
	sudo zip -r /sysadmins/backup/$nomZip ./*.log
	sudo rm * 2>/dev/null
	cd ~
}

function afficherDuree () {
	source /sysadmins/fichier.conf
	startTime=$start
	currentTime=$(date +%s)
	elapsedTime=$((currentTime - startTime))
	jours=$((elapsedTime / 86400))
	heures=$((elapsedTime / 3600))
	minutes=$(( (elapsedTime % 3600) / 60 ))
	secondes=$((elapsedTime % 60))
	echo "Le script est en cours d'exécution depuis DD:HH:MM:SS : $jours:$heures:$minutes:$secondes"
	echo "Appuyez sur une touche pour continuer..."
	read -n 1 -s 
}

function afficherErreur () {
	echo "Le nombre d'erreur depuis l'execution du script est : $nbErreur"
	if [[ -e /sysadmins/logs/*.error.log ]]; then
		echo "Historique d'erreur(s) :"
		cat /sysadmins/logs/*.error.log
	fi
	if ! [[ -z $(ls -A /sysadmins/backup/) ]]; then
		dezipper
	fi
	echo "Appuyez sur une touche pour continuer..."
	read -n 1 -s 
}

function verifierServeur () {
	verificationServeur
	if $erreur; then
		echo "Le serveur $serveur n'est pas operationnel"
		echo "$(date +"%Y-%m-%d %H:%M") : ECHEC de la communication avec le serveur [verification manuelle]" >> "/sysadmins/logs/$date.error.log"
	else
		echo "Le serveur $serveur est operationnel"
		echo "$(date +"%Y-%m-%d %H:%M") : SUCCES de la communication avec le serveur [verification manuelle]" >> "/sysadmins/logs/$date.log"
	fi
	echo "Appuyez sur une touche pour continuer..."
	read -n 1 -s
}

function supprimerSauvegarde () {
	choix=""
	if ! [[ -z $(ls -A /sysadmins/backup/) ]]; then
		while [[ $choix == "" ]]; do
			read -p "Etes-vous sur de vouloir supprimer toutes les sauvegardes ? (y) pour oui, (n) pour non : " choix
		done
		if [[ $choix == "y" ]]; then
			sudo rm -f /sysadmins/backup/*
			if [[ $? == 0 ]]; then
				echo "Toutes les sauvegardes ont ete supprimees avec succes !"
				echo "$(date +"%Y-%m-%d %H:%M") : SUPPRESSION des sauvegardes" >> "/sysadmins/logs/${date}.log"
			fi
		else
			echo "ECHEC de la suppression des sauvegardes"
			return
		fi
	else
		echo "ERREUR : il n'y a aucunes sauvegardes a supprimer."

	fi
	echo "Appuyez sur une touche pour continuer..."
	read -n 1 -s
}

function changerCourriel () {
	echo "Courriel actuel : $mail"
	nouveauCourriel=$mail
	while ! [[ $nouveauCourriel == "q" ]]; do
		read -p "Veuillez indiquer le nouveau courriel [(q) pour quitter] : " nouveauCourriel
		if [[ -n $nouveauCourriel && $nouveauCourriel != "q" ]]; then
			read -p "Veuillez confirmer le nouveau courriel : " nouveauCourriel2
			if [[ $nouveauCourriel == $nouveauCourriel2 ]]; then
				sudo sed -i "2s/.*/"courriel=$nouveauCourriel"/" "/sysadmins/fichier.conf"
				echo "Le nouveau courriel est : $nouveauCourriel"
				echo "$(date +"%Y-%m-%d %H:%M") : NOUVEAU courriel defini pour $nouveauCourriel" >> "/sysadmins/logs/$date.log"
				echo "Appuyez sur une touche pour continuer..."
				read -n 1 -s
				return
			else
				echo "ERREUR : Les courriels ne correspondent pas, veuillez recommencer."
			fi
		fi
	done
}

function stopper () {
	pid=$(pgrep "bash")
	for p in $pid; do
		kill $p
		if [[ $? -eq 0 ]]; then
			echo "Le programme avec le PID $p a bien ete stoppe."
		fi
	done
	echo "$(date +"%Y-%m-%d %H:%M") : ARRET du programme manuellement" >> "/sysadmins/logs/$date.log"
}

function dezipper () {
	fichierError=$null
	cd /sysadmins/backup/
	for fichierZip in *error.zip; do
		unzip -j "$fichierZip"
	done

	for fichierError in *error.log; do
		cat $fichierError
	done

	sudo rm -f *error.log
	cd /home/$USER
}

function editerStart () {
	depart=$(date +%s)
	sudo sed -i "3s/.*/"start=$depart"/" "/sysadmins/fichier.conf"
}

#Demarrage du script ici!
source /sysadmins/fichier.conf
editerStart
fichierConf="/sysadmins/fichier.conf"
nbErreur=0
mail=$courriel
invalid=false
serveur=$srv

if [[ $1 == "command" ]]; then
	command

elif [[ $1 == "sauvegarde" ]]; then
	sauvegarde

else
	while true; do
		date=$(date +"%Y-%m-%d")
		heure=$(date +"%H:%M")
		fichierErreur="${date}.error.log"
		fichierJournal="${date}.log"

		if ! [[ -e /sysadmins/logs/$fichierJournal ]]; then
			touch /sysadmins/logs/$fichierJournal;
		fi

		verificationServeur

		if $erreur; then
			((nbErreur++))
			if ! [[ -e /sysadmins/logs/$fichierErreur ]]; then
				touch /sysadmins/logs/$fichierErreur;
			fi

			envoyerCourriel "$message";

			if [[ $? ]]; then
				echo "$date $heure : ENVOIE du courriel a $mail" >> "/sysadmins/logs/$fichierJournal"
			fi

			echo "$date $heure : ECHEC de la communication avec le serveur : Code $code" >> "/sysadmins/logs/$fichierErreur"

		else
			echo "$date $heure : SUCCES de la communication avec le serveur" >> "/sysadmins/logs/$fichierJournal"
		fi

		sleep 60;
	done
fi