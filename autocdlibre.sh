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

# version de ce script
autocdlibre_version=10
# où récupérer les infos
autocdlibre_server="http://ccomb.free.fr/autocdlibre"

# analyse des arguments
while [ $# -gt 0 ]; do
	case $1 in
	"-h"|"--help")
		echo
		echo "AutoCdLibre v$autocdlibre_version : pour créer un CD de logiciels libres pour Windows"
		echo "Lancez simplement ce script sans argument, et il s'occupera de tout."
		echo "Pour plus d'infos consultez http://ccomb.free.fr/wiki/wakka.php?wiki=AutoCdLibre"
		echo
		echo "Syntaxe : $0 [-h][-nosrc][-arbre][-noburn]"
		echo "-h : ce petit texte d'aide"
		echo "-nosrc : ne pas inclure les codes source"
		echo "-arbre : stopper après la creation de l'arborescence du CD"
		echo "-noburn : stopper juste avant la gravure."
		echo
		exit ;;
	"-nosrc") NOSRC=1;;
	"-arbre") ARBRE=1;;
	"-noburn") NOBURN=1;;
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
printf "Test de l'accès à internet..."
dig +time=2 ccomb.free.fr > /dev/null 2>&1
if [ $? -eq 0 ]; then reseau=1; echo OK; else reseau=0; echo ECHEC; fi

# on récupère le numéro de la dernière version (si on a la connexion au net)
echo "vérification de la dernière version..."
rm -f latest_version
if [ $reseau -eq 1 ]; then wget -O latest_version -T 4 -q $autocdlibre_server/latest_version; fi
if [ -e latest_version -a $reseau -eq 1 ]; then
	latest_version=`cat latest_version`
	rm -f latest_version
	# on vérifie qu'on a la dernière version
	if [ $latest_version -gt $autocdlibre_version ]; then
		# on télécharge et on affiche le changelog
		for i in `seq \`expr $autocdlibre_version + 1\` $latest_version`; do
			wget -c -T 4 -q $autocdlibre_server/changelog_v$i
		done
		echo "  La nouvelle version (v$latest_version) de ce script est disponible."
		echo "-------"
		echo "  Modifications depuis la version $autocdlibre_version :"
		for i in `seq \`expr $autocdlibre_version + 1\` $latest_version`; do
			echo "Dans la version $i :"
			cat changelog_v$i 2>/dev/null
		done
		echo "-------"
		printf "Voulez-vous récupérer et utiliser cette nouvelle version ? (o/n) [o] "
		read rep;
		# on télécharge et on exécute la nouvelle version
		if [ "$rep" = "o" -o "$rep" = "O" -o "$rep" = "" ]; then
			echo "  Récupération de la dernière version..."
			wget -c -q $autocdlibre_server/autocdlibre_v$latest_version.sh
			chmod +x autocdlibre_v$latest_version.sh
			echo "Execution de la nouvelle version :"
			./autocdlibre_v$latest_version.sh $@
			exit
		else echo "  OK, on garde la version actuelle."
		fi
	else echo "  Pas de nouvelle version disponible. On garde la version actuelle."
	fi
else echo "  Impossible de récupérer la dernière version de ce script. On garde la version actuelle."
fi

repcd="autocdlibre_v$autocdlibre_version"
cdname=autocdlibre_v$autocdlibre_version.iso
reptelech=fichiers_telecharges_v$autocdlibre_version

# si une image iso est prête
if [ -f $cdname ]; then
  printf "\nUne image ISO du cd $cdname semble déjà prête.\nVoulez-vous l'utiliser pour graver directement ? (o/n) [o] "
  read rep
