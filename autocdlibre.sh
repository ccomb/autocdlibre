#!/bin/bash
# name: autocdlibre
# Ce script permet de télécharger automatiquement les dernières versions
# de certains logiciels libres et de les graver sur un cd
# ATTENTION : l'encodage de ce fichier est l'UTF-8
##################################################################
# Copyright (C) 2004 Christophe Combelles (ccomb@free.fr)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
##################################################################

# pour déboguer ce script, décommentez la ligne suivante
#set -x

# on vire les alias
unalias -a

# version de ce script
autocdlibre_version=21
# où récupérer les infos
autocdlibre_email="ccomb@free.fr"
autocdlibre_server="ccomb.free.fr"
autocdlibre_url="http://$autocdlibre_server/autocdlibre"
autocdlibre_home="http://$autocdlibre_server/wiki/wakka.php?wiki=AutoCdLibre"

# analyse des arguments
while [ $# -gt 0 ]; do
	case $1 in
	"-h"|"--help")
		echo
		echo "AutoCdLibre v$autocdlibre_version : pour créer un CD de logiciels libres pour Windows"
		echo "Lancez simplement ce script sans argument, et il s'occupera de tout."
		echo "Pour plus d'infos consultez $autocdlibre_home"
		echo
		echo "Syntaxe : $0 [-h][-nosrc][-arbre][-noburn]"
		echo "-h      : ce petit texte d'aide"
		echo "-nosrc  : ne pas inclure les codes sources"
		echo "-arbre  : stopper après la creation de l'arborescence du CD"
		echo "-noburn : stopper juste avant la gravure."
		echo "-auto   : valider toutes les questions par défaut"
		echo
		exit ;;
	"-nosrc") NOSRC=1;;
	"-arbre") ARBRE=1;;
	"-noburn") NOBURN=1;;
	"-auto") AUTO=1;;
	esac
	shift
done

# on vérifie qu'on a tout ce dont on a besoin
aton() {
which $1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "J'ai besoin du programme \"$1\". Veuillez l'installer"
	exit
fi
}
for prog in which echo wget cdrecord mkisofs grep head basename pwd find awk cut uniq date unzip dig expr seq; do
	aton $prog
done

# chemin du script
script=`pwd`/$0

# on affiche le numéro de version
echo
echo "autocdlibre v$autocdlibre_version"

# on regarde si on est en UTF-8 ou pas
utf8=`echo $LANG|grep UTF-8`
if [ -z "$utf8" ]; then
	echo
	echo "Vous ne semblez pas utiliser l'unicode (UTF-8) dans votre paramètre de langue."
	echo "Certains caractères peuvent mal s'afficher dans votre terminal GNU."
	echo "Cependant, tout devrait s'afficher correctement sous Windows"
	echo
	sleep 2
fi

# on vérifie qu'on a les droits en écriture sur le répertoire actuel
fichiertest=autocdlibre_test_ecriture.$$
if [ ! -e $fichiertest ]; then
	touch $fichiertest
	if [ ! -e $fichiertest ]; then
		echo "vous n'avez pas les droits en écriture sur le répertoire courant. Je ne peux pas continuer"
		exit
	fi
	rm -f $fichiertest
fi

# on teste la connexion au net
echo -n "Test de l'accès à internet..."
dig +time=2 $autocdlibre_server > /dev/null 2>&1
test1=$?
if [ $test1 -eq 0 ]; then
	ping -q -c 2 $autocdlibre_server > /dev/null 2>&1
	test2=$?
	if [ $? -eq 0 ]; then reseau=1; echo OK; else reseau=0; echo ECHEC; fi
else reseau=0; echo ECHEC; fi

# on récupère le numéro de la dernière version (si on a la connexion au net)
echo "vérification de la dernière version..."
rm -f latest_version
if [ $reseau -eq 1 ]; then wget -O latest_version -T 4 -q $autocdlibre_url/latest_version; fi
if [ -e latest_version -a $reseau -eq 1 ]; then
	latest_version=`cat latest_version`
	rm -f latest_version
	# on vérifie qu'on a la dernière version
	if [ $latest_version -gt $autocdlibre_version ]; then
		# on télécharge et on affiche le changelog
		for i in `seq \`expr $autocdlibre_version + 1\` $latest_version`; do
			wget -c -T 4 -q $autocdlibre_url/changelog_v$i
		done
		echo "  La nouvelle version (v$latest_version) de ce script est disponible."
		echo "-------"
		echo "  Modifications depuis la version $autocdlibre_version :"
		for i in `seq \`expr $autocdlibre_version + 1\` $latest_version`; do
			echo "Dans la version $i :"
			cat changelog_v$i 2>/dev/null
		done
		echo "-------"
		echo -n "Voulez-vous récupérer et utiliser cette nouvelle version ? (o/n) [o] "
		if [ "$AUTO" != "1" ]; then read reponse; else echo; fi
		# on télécharge et on exécute la nouvelle version
		if [ "$reponse" = "o" -o "$reponse" = "O" -o "$reponse" = "" -o "$reponse" = "oui" -o "$reponse" = "OUI" ]; then
			echo "  Récupération de la dernière version..."
			wget -c -q $autocdlibre_url/autocdlibre_v$latest_version.sh
			chmod +x autocdlibre_v$latest_version.sh
			echo "Exécution de la nouvelle version :"
			./autocdlibre_v$latest_version.sh $@
			exit
		else echo "  OK, on garde la version actuelle."
		fi
	else echo "  Pas de nouvelle version disponible. On garde la version actuelle (v$autocdlibre_version)."
	fi