fi
if [ ! -f $cdname -o "$rep" != "o" -a "$rep" != "O" -a "$rep" != "" ]; then 
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
/^%URL/  { if(insource==1) next; infile=0; if($1=="%URLZIP") { unzip=1; sub("%URLZIP ","")} else {unzip=0; sub("%URL ","")}; system("printf \"Récupération de `basename \"" $0 "\"`...\"; nom=`basename \"" $0 "\"`; ailleurs=\"`find . -name $nom| head -1`\"; if [ ! -z \"$ailleurs\" ]; then printf \"déjà téléchargé, \"; fi; if [ ! -z \"$ailleurs\" -a \"" reptelech "/$nom\" != \"$ailleurs\" -a ! -e \"" reptelech "/$nom\" ]; then ln \"$ailleurs\" " reptelech "; fi; if [ \"" reseau "\" = \"1\" ]; then wget -c -q \"" $0 "\" -P " reptelech "; fi; if [ -e \"" reptelech "/$nom\" ]; then ln \"" reptelech "/$nom\" \"" dir "\"; echo \"OK\"; else echo \"ECHEC\"; touch ERROR; fi; if [ \"" unzip "\" = \"1\" ]; then echo \"  Décompression de $nom...\"; unzip \"" dir "/$nom\" -d \"" dir "\" >/dev/null 2>&1; rm -f \"" dir "/$nom\"; fi"); }
{ if(insource==1) next; if(infile==1) { print $0 >> repcd "/" file }
}' $script 
  # on écrit le numéro de version dans le cd
  printf "CD-ROM généré le `date '+%A %d %B %Y'` par le script \"autocdlibre\" version $autocdlibre_version ($autocdlibre_server)" > $repcd/info
  if [ -e ERROR ]; then rm -f ERROR; echo; echo "Au moins un fichier n'a pas pu être téléchargé"; exit; fi
  echo "téléchargement terminé, arborescence du CD terminée"

  # si demandé, on s'arrête
  if [ "$ARBRE" = "1" ]; then echo "arrêt demandé après création de l'arborescence"; exit; fi

  # on construit l'image du cd
  printf "Contruction de l'image ISO du cd..."
  date="`date '+%B%Y'`"
  mkisofs -quiet -rJ -V Logiciels\ Libres\ $date -o $cdname $repcd >/dev/null 2>&1
  if [ $? -eq 0 ]; then echo OK; else echo ECHEC; exit; fi
fi


# on cherche le premier graveur disponible (k2.6)
printf "Recherche du premier graveur..."
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
  echo ECHEC
  echo "Aucun graveur trouvé. Je ne peux pas continuer."
  exit
else echo "graveur trouvé : $device"
fi

# si demandé, on s'arrête
if [ "$NOBURN" = "1" ]; then echo "arrêt demandé avant la gravure"; exit; fi

# on grave
printf "Démarrage de la gravure..."
res=1; num=0
while [ $res -ne 0 ]; do
  cdrecord dev=$device driveropts=burnfree -eject $cdname >/dev/null 2>&1
  res=$?; let num++
  if [ $num -eq 3 ]; then printf "\nJe n'arrive pas à graver. Je ne peux pas terminer\n"; exit; fi
  if [ $res -ne 0 ]; then printf "\nVeuillez insérer un CD vierge dans le graveur, et pressez ENTER\n(ou Ctrl-C pour interrompre)\n"; read; fi
done
echo OK
echo "Gravure terminée. L'image ISO est conservée sous le nom $cdname."
echo "Les fichiers téléchargés sont conservés dans $reptele."
echo "L'arborescence du CD ne sert plus à rien. Voulez vous l'effacer ?"
echo "rm -rf $repcd ? (o/n) [o] ?"
read rep
if [ "$rep" = "o" -o "$rep" = "O" -o "$rep" = "" ]; then
  echo "Effacement de l'arborescence du CD..."
  rm -rf $repcd
fi

echo "Si vous pensez que ce CD n'est pas à jour avec les dernières versions, ou pour toute autre remarque ou question,"
echo "veuillez envoyer un mail à ccomb@free.fr, ou rendez-vous à http://ccomb.free.fr/wiki/wakka.php?wiki=AutoCdLibre"