else echo "  Impossible de récupérer la dernière version de ce script. On garde la version actuelle."
fi

repcd="autocdlibre_v$autocdlibre_version"
cdname=autocdlibre_v$autocdlibre_version.iso
reptelech=fichiers_telecharges_v$autocdlibre_version

demande_effacement() {
	item=$1
	if [ -d $item ]; then
		echo; echo "Le répertoire $item ne sert plus à rien. Voulez-vous l'effacer ?"
		printf "rm -rf $item ? (o/n) [o] ?"
		if [ "$AUTO" != "1" ]; then read reponse; else echo; fi
		if [ "$reponse" = "o" -o "$reponse" = "O" -o "$reponse" = "" -o "$reponse" = "oui" -o "$reponse" = "OUI" ]; then
			echo "Effacement de $item..."
			rm -rf "$item"
		fi
	else if [ -e $item ]; then
		echo; echo "Le fichier $item ne sert plus à rien. Voulez-vous l'effacer ?"
		printf "rm -f $item ? (o/n) [o] ?"
		if [ "$AUTO" != "1" ]; then read reponse; else echo; fi
		if [ "$reponse" = "o" -o "$reponse" = "O" -o "$reponse" = "" -o "$reponse" = "oui" -o "$reponse" = "OUI" ]; then
			echo "Effacement de $item..."
			rm -f "$item"
		fi
	fi; fi  
}

sortie_propre() {
	echo
	echo "Les fichiers téléchargés sont conservés dans $reptelech."
	if [ -d $repcd -a -f $cdname -a -d $reptelech ]; then
		echo "L'arborescence du CD ne sert plus à rien. Voulez vous l'effacer ?"
		printf "rm -rf $repcd ? (o/n) [o] ?"
		if [ "$AUTO" != "1" ]; then read reponse; else echo; fi
		if [ "$reponse" = "o" -o "$reponse" = "O" -o "$reponse" = "" -o "$reponse" = "oui" -o "$reponse" = "OUI" ]; then
			echo "Effacement de l'arborescence du CD..."
			rm -rf $repcd
		fi
	fi
	# on efface les anciens autocdlibres
	if [ -d $reptelech ]; then
		i=0
		while [ $i -lt $autocdlibre_version ]; do
				demande_effacement autocdlibre_v$i
				demande_effacement autocdlibre_v${i}.iso
				demande_effacement fichiers_telecharges_v$i
				i=$((i+1))
		done
	fi

	echo "Si vous pensez que ce CD n'est pas à jour avec les dernières versions, ou pour toute autre remarque ou question,"
	echo "veuillez envoyer un mail à $autocdlibre_email, ou rendez-vous à $autocdlibre_home"
	exit
}
trap sortie_propre INT
trap sortie_propre TERM
trap sortie_propre QUIT
trap sortie_propre HUP

# si une image iso est prête
if [ -f $cdname ]; then
	echo
	echo "Une image ISO du cd $cdname semble déjà prête."
	echo -n "Voulez-vous l'utiliser pour graver directement ? (o/n) [o] "
	if [ "$AUTO" != "1" ]; then read reponse; else echo; fi
fi
if [ ! -f $cdname -o "$reponse" != "o" -a "$reponse" != "O" -a "$reponse" != "" -a "$reponse" != "oui" -a "$reponse" != "OUI" ]; then 
	# on prépare le répertoire pour l'arborescence
	mv_to_old() { if [ -e $*.old ]; then mv_to_old $*.old; fi; mv $* $*.old; }
	if [ -d $repcd ]; then mv_to_old $repcd ; fi
	mkdir $repcd
	# on crée un répertoire de téléchargement
	mkdir -p $reptelech
	# on démarre l'analyse des commandes en fin de script
	rm -f ERROR
	awk -v repcd=$repcd -v reseau=$reseau -v reptelech=$reptelech -v nosrc=$NOSRC '
BEGIN { ORS="\r\n"; insource=0; infile=0 }
/^%#/ { next }
/^#%/ { next }
/^$/ { if(infile==0) next }
/^%DIR/  { insource=0; infile=0; sub("%DIR ",""); system("mkdir -p \"" repcd "/" $0 "\""); dir=repcd "/" $0; if($NF=="source") { if(nosrc==1) { insource=1; next }}}
/^%FILE/ { if(insource==1) next; infile=1; sub("%FILE ",""); file=$0; next }
/^%URL/  { if(insource==1) next; infile=0; if($1=="%URLZIP") { unzip=1; sub("%URLZIP ","")} else {unzip=0; sub("%URL ","")}; system("echo -n \"Récupération de `basename \"" $0 "\"`...\"; nom=`basename \"" $0 "\"`; ailleurs=\"`find . -name \"$nom\"| head -1`\"; if [ ! -z \"$ailleurs\" ]; then echo -n \"déjà téléchargé, \"; fi; if [ ! -z \"$ailleurs\" -a \"" reptelech "/$nom\" != \"$ailleurs\" -a ! -e \"" reptelech "/$nom\" ]; then ln \"$ailleurs\" " reptelech "; fi; if [ \"" reseau "\" = \"1\" ]; then wget -q -c \"" $0 "\" -P " reptelech "; fi; if [ -e \"" reptelech "/$nom\" ]; then ln \"" reptelech "/$nom\" \"" dir "\"; echo \"OK\"; else printf \"\\e[7mECHEC\\e[m\n\"; touch ERROR; fi; if [ \"" unzip "\" = \"1\" ]; then echo \"  Décompression de $nom...\"; unzip \"" dir "/$nom\" -d \"" dir "\" >/dev/null 2>&1; rm -f \"" dir "/$nom\"; fi"); }
{ if(insource==1) next; if(infile==1) { print $0 >> repcd "/" file }
}' $script 
	# on écrit le numéro de version dans le cd
	echo -n "CD-ROM généré le `date '+%A %d %B %Y'` par le script \"autocdlibre\" version $autocdlibre_version ($autocdlibre_url)" > $repcd/info
	if [ -e ERROR ]; then
		rm -f ERROR
		echo
		echo "Au moins un fichier n'a pas pu être téléchargé."
		echo "Veuillez relancer le script une ou deux fois et, si l'échec se répète, 
		echo "merci de prévenir à l'adresse $autocdlibre_email"
		exit
	fi
	echo "Téléchargement terminé, arborescence du CD terminée"

	# si demandé, on s'arrête
	if [ "$ARBRE" = "1" ]; then echo "arrêt demandé après création de l'arborescence"; sortie_propre; fi

	# on construit l'image du cd
	echo -n "Construction de l'image ISO du cd..."
	mkisofs -quiet -rJ -V L.\ Libres\ v$autocdlibre_version -o $cdname $repcd >/dev/null 2>&1
	if [ $? -eq 0 ]; then echo OK; else printf "\e[7mECHEC\e[m\n"; sortie_propre; fi
fi


# on cherche le premier graveur disponible (k2.6)
echo -n "Recherche du premier graveur..."
for protocole in `cdrecord dev=help 2>&1 |grep Transport\ name | cut -f3 | grep -v RSCSI | uniq`; do
	for graveur in `cdrecord dev=$protocole -scanbus 2>&1 |grep '.,.,.'|grep -v '*'|cut -f2`; do
	cdrecord dev=$protocole:$graveur -prcap -prcap 2>&1 | grep -q 'Does write CD-R media'
	if [ $? -eq 0 ]; then device=$protocole:$graveur; break; fi
	done
	if [ ! -z "$device" ]; then break; fi
done

# si pas de graveur, on essaye l'ancienne méthode (k2.4)
if [ -z "$device" ]; then
	for graveur in `cdrecord -scanbus 2>&1 |grep '.,.,.'|grep -v '*'|cut -f2`; do
		cdrecord dev=$graveur -prcap -prcap 2>&1 | grep -q 'Does write CD-R media'
		if [ $? -eq 0 ]; then device=$graveur; break; fi
	done
fi

# pas de graveur, pas la peine d'aller plus loin.
if [ -z "$device" ]; then
	printf "\e[7mECHEC\e[m\n"
	echo "Aucun graveur trouvé. Je ne peux pas continuer."
	sortie_propre
else echo "graveur trouvé : $device"
fi

# si demandé, on s'arrête
if [ "$NOBURN" = "1" ]; then
	echo "Arrêt demandé avant la gravure"
	echo "L'image ISO est conservée sous le nom $cdname."
	sortie_propre
fi

# on grave
echo -n "Démarrage de la gravure..."
res=1; num=0
while [ $res -ne 0 ]; do
	cdrecord dev=$device driveropts=burnfree -eject $cdname >/dev/null 2>&1
	res=$?; let num++
	if [ $num -eq 3 ]; then echo; printf "\e[7mERREUR\e[m : je n'arrive pas à graver. Je ne peux pas terminer"; sortie_propre; fi
	if [ $res -ne 0 ]; then echo; echo "Veuillez insérer un CD vierge dans le graveur, et pressez ENTER"; echo "(ou Ctrl-C pour interrompre)"; if [ "$AUTO" != "1" ]; then read; fi; fi