exit
################################"
# liste des logiciels qu'on veut
# syntaxe :
# une commande DIR suivi d'un nombre arbitraire de commandes URL et FILE
# %DIR : sert à créer un répertoire
# %URL : sert à télécharger quelque chose dans le dernier répertoire créé
# %URLZIP : idem sauf qu'on décompresse avant de graver
# %FILE : sert à créer un fichier texte (attention à créer le répertoire avant le fichier)
# %# ou #% : sert à mettre un commentaire
# conseil : il est plus pratique de mettre les %DIR et %URL au début, et les %FILE à la fin.
# ATTENTION : pour que -nosrc fonctionne, les répertoires contenant
# les codes sources doivent s'appeler "code source"
################################"

#% CLAMAV
%DIR Internet/Antivirus
%URL http://belnet.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.35-setup.exe
%DIR Internet/Antivirus/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.35-src.zip
%FILE Internet/Antivirus/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/clamwin/clamwin-0.35-src.zip

#% HTTRACK
%DIR Internet/Aspirateur de site web
%URL http://download.httrack.com/httrack-3.32-2.exe
%DIR Internet/Aspirateur de site web/code source
%URL http://www.httrack.com/httrack-3.32-2.tar.gz
%FILE Internet/Aspirateur de site web/code source/codesource.txt
le code source peut être obtenu ici : http://www.httrack.com/httrack-3.32-2.tar.gz

#% NVU
%DIR Internet/Éditeur de site web
%URL http://cvs.nvu.com/download/nvu-0.30-win32-installer-full.exe
%DIR Internet/Éditeur de site web/code source
%URL http://www.nvu.com/download/nvu-0.30-source.tar.gz
%FILE Internet/Éditeur de site web/code source/codesource.txt
le code source peut être obtenu ici : http://www.nvu.com/download/nvu-0.30-source.tar.gz

#% ABIWORD
%DIR Bureautique/Traitement de texte seul
%URL http://belnet.dl.sourceforge.net/sourceforge/abiword/abiword-setup-2.0.7.exe
%URL http://belnet.dl.sourceforge.net/sourceforge/abiword/abiword-plugins-impexp-2.0.7.exe
%URL http://belnet.dl.sourceforge.net/sourceforge/abiword/abiword-plugins-tools-2.0.7.exe
%DIR Bureautique/Traitement de texte seul/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/abiword/abiword-2.0.7.tar.gz
%FILE Bureautique/Traitement de texte seul/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/abiword/abiword-2.0.7.tar.gz

#% OPENVIP
%DIR Multimedia/Montage vidéo
%URL http://belnet.dl.sourceforge.net/sourceforge/openvip/openvip-1.0.1-setup.exe
%DIR Multimedia/Montage vidéo/code source
%FILE Multimedia/Montage vidéo/code source/codesource.txt
Le code source de OpenVIP peut être consulté ici : http://cvs.sourceforge.net/viewcvs.py/openvip/

#% VIRTUALDUB
%DIR Multimedia/Capture et traitement de vidéo
%URLZIP http://puzzle.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10.zip
%DIR Multimedia/Capture et traitement de vidéo/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10-src.zip.bz2
%FILE Multimedia/Capture et traitement de vidéo/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/virtualdub/VirtualDub-1.5.10-src.zip.bz2

#% CORNICE
%DIR Multimedia/Visualiseur photos
%URL http://wxglade.sourceforge.net/extra/Cornice-0.4-setup.exe
%DIR Multimedia/Visualiseur photos/code source
%URL http://wxglade.sourceforge.net/extra/Cornice-0.4.tgz
%FILE Multimedia/Visualiseur photos/code source/codesource.txt
le code source peut être obtenu ici : http://wxglade.sourceforge.net/extra/Cornice-0.4.tgz