done
echo OK
echo "Gravure terminée. L'image ISO est conservée sous le nom $cdname."

sortie_propre



exit
################################"
# liste des logiciels qu'on veut
# syntaxe :
# une commande DIR suivi d'un nombre arbitraire de commandes URL et FILE
# %DIR : sert à créer un répertoire
# %URL : sert à télécharger quelque chose dans le dernier répertoire créé
# %URLZIP : idem sauf qu'on décompresse (unzip seulement) avant de graver
# %FILE : sert à créer un fichier texte (attention à créer le répertoire avant le fichier)
# %# ou #% : sert à mettre un commentaire
# ATTENTION : pour que -nosrc fonctionne, les répertoires contenant les codes sources doivent s'appeler "code source"
################################"

#% GRISBI
%DIR Bureautique/Comptabilité personnelle
%URL http://ovh.dl.sourceforge.net/sourceforge/grisbi4win/grisbi-0.5.3-win32-gcc-041205-full.exe
%DIR Bureautique/Comptabilité personnelle/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/grisbi/grisbi-0.5.3.tar.bz2
%DIR Bureautique/Comptabilité personnelle/Manuel utilisateur
%URL http://ovh.dl.sourceforge.net/sourceforge/grisbi/grisbi-manuel-img-0.5.1.pdf
%FILE Bureautique/Comptabilité personnelle/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/grisbi/grisbi-0.5.3.tar.bz2

#% CLAMWIN
%DIR Internet/Scanner à virus
%URL http://ovh.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.37.3-setup.exe
%DIR Internet/Scanner à virus/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.37.3-src.zip
%FILE Internet/Scanner à virus/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.37.3-src.zip

#% HTTRACK
%DIR Internet/Aspirateur de site web
%URL http://download.httrack.com/httrack-3.32-2.exe
%DIR Internet/Aspirateur de site web/code source
%URL http://www.httrack.com/httrack-3.32-2.tar.gz
%FILE Internet/Aspirateur de site web/code source/codesource.txt
le code source peut être obtenu ici : http://www.httrack.com/httrack-3.32-2.tar.gz

#% NVU
%DIR Internet/Éditeur de site web
%URL http://frenchmozilla.sourceforge.net/FTP/Nvu-tmp/nvu-0.60-win32-installer-fr.exe
%DIR Internet/Éditeur de site web/code source
#%URL http://cvs.nvu.com/download/nvu-0.60-sources.tar.bz2
%FILE Internet/Éditeur de site web/code source/codesource.txt
le code source peut être obtenu ici :
http://cvs.nvu.com/download/nvu-0.60-sources.tar.bz2

#% ABIWORD
%DIR Bureautique/Traitement de texte seul
%URL http://ovh.dl.sourceforge.net/sourceforge/abiword/abiword-setup-2.2.1.exe
%URL http://ovh.dl.sourceforge.net/sourceforge/abiword/abiword-plugins-impexp-2.2.1.exe
%URL http://ovh.dl.sourceforge.net/sourceforge/abiword/abiword-plugins-tools-2.2.1.exe
%URL http://ovh.dl.sourceforge.net/sourceforge/abiword/AbiWord_Dictionrary_Francais.exe
%DIR Bureautique/Traitement de texte seul/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/abiword/abiword-2.2.2.tar.bz2
%FILE Bureautique/Traitement de texte seul/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/abiword/abiword-2.2.2.tar.bz2

#% OPENVIP
%DIR Multimedia/Montage vidéo
%URL http://ovh.dl.sourceforge.net/sourceforge/openvip/openvip-1.0.1-setup.exe
%DIR Multimedia/Montage vidéo/code source
%FILE Multimedia/Montage vidéo/code source/codesource.txt
Le code source de OpenVIP peut être consulté ici : http://cvs.sourceforge.net/viewcvs.py/openvip/

#% VIRTUALDUB
%DIR Multimedia/Capture et traitement de vidéo
%URLZIP http://puzzle.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10.zip
%DIR Multimedia/Capture et traitement de vidéo/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10-src.zip.bz2
%FILE Multimedia/Capture et traitement de vidéo/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10-src.zip.bz2

#% CORNICE
%DIR Multimedia/Visualiseur photos
%URL http://wxglade.sourceforge.net/extra/cornice-0.5.2-wx24-setup.exe
%DIR Multimedia/Visualiseur photos/code source
%URL http://wxglade.sourceforge.net/extra/cornice-0.5.2.tar.gz
%FILE Multimedia/Visualiseur photos/code source/codesource.txt
le code source peut être obtenu ici :
http://wxglade.sourceforge.net/extra/cornice-0.5.2.tar.gz