#% PDFCREATOR
%DIR Bureautique/Création de fichiers PDF
%URL http://belnet.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-0_8_0_GNUGhostscript.exe
%DIR Bureautique/Création de fichiers PDF/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-Source-0_8_0.zip
%FILE Bureautique/Création de fichiers PDF/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-Source-0_8_0.zip

#% THE GIMP
%DIR Multimedia/Éditeur photo
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gtk+-2.4.3-setup.zip
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gimp-2.0.3-i586-setup.zip
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gimp-help-2-0.3-setup.zip
%FILE Multimedia/Éditeur photo/comment installer GIMP.txt
Dans l'ordre, il faut installer :
- gtk+
- gimp
- gimp-help
- optionnellement les plugins
Consultez ensuite les tutoriels dans le dossier : Débuter avec GIMP

%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins.zip
%DIR Multimedia/Éditeur photo/Débuter avec GIMP
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_v2.zip
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_2_v2.zip
%DIR Multimedia/Éditeur photo/code source
%URL ftp://ftp.gimp.org/pub/gimp/v2.0/gimp-2.0.2.tar.bz2
%URL http://www.freedesktop.org/software/pkgconfig/releases/pkgconfig-0.15.0.tar.gz
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/gtk+-2.4.3.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/pango-1.4.0.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/glib-2.4.2.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/atk-1.6.0.tar.bz2
%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins-src.zip
%FILE Multimedia/Éditeur photo/code source/codesource.txt
le code source peut être obtenu ici :
ftp://ftp.gimp.org/pub/gimp/v2.0/gimp-2.0.2.tar.bz2
http://www.freedesktop.org/software/pkgconfig/releases/pkgconfig-0.15.0.tar.gz
ftp://ftp.gimp.org/pub/gtk/v2.4/gtk+-2.4.3.tar.bz2
ftp://ftp.gimp.org/pub/gtk/v2.4/pango-1.4.0.tar.bz2
ftp://ftp.gimp.org/pub/gtk/v2.4/glib-2.4.2.tar.bz2
ftp://ftp.gimp.org/pub/gtk/v2.4/atk-1.6.0.tar.bz2
ftp://ftp.arnes.si/software/gimp-win/gimp-plugins-src.zip

#% GHOSTSCRIPT ET GSVIEW
%DIR Bureautique/Visualiseur de fichiers PDF et Postscript
%URL http://puzzle.dl.sourceforge.net/sourceforge/ghostscript/gs706w32.exe
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/ghostgum/gsv46w32.exe
%DIR Bureautique/Visualiseur de fichiers PDF et Postscript/code source
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/gnu/gs707/ghostscript-7.07.tar.bz2
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/ghostgum/gsv46src.zip
%FILE Bureautique/Visualiseur de fichiers PDF et Postscript/code source/codesource.txt
le code source peut être obtenu ici :
ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/gnu/gs707/ghostscript-7.07.tar.bz2
ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/ghostgum/gsv46src.zip

#% FILEZILLA
%DIR Internet/Transfert FTP
%URL http://puzzle.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_7b_setup.exe
%DIR Internet/Transfert FTP/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_7b_src.zip
%FILE Internet/Transfert FTP/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_7b_src.zip

#% DIA
%DIR Bureautique/Éditeur de diagrammes
%URLZIP http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-0.92.2-1-setup.zip
%DIR Bureautique/Éditeur de diagrammes/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-0.92.2.tar.bz2
%URL http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-installer-src-0.92.2-1.zip
%FILE Bureautique/Éditeur de diagrammes/code source/codesource.txt
le code source peut être obtenu ici :
http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-0.92.2.tar.bz2
http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-installer-src-0.92.2-1.zip

#% BLENDER
%DIR Multimedia/Animation et rendu 3D
%URL http://download.blender.org/release/Blender2.33a/blender-2.33a-windows.exe
%URL http://download.blender.org/release/yafray.0.0.6/YafRay-0.0.6-2-win.exe
%DIR Multimedia/Animation et rendu 3D/Manuel (anglais)
%URLZIP http://download.blender.org/documentation/BlenderManualIen.23.pdf.zip
%URLZIP http://download.blender.org/documentation/BlenderManualIIen.23.pdf.zip
%DIR Multimedia/Animation et rendu 3D/code source
%URL http://download.blender.org/release/yafray.0.0.6/yafray-0.0.6-2-src.tar.gz
%URL http://download.blender.org/source/blender-2.33a.tar.bz2
%FILE Multimedia/Animation et rendu 3D/code source/codesource.txt
le code source peut être obtenu ici :
http://download.blender.org/release/yafray.0.0.6/yafray-0.0.6-2-src.tar.gz
http://download.blender.org/source/blender-2.33a.tar.bz2
%DIR Multimedia/Animation et rendu 3D/Python (optionnel)
%URL http://python.org/ftp/python/2.3.4/Python-2.3.4.exe
%DIR Multimedia/Animation et rendu 3D/Python (optionnel)/code source
%URL http://python.org/ftp/python/2.3.4/Python-2.3.4.tgz
%FILE Multimedia/Animation et rendu 3D/Python (optionnel)/code source/codesource.txt
le code source peut être obtenu ici : http://python.org/ftp/python/2.3.4/Python-2.3.4.tgz

#% OPENOFFICE.ORG
%DIR Bureautique/Suite Bureautique Complète/OpenOffice.org 1.1.2
%URLZIP http://ftp.club-internet.fr/pub/OpenOffice/localized/fr/1.1.2/OOo_1.1.2_Win32Intel_install_fr.zip
%DIR Bureautique/Suite Bureautique Complète/code source
%FILE Bureautique/Suite Bureautique Complète/code source/codesource.txt
Le code source est énorme et peut être récupéré ici : ftp://openoffice.cict.fr/openoffice/stable/1.1.2/
#%URL ftp://openoffice.cict.fr/openoffice/stable/1.1.2/OOo_1.1.2_source.tar.gz
%DIR Bureautique/Suite Bureautique Complète/Manuels et documentation
%URL http://fr.openoffice.org/Documentation/Guides/Manuel_install1.1_v2.pdf
%URL http://fr.openoffice.org/Documentation/Guides/parcours_texte_ooo.pdf
%URL http://fr.openoffice.org/Documentation/Guides/guideDraw.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Andrew5.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Guide_comparatif_1.0.1.pdf
%URLZIP http://fr.openoffice.org/Documentation/Livres/Livre_pdf.zip

#% CDEX
%DIR Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis
%URL http://belnet.dl.sourceforge.net/sourceforge/cdexos/cdex_151.exe
%DIR Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis/code source
%FILE Multimedia/Compression CD audio vers MP3 ou Ogg-Vorbis/code source/codesource.txt
Voir ici : http://cvs.sourceforge.net/viewcvs.py/cdexos/cdex_xp/

#% 7-ZIP
%DIR Compression de fichiers (zip, gz, bz2, etc.)
%URL http://belnet.dl.sourceforge.net/sourceforge/sevenzip/7z313.exe
%DIR Compression de fichiers (zip, gz, bz2, etc.)/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/sevenzip/7z313.tar.bz2
%FILE Compression de fichiers (zip, gz, bz2, etc.)/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/sevenzip/7z313.tar.bz2

#% EMULE
%DIR Internet/Téléchargement Peer2peer
%URL http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.43b-Installer.exe
%DIR Internet/Téléchargement Peer2peer/code source
%URL http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.43b-Sources.zip
%FILE Internet/Téléchargement Peer2peer/code source/codesource.txt
le code source peut être obtenu ici : http://ovh.dl.sourceforge.net/sourceforge/emule/eMule0.43b-Sources.zip
%FILE Internet/Téléchargement Peer2peer/conseil.txt
Évidemment, tout le monde sait que le téléchargement de certains logiciels propriétaires et payants est illégal...
Mais il faut penser à quelque chose de beaucoup plus important et plus néfaste : 