#% PDFCREATOR
%DIR Bureautique/Création de fichiers PDF
%URL http://ovh.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-0_8_0_GNUGhostscript.exe
%DIR Bureautique/Création de fichiers PDF/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-Source-0_8_0.zip
%FILE Bureautique/Création de fichiers PDF/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-Source-0_8_0.zip

#% THE GIMP
%DIR Multimedia/Retouche photo
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gtk+-2.4.9-setup.zip
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gimp-2.0.5-i586-setup.zip
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gimp-help-2-0.3-setup.zip
%FILE Multimedia/Retouche photo/installation.txt
Dans l'ordre, il faut installer :
- gtk+
- gimp
- gimp-help
- optionnellement les plugins
Consultez ensuite les tutoriels dans le dossier : Débuter avec GIMP

%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins.zip
%DIR Multimedia/Retouche photo/Débuter avec GIMP
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_v2.zip
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_2_v2.zip
%DIR Multimedia/Retouche photo/code source
ftp://ftp.arnes.si/software/gimp-win/gimp-2.0.4-src.zip
%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins-src.zip
%FILE Multimedia/Retouche photo/code source/codesource.txt
le code source peut être obtenu ici :
ftp://ftp.arnes.si/software/gimp-win/gimp-2.0.4-src.zip
ftp://ftp.arnes.si/software/gimp-win/gimp-plugins-src.zip

#% GHOSTSCRIPT ET GSVIEW
%DIR Bureautique/Visualiseur de fichiers PDF et Postscript
%URL http://ovh.dl.sourceforge.net/sourceforge/ghostscript/gs815w32.exe
%URL ftp://sunsite.cnlab-switch.ch/mirror/ghost/ghostgum/gsv46w32.exe
%FILE Bureautique/Visualiseur de fichiers PDF et Postscript/installation.txt
Il faut installer d'abord GhostScript (gs815w32.exe), puis GSView (gsv46w32.exe).
Le programme pour voir les fichiers PDF et PS est GSView.
%DIR Bureautique/Visualiseur de fichiers PDF et Postscript/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/ghostscript/ghostscript-8.15.tar.bz2
%URL ftp://sunsite.cnlab-switch.ch/mirror/ghost/ghostgum/gsv46src.zip
%FILE Bureautique/Visualiseur de fichiers PDF et Postscript/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/ghostscript/ghostscript-8.15.tar.bz2
ftp://sunsite.cnlab-switch.ch/mirror/ghost/ghostgum/gsv46src.zip

#% FILEZILLA
%DIR Internet/Transfert FTP
%URL http://ovh.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_9_setup.exe
%DIR Internet/Transfert FTP/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_9_src.zip
%FILE Internet/Transfert FTP/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_9_src.zip

#% DIA
%DIR Bureautique/Éditeur de diagrammes
%URLZIP http://ovh.dl.sourceforge.net/sourceforge/dia-installer/dia-setup-0.94.zip
%DIR Bureautique/Éditeur de diagrammes/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/dia-installer/dia-0.94.tar.bz2
%FILE Bureautique/Éditeur de diagrammes/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/dia-installer/dia-0.94.tar.bz2

#% BLENDER
%DIR Multimedia/Animation et rendu 3D
%URL http://download.blender.org/release/Blender2.35/blender-2.35a-windows.exe
%URLZIP http://download.blender.org/release/yafray.0.0.7/yafray-0.0.6-7-win.zip
%DIR Multimedia/Animation et rendu 3D/Vidéos de démo
%URL http://download.blender.org/demo/movies/ChairDivXS.avi
%URL http://download.blender.org/demo/movies/erosion2.avi
%URL http://download.blender.org/demo/movies/lassoselect_demo.avi
%URL http://download.blender.org/demo/movies/particle_heat_ray.mov
%URL http://download.blender.org/demo/movies/rotateedge_demo.avi
%URL http://download.blender.org/demo/movies/snowman.avi
%URL http://download.blender.org/demo/movies/stretchto_demo.avi
#%URL http://download.blender.org/demo/movies/artintro_final.avi
%DIR Multimedia/Animation et rendu 3D/Manuel (anglais)
%URLZIP http://download.blender.org/documentation/BlenderManualIen.23.pdf.zip
%URLZIP http://download.blender.org/documentation/BlenderManualIIen.23.pdf.zip
%DIR Multimedia/Animation et rendu 3D/code source
%URL http://download.blender.org/release/yafray.0.0.7/yafray-0.0.6-7-win.zip
%URL http://download.blender.org/source/blender-2.35.tar.bz2
%FILE Multimedia/Animation et rendu 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://download.blender.org/release/yafray.0.0.6/yafray-0.0.6-2-src.tar.gz
http://download.blender.org/source/blender-2.33a.tar.bz2