En téléchargeant et en copiant des logiciels propriétaires payants,
vous augmentez la notoriété et la diffusion de ces logiciels,
et vous leur faites de la publicité inutilement.
Vous perdez du temps à apprendre des logiciels que vous n'avez pas le droit d'utiliser,
vous devenez dépendant d'un produit que vous risquez d'être obligé de payer un jour,
et dont la pérennité, le prix, la disponibilité, ou la compatibilité sont inconnus dans le futur.

Au lieu de télécharger illégalement Photoshop, apprenez à utiliser GIMP.
Il est aussi performant, gratuit, légal,
et vous êtes sûr qu'il ne va jamais disparaître, ni devenir payant : c'est un Logiciel Libre.

Au lieu de télécharger illégalement Microsoft Office, apprenez OpenOffice.org,
il est gratuit, compatible, ouvert, facile à utiliser, plus stable, et il évolue plus vite.

#% INKSCAPE
%DIR Multimedia/Dessin vectoriel
%URL http://belnet.dl.sourceforge.net/sourceforge/inkscape/Inkscape-0.39-1.win32.exe
%DIR Multimedia/Dessin vectoriel/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.39.tar.bz2
%FILE Multimedia/Dessin vectoriel/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.39.tar.bz2

#% AUDACITY
%DIR Multimedia/Enregistreur et éditeur de sons
%URL http://unc.dl.sourceforge.net/sourceforge/audacity/audacity-win-1.2.1.exe
%DIR Multimedia/Enregistreur et éditeur de sons/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/audacity/audacity-src-1.2.1.tar.bz2
%FILE Multimedia/Enregistreur et éditeur de sons/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/audacity/audacity-src-1.2.1.tar.bz2

#% MOZILLA
%DIR Internet/Suite internet complète (navigateur, e-mail, éditeur web)
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/mozilla-win32-1.7.1-installer-fr-FR.exe
#%URL http://frenchmozilla.sourceforge.net/FTP/1.7.1/mozilla-l10n-fr-FR-1.7.1.xpi
%DIR Internet/Suite internet complète (navigateur, e-mail, éditeur web)/code source
%URL http://ftp.mozilla.org/pub/mozilla.org/mozilla/releases/mozilla1.7.1/src/mozilla-source-1.7.1.tar.bz2
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
le code source peut être obtenu ici : http://ftp.mozilla.org/pub/mozilla.org/mozilla/releases/mozilla1.7.1/src/mozilla-source-1.7.1.tar.bz2

#% FIREFOX
%DIR Internet/Navigateur Internet
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/FirefoxSetup-0.9.2-fr.exe
%DIR Internet/Navigateur Internet/code source
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/0.9.2/firefox-0.9.2-source.tar.bz2
%FILE Internet/Navigateur Internet/code source/codesource.txt
le code source peut être obtenu ici : http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/0.9.2/firefox-0.9.2-source.tar.bz2

#% THUNDERBIRD
%DIR Internet/Logiciel de courrier électronique
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/ThunderbirdSetup-0.7.2-fr.exe
%DIR Internet/Logiciel de courrier électronique/code source
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/thunderbird/releases/0.7.2/thunderbird-0.7.2-source.tar.bz2
%FILE Internet/Logiciel de courrier électronique/code source/codesource.txt
le code source peut être obtenu ici : http://ftp.eu.mozilla.org/pub/mozilla.org/thunderbird/releases/0.7.2/thunderbird-0.7.2-source.tar.bz2

#% PRIVOXY
%DIR Internet/Filtrage pubs internet
%URL http://belnet.dl.sourceforge.net/sourceforge/ijbswa/privoxy_setup_3_0_3-2.exe
%DIR Internet/Filtrage pubs internet/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/ijbswa/privoxy-3.0.3-2-stable.src.tar.gz
%FILE Internet/Filtrage pubs internet/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/ijbswa/privoxy-3.0.3-2-stable.src.tar.gz
%FILE Internet/Filtrage pubs internet/comment utiliser Privoxy.txt
Pour utiliser privoxy :
dans Mozilla : menu Edition -> préférences -> avancé -> proxies -> configuration manuelle :
HTTP proxy = localhost
HTTP Port = 8118

#% ZINF
%DIR Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)
%URL http://belnet.dl.sourceforge.net/sourceforge/zinf/zinf-setup-2.2.1.exe
%DIR Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/zinf/zinf-2.2.1.tar.gz
%FILE Multimedia/Lecteur audio (mp3, Ogg-Vorbis, etc.)/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/zinf/zinf-2.2.1.tar.gz

#% GAIM
%DIR Internet/Messagerie instantanée (icq, jabber, msn, etc.)
%URL http://belnet.dl.sourceforge.net/sourceforge/gaim/gaim-0.80.exe
%DIR Internet/Messagerie instantanée (icq, jabber, msn, etc.)/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/gaim/gaim-0.80.tar.bz2
%FILE Internet/Messagerie instantanée (icq, jabber, msn, etc.)/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/gaim/gaim-0.80.tar.bz2

#% VLC MEDIA PLAYER
%DIR Multimedia/Lecteur Vidéo et DVD
%URL http://download.videolan.org/pub/videolan/vlc/0.7.2/win32/vlc-0.7.2-win32.exe
%DIR Multimedia/Lecteur Vidéo et DVD/code source
%URL http://download.videolan.org/pub/videolan/vlc/0.7.2/vlc-0.7.2.tar.bz2
%FILE Multimedia/Lecteur Vidéo et DVD/code source/codesource.txt
le code source peut être obtenu ici : http://download.videolan.org/pub/videolan/vlc/0.7.2/vlc-0.7.2.tar.bz2

#% CELESTIA
%DIR Divertissement/Visite univers en 3D
%URL http://belnet.dl.sourceforge.net/sourceforge/celestia/celestia-win32-1.3.1-1.exe
%DIR Divertissement/Visite univers en 3D/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/celestia/celestia-1.3.1.tar.gz
%FILE Divertissement/Visite univers en 3D/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/celestia/celestia-1.3.1.tar.gz

#% BILLARD 3D
%DIR Divertissement/Billard en 3D
%URL http://belnet.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75-Setup.exe
%DIR Divertissement/Billard en 3D/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75.tar.gz
%FILE Divertissement/Billard en 3D/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75.tar.gz

#% SCORCHED 3D
%DIR Divertissement/Artillerie en 3D
%URL http://belnet.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-37.2.exe
%DIR Divertissement/Artillerie en 3D/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-37.2-src.zip
%FILE Divertissement/Artillerie en 3D/code source/codesource.txt
le code source peut être obtenu ici : http://belnet.dl.sourceforge.net/sourceforge/scorched3d/Scorched3D-37.2-src.zip

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

Les logiciels les plus urgents et intéressants à utiliser sont Mozilla et OpenOffice.org.

Mozilla, en tant que navigateur internet, est infiniment plus pratique,
il est beaucoup plus moderne et plus sûr, il supporte et respecte mieux les derniers standards du web,
et il permet d'éviter la moitié des problèmes de sécurité rencontrés sur internet.
Sa part de marché augmente actuellement à une vitesse gigantesque face à Internet Explorer,
qui n'a pas subit d'amélioration depuis plus de trois ans et est maintenant obsolète et même dangereux.
La même remarque peut s'appliquer à Outlook Express, qui peut aussi être remplacé par Mozilla.

L'utilisation d'Internet Explorer n'est obligatoire aujourd'hui que pour quelques rares sites internet
non standards qui n'ont été conçus que pour être visités avec ce navigateur. Lorsque vous tombez
sur un tel site, prenez un peu de temps et écrivez à son webmaster pour vous plaindre. Vous contribuerez
à rendre l'internet plus ouvert, plus standard, plus interopérable et plus accessible.