#% OPENOFFICE.ORG
%DIR Bureautique/Suite Bureautique Complète/OpenOffice.org 1.1.3
%URLZIP ftp://openoffice.cict.fr/openoffice/localized/fr/1.1.3/OOo_1.1.3_Win32Intel_install_fr.zip
%DIR Bureautique/Suite Bureautique Complète/code source
%FILE Bureautique/Suite Bureautique Complète/code source/codesource.txt
Le code source est énorme et peut être récupéré ici : ftp://openoffice.cict.fr/openoffice/stable/1.1.3/
#%URL ftp://openoffice.cict.fr/openoffice/stable/1.1.3/OOo_1.1.3_source.tar.gz
%DIR Bureautique/Suite Bureautique Complète/Manuels et documentation
%URL http://fr.openoffice.org/Documentation/Guides/Manuel_install1.1_v2.pdf
%URL http://fr.openoffice.org/Documentation/Guides/parcours_texte_ooo.pdf
%URL http://fr.openoffice.org/Documentation/Guides/guideDraw.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Andrew5.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Guide_comparatif_1.0.1.pdf
%URLZIP http://essai.pba.fr/Livre_pdf.zip

#% CDEX
%DIR Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis
%URL http://ovh.dl.sourceforge.net/sourceforge/cdexos/cdex_151.exe
%DIR Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis/code source
%FILE Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis/code source/codesource.txt
Voir ici : http://cvs.sourceforge.net/viewcvs.py/cdexos/cdex_xp/

#% 7-ZIP
%DIR Bureautique/Compression de fichiers (zip, gz, bz2, etc.)
%URL http://ovh.dl.sourceforge.net/sourceforge/sevenzip/7z413b.exe
%FILE Bureautique/Compression de fichiers (zip, gz, bz2, etc.)/lisez-moi.txt
Après installation de 7-zip, voici ce qu'il faut faire pour avoir le programme en français et un usage plus agréable :
- Menu Démarrer -> Programmes -> 7-zip -> 7-zip File Manager
- Dans le "7-zip File Manager", ouvrir le menu Tools -> Options
- Dans l'onglet "System" : cocher toutes les extensions pour les associer à 7-zip
- Dans l'onglet "Language" : sélectionner français
- Dans l'onglet "Plugins", cliquer sur "Options" et cocher "Cascaded context menu"
Ensuite fermer 7-zip.
Après ces réglages, 7-zip sera en français, le menu contextuel (clic droit) affichera un sous-menu global pour 7-zip, et tous les fichiers compressés seront automatiquement ouverts avec 7-zip.
%DIR Bureautique/Compression de fichiers (zip, gz, bz2, etc.)/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/sevenzip/7z413b.tar.bz2
%FILE Bureautique/Compression de fichiers (zip, gz, bz2, etc.)/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/sevenzip/7z413b.tar.bz2

#% EMULE
%DIR Internet/Téléchargement Peer2peer
%URL http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.44d-Installer.exe
%DIR Internet/Téléchargement Peer2peer/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.44d-Sources.zip
%FILE Internet/Téléchargement Peer2peer/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.44d-Sources.zip
%FILE Internet/Téléchargement Peer2peer/conseil.txt
Évidemment, tout le monde sait que le téléchargement des logiciels propriétaires et payants est illégal...
Mais il faut penser à quelque chose de beaucoup plus important et plus néfaste : 

En téléchargeant et en copiant des logiciels propriétaires payants,
vous augmentez la notoriété et la diffusion de ces logiciels,
et vous leur faites de la publicité inutilement.
Vous perdez du temps à apprendre des logiciels que vous n'avez pas le droit d'utiliser,
vous devenez dépendant d'un produit que vous risquez d'être obligé de payer un jour,
et dont la pérennité, le prix, la disponibilité, ou la compatibilité sont inconnus dans le futur.

Quelques exemples :

Au lieu de télécharger illégalement Photoshop, apprenez à utiliser GIMP.
Il est aussi performant, gratuit, légal,
et vous êtes sûr qu'il ne va jamais disparaître, ni devenir payant : c'est un Logiciel Libre.

Au lieu de télécharger illégalement Microsoft Office, apprenez OpenOffice.org,
il est gratuit, compatible, ouvert, facile à utiliser, plus stable, et il évolue plus vite.

#% INKSCAPE
%DIR Multimedia/Dessin vectoriel
%URL http://ovh.dl.sourceforge.net/sourceforge/inkscape/Inkscape-0.40-1.win32.exe
%DIR Multimedia/Dessin vectoriel/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.40.tar.bz2
%FILE Multimedia/Dessin vectoriel/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.40.tar.bz2

#% AUDACITY
%DIR Multimedia/Enregistreur et éditeur de sons
%URL http://ovh.dl.sourceforge.net/sourceforge/audacity/audacity-win-1.2.3.exe
%URL http://mitiok.free.fr/lame-3.96.1.zip
%DIR Multimedia/Enregistreur et éditeur de sons/mode d'emploi
%URLZIP http://audacity.sourceforge.net/audacity-manual-1.2.zip
%URL http://audacity.sourceforge.net/audacity-mode-d'emploi.pdf
%DIR Multimedia/Enregistreur et éditeur de sons/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/audacity/audacity-src-1.2.3.tar.gz
%FILE Multimedia/Enregistreur et éditeur de sons/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/audacity/audacity-src-1.2.3.tar.gz

#% MOZILLA
%DIR Internet/Suite internet complète (navigateur, e-mail, éditeur web)
%URL http://ovh.dl.sourceforge.net/sourceforge/frenchmozilla/mozilla-win32-1.7.3-installer-fr-FR.exe
#%URL http://frenchmozilla.sourceforge.net/FTP/1.7.1/mozilla-l10n-fr-FR-1.7.1.xpi
%DIR Internet/Suite internet complète (navigateur, e-mail, éditeur web)/manuel
%URL http://ovh.dl.sourceforge.net/sourceforge/frenchmozilla/mozman-1.35.fr.pdf
%DIR Internet/Suite internet complète (navigateur, e-mail, éditeur web)/code source
%URL http://ftp.mozilla.org/pub/mozilla.org/mozilla/releases/mozilla1.7.3/src/mozilla-source-1.7.3.tar.bz2
#%FILE Internet/Suite internet complète (navigateur, e-mail, éditeur web)/Comment installer la langue française.txt
#%- installez d'abord Mozilla lui-même 
#%- démarrez Mozilla et ouvrez le CD-ROM avec Mozilla
#%  (tapez D: ou la lettre correspondant à votre lecteur CD-ROM au lieu d'une adresse internet)
#%- retrouvez dans le CD-ROM le fichier mozilla-l10n-fr-FR-1.7.1.xpi et CLIQUEZ DESSUS depuis Mozilla
#%- confirmez l'installation
#%- allez dans le menu Edit->Preferences->Appearance->Languages/Content
#%- sélectionnez "Français" en haut, et "Région FR" en bas.
#%- cliquez sur OK et redémarrez Mozilla
%FILE Internet/Suite internet complète (navigateur, e-mail, éditeur web)/code source/codesource.txt
le code source peut être obtenu ici :
http://ftp.mozilla.org/pub/mozilla.org/mozilla/releases/mozilla1.7.3/src/mozilla-source-1.7.3.tar.bz2

#% FIREFOX
%DIR Internet/Navigateur Internet moderne
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/1.0/win32/fr-FR/Firefox Setup 1.0.exe
%DIR Internet/Navigateur Internet moderne/code source
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/1.0/source/firefox-1.0-source.tar.bz2
%FILE Internet/Navigateur Internet moderne/code source/codesource.txt
le code source peut être obtenu ici :
http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/1.0/source/firefox-1.0-source.tar.bz2

#% THUNDERBIRD
%DIR Internet/Logiciel de courrier électronique
%URL http://ftp.scarlet.be/pub/mozilla.org/thunderbird/releases/1.0/win32/fr-FR/Thunderbird Setup 1.0.exe
%DIR Internet/Logiciel de courrier électronique/code source
%URL http://ftp.scarlet.be/pub/mozilla.org/thunderbird/releases/1.0/source/thunderbird-1.0-source.tar.bz2
%FILE Internet/Logiciel de courrier électronique/code source/codesource.txt
le code source peut être obtenu ici :
http://ftp.scarlet.be/pub/mozilla.org/thunderbird/releases/1.0/source/thunderbird-1.0-source.tar.bz2

#% PRIVOXY
%DIR Internet/Filtrage pubs internet
%URL http://ovh.dl.sourceforge.net/sourceforge/ijbswa/privoxy_setup_3_0_3-2.exe
%DIR Internet/Filtrage pubs internet/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/ijbswa/privoxy-3.0.3-2-stable.src.tar.gz
%FILE Internet/Filtrage pubs internet/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/ijbswa/privoxy-3.0.3-2-stable.src.tar.gz
%FILE Internet/Filtrage pubs internet/comment utiliser Privoxy.txt
Pour utiliser privoxy :
dans Mozilla : menu Edition -> préférences -> avancé -> proxies -> configuration manuelle :
HTTP proxy = localhost
HTTP Port = 8118

#% ZINF
%DIR Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)
%URL http://ovh.dl.sourceforge.net/sourceforge/zinf/zinf-setup-2.2.1.exe
%DIR Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/zinf/zinf-2.2.1.tar.gz
%FILE Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/zinf/zinf-2.2.1.tar.gz

#% GAIM
%DIR Internet/Messagerie instantanée (icq, jabber, msn, etc.)
%URL http://ovh.dl.sourceforge.net/sourceforge/gaim/gaim-1.1.0.exe
%DIR Internet/Messagerie instantanée (icq, jabber, msn, etc.)/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/gaim/gaim-1.1.0.tar.bz2
%FILE Internet/Messagerie instantanée (icq, jabber, msn, etc.)/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/gaim/gaim-1.1.0.tar.bz2

#% VLC MEDIA PLAYER
%DIR Multimedia/Lecteur Vidéo et DVD
%URL http://download.videolan.org/pub/videolan/vlc/0.8.1/win32/vlc-0.8.1-win32.exe
%DIR Multimedia/Lecteur Vidéo et DVD/code source
%URL http://download.videolan.org/pub/videolan/vlc/0.8.1/vlc-0.8.1.tar.bz2
%FILE Multimedia/Lecteur Vidéo et DVD/code source/codesource.txt
le code source peut être obtenu ici :
http://download.videolan.org/pub/videolan/vlc/0.8.1/vlc-0.8.1.tar.bz2

#% CELESTIA
%DIR Divertissement/Visite univers en 3D
%URL http://ovh.dl.sourceforge.net/sourceforge/celestia/celestia-win32-1.3.2.exe
%DIR Divertissement/Visite univers en 3D/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/celestia/celestia-1.3.2.tar.gz
%FILE Divertissement/Visite univers en 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/celestia/celestia-1.3.2.tar.gz

#% BILLARD 3D
%DIR Divertissement/Billard en 3D
%URL http://ovh.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75-Setup.exe
%DIR Divertissement/Billard en 3D/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75.tar.gz
%FILE Divertissement/Billard en 3D/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75.tar.gz

#% SCORCHED 3D
%DIR Divertissement/Artillerie en 3D
%URL http://ovh.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-38.exe
%DIR Divertissement/Artillerie en 3D/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-38-src.tar.gz
%FILE Divertissement/Artillerie en 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-38-src.tar.gz

#% TORCS
%DIR Divertissement/Course de voiture en 3D
%URL http://ovh.dl.sourceforge.net/sourceforge/torcs/TORCS-1.2.1-win32-setup.exe
%DIR Divertissement/Course de voiture en 3D/Vidéo
%URL http://ovh.dl.sourceforge.net/sourceforge/torcs/mixed-1.avi
%DIR Divertissement/Course de voiture en 3D/code source
%FILE Divertissement/Course de voiture en 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://sourceforge.net/project/showfiles.php?group_id=3777

#% BATTLE FOR WESNOTH
%DIR Divertissement/Bataille stratégique en 3D
%URL http://ovh.dl.sourceforge.net/sourceforge/wesnoth/wesnoth-windows-0.8.exe
%DIR Divertissement/Bataille stratégique en 3D/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/wesnoth/wesnoth-0.8.tar.gz
%FILE Divertissement/Bataille stratégique en 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://ovh.dl.sourceforge.net/sourceforge/wesnoth/wesnoth-0.8.tar.gz

%#######################FICHIER TEXTES######################
%FILE Dans ce CD.txt
Ce CD ne contient que des LOGICIELS LIBRES.
Ces logiciels sont distribués selon une licence qui vous autorise à en faire ce que vous voulez :

installer, utiliser, copier, étudier, distribuer, modifier, adapter, traduire et même vendre.

La seule restriction est que si vous distribuez des versions modifiées de ces logiciels,
vous avez l'obligation de fournir le code de vos modifications
(veuillez lire leurs licences pour plus de précisions.).
C'est ce qui garantit que le logiciel restera toujours libre,
et que vous pourrez toujours l'utiliser gratuitement.

En apprenant à utiliser ces logiciels vous ne perdez pas de temps
car vous avez l'assurance qu'ils ne vont pas disparaître ni devenir payants.
Ils sont perennes et votre apprentissage l'est aussi !

----

Les logiciels les plus urgents et intéressants à utiliser sont Mozilla (ou Firefox) et OpenOffice.org.

Mozilla (ou Firefox), en tant que navigateur internet, est infiniment plus pratique,
il est beaucoup plus moderne et plus sûr, il supporte et respecte mieux les derniers standards du web,
et il permet d'éviter la moitié des problèmes de sécurité rencontrés sur internet.
Sa part de marché augmente actuellement à une vitesse gigantesque face à Internet Explorer,
qui n'a pas subit d'amélioration depuis plus de trois ans et est maintenant obsolète et même dangereux.
La même remarque peut s'appliquer à Outlook Express, qui peut aussi être remplacé par Mozilla (ou Thunderbird).

L'utilisation d'Internet Explorer n'est obligatoire aujourd'hui que pour quelques rares sites internet
non standards qui n'ont été conçus que pour être visités avec ce navigateur. Lorsque vous tombez
sur un tel site, prenez un peu de temps et écrivez à son webmaster pour vous plaindre. Vous contribuerez
à rendre l'internet plus ouvert, plus standard, plus interopérable et plus accessible.
