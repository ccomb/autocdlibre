#!/bin/bash
# name: autocdlibre
# Ce script permet de télécharger automatiquement les dernières versions
# de certains logiciels libres et de les graver sur un cd
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
autocdlibre_version=2
# où récupérer les infos
autocdlibre_server="http://ccomb.free.fr/autocdlibre"

# on vérifie qu'on a tout ce dont on a besoin
aton() {
which $1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "J'ai besoin du programme \"$1\". Veuillez l'installer"
	exit
fi
}
aton which
aton echo
aton wget
aton cdrecord
aton mkisofs
aton grep
aton head
aton basename
aton pwd
aton find
aton awk
aton cut
aton uniq
aton date
aton unzip
aton dig
aton expr

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
		wget -c -T 4 -q $autocdlibre_server/changelog_v$latest_version
		echo "  La nouvelle version (v$latest_version) de ce script est disponible."
		echo "-------"
		echo "  Modifications depuis la version `expr $latest_version - 1` :"
		cat changelog_v$latest_version 2>/dev/null
		echo "-------"
		printf "Voulez-vous récupérer et utiliser cette nouvelle version ? (o/n) [o] "
		read rep;
		# on télécharge et on exécute la nouvelle version
		if [ "$rep" = "o" -o "$rep" = "O" -o "$rep" = "" ]; then
			echo "  Récupération de la dernière version..."
			wget -c -q $autocdlibre_server/autocdlibre_v$latest_version.sh
			chmod +x autocdlibre_v$latest_version.sh
			echo "Execution de la nouvelle version :"
			./autocdlibre_v$latest_version.sh
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
  awk -v repcd=$repcd -v reseau=$reseau -v reptelech=$reptelech '
BEGIN { ORS="\r\n" }
/^%#/ { next }
/^#%/ { next }
/^$/ { if(infile==0) next }
/^%DIR/  { infile=0; sub("%DIR ",""); system("mkdir -p \"" repcd "/" $0 "\""); dir=repcd "/" $0 }
/^%FILE/ { infile=1; sub("%FILE ",""); file=$0; next }
/^%URL/  { infile=0; if($1=="%URLZIP") { unzip=1; sub("%URLZIP ","")} else {unzip=0; sub("%URL ","")}; system("printf \"Récupération de `basename \"" $0 "\"`...\"; nom=`basename \"" $0 "\"`; ailleurs=\"`find . -name $nom| head -1`\"; if [ ! -z \"$ailleurs\" -a \"" reptelech "/$nom\" != \"$ailleurs\" -a ! -e \"" reptelech "/$nom\" ]; then printf \"trouvé en local, \"; ln \"$ailleurs\" " reptelech "; fi; if [ \"" reseau "\" = \"1\" ]; then wget -c -q \"" $0 "\" -P " reptelech "; fi; if [ -e \"" reptelech "/$nom\" ]; then printf \"déjà téléchargé, \"; ln \"" reptelech "/$nom\" \"" dir "\"; echo \"OK\"; else echo \"ECHEC\"; touch ERROR; fi; if [ \"" unzip "\" = \"1\" ]; then echo \"  Décompression de $nom...\"; unzip \"" dir "/$nom\" -d \"" dir "\" >/dev/null 2>&1; rm -f \"" dir "/$nom\"; fi"); }
{ if(infile==1) { print $0 >> repcd "/" file }
}' $script 
  # on écrit le numéro de version dans le cd
  printf "CD-ROM généré le `date '+%A %d %B %Y'` par le script \"autocdlibre\" version $autocdlibre_version ($autocdlibre_server)" > $repcd/info
  if [ -e ERROR ]; then rm -f ERROR; echo; echo "Au moins un fichier n'a pas pu être téléchargé"; exit; fi
  echo "téléchargement terminé."

  # on construit l'image du cd
  printf "Contruction de l'image ISO du cd..."
  date="`date | cut -d' ' -f 2``date | cut -d' ' -f 7`"
  mkisofs -quiet -J -V Logiciels\ Libres\ $date -o $cdname $repcd >/dev/null 2>&1
  if [ $? -eq 0 ]; then echo OK; else echo ECHEC; exit; fi
fi


# on cherche le premier graveur disponible
printf "Recherche du premier graveur..."
for protocole in `cdrecord dev=help 2>&1 |grep Transport\ name | cut -f3 | grep -v RSCSI | uniq`; do
  for graveur in `cdrecord dev=$protocole -scanbus 2>&1 |grep '.,.,.'|grep -v '*'|cut -f2`; do
	cdrecord dev=$protocole:$graveur -prcap -prcap 2>&1 | grep -q 'Does write CD-R media'
	if [ $? -eq 0 ]; then device=$protocole:$graveur; break; fi
  done
  if [ ! -z "$device" ]; then break; fi
done

# pas de graveur, pas la peine d'aller plus loin.
if [ -z "$device" ]; then
  echo ECHEC
  echo "Aucun graveur trouvé. Je ne peux pas continuer."
  exit
else echo "graveur trouvé : $device"
fi

# on grave
printf "Démarrage de la gravure..."
res=1; num=0
while [ $res -ne 0 ]; do
  cdrecord dev=$device driveropts=burnfree -eject $cdname >/dev/null 2>&1
  res=$?; let num++
  if [ $num -eq 3 ]; then printf "\nJe n'arrive pas à graver. Je ne peux pas terminer\n"; exit; fi
  if [ $res -ne 0 ]; then printf "\nVeuillez insérer un CD vierge dans le graveur, et pressez ENTER\n"; read; fi
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
# %FILE : sert à créer un fichier texte
# %# ou #% : sert à mettre un commentaire
# conseil : il est plus pratique de mettre les %DIR et %URL au début, et les %FILE à la fin.
#######COMMANDES####### (ne pas modifier cette ligne)
%DIR Visualiseur photos
%URL http://wxglade.sourceforge.net/extra/Cornice-0.4-setup.exe
%DIR Visualiseur photos/code source
%URL http://wxglade.sourceforge.net/extra/Cornice-0.4.tgz

%DIR Création de fichiers PDF
%URL http://belnet.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-0_8_0_GNUGhostscript.exe
%DIR Création de fichiers PDF/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/pdfcreator/PDFCreator-Source-0_8_0.zip

%DIR Éditeur photo
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gtk+-2.4.3-setup.zip
%URLZIP ftp://ftp.arnes.si/software/gimp-win/gimp-2.0.2-i586-setup-1.zip
%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins.zip
%DIR Éditeur photo/code source
%URL ftp://ftp.gimp.org/pub/gimp/v2.0/gimp-2.0.2.tar.bz2
%URL http://www.freedesktop.org/software/pkgconfig/releases/pkgconfig-0.15.0.tar.gz
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/gtk+-2.4.3.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/pango-1.4.0.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/glib-2.4.2.tar.bz2
%URL ftp://ftp.gimp.org/pub/gtk/v2.4/atk-1.6.0.tar.bz2
%URL ftp://ftp.arnes.si/software/gimp-win/gimp-plugins-src.zip
%DIR Éditeur photo/Débuter avec GIMP
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_v2.zip
%URLZIP http://www.aljacom.com/%7Egimp/debuter_avec_gimp_2_v2.zip

%DIR Lecteur PDF et Postscript
%URL http://puzzle.dl.sourceforge.net/sourceforge/ghostscript/gs706w32.exe
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/ghostgum/gsv46w32.exe
%DIR Lecteur PDF et Postscript/code source
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/gnu/gs707/ghostscript-7.07.tar.bz2
%URL ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/ghostgum/gsv46src.zip

%DIR Transfert FTP
%URL http://puzzle.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_7b_setup.exe
%DIR Transfert FTP/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/filezilla/FileZilla_2_2_7b_src.zip

%DIR Éditeur de diagrammes
%URLZIP http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-0.92.2-1-setup.zip
%DIR Éditeur de diagrammes/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-0.92.2.tar.bz2
%URL http://belnet.dl.sourceforge.net/sourceforge/dia-installer/dia-installer-src-0.92.2-1.zip

%DIR Animation 3D
%URL http://download.blender.org/release/Blender2.33a/blender-2.33a-windows.exe
%URL http://download.blender.org/release/yafray.0.0.6/YafRay-0.0.6-2-win.exe
%DIR Animation 3D/Manuel (anglais)
%URLZIP http://download.blender.org/documentation/BlenderManualIen.23.pdf.zip
%URLZIP http://download.blender.org/documentation/BlenderManualIIen.23.pdf.zip
%DIR Animation 3D/code source
%URL http://download.blender.org/release/yafray.0.0.6/yafray-0.0.6-2-src.tar.gz
%URL http://download.blender.org/source/blender-2.33a.tar.bz2
%DIR Animation 3D/Python (optionnel)
%URL http://python.org/ftp/python/2.3.4/Python-2.3.4.exe
%DIR Animation 3D/Python (optionnel)/code source
%URL http://python.org/ftp/python/2.3.4/Python-2.3.4.tgz

%DIR Bureautique/OpenOffice.org 1.1.2
%URLZIP http://ftp.club-internet.fr/pub/OpenOffice/localized/fr/1.1.2/OOo_1.1.2_Win32Intel_install_fr.zip
%DIR Bureautique/code source
%FILE Bureautique/code source/codesource.txt
Le code source est énorme et peut être récupéré ici : ftp://openoffice.cict.fr/openoffice/stable/1.1.2/
#%URL ftp://openoffice.cict.fr/openoffice/stable/1.1.2/OOo_1.1.2_source.tar.gz
%DIR Bureautique/Manuels et documentation
%URL http://fr.openoffice.org/Documentation/Guides/Manuel_install1.1_v2.pdf
%URL http://fr.openoffice.org/Documentation/Guides/parcours_texte_ooo.pdf
%URL http://fr.openoffice.org/Documentation/Guides/guideDraw.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Andrew5.pdf
%URL http://fr.openoffice.org/Documentation/Guides/Guide_comparatif_1.0.1.pdf
%URLZIP http://fr.openoffice.org/Documentation/Livres/Livre_pdf.zip

%DIR Compression CD audio
%URL http://belnet.dl.sourceforge.net/sourceforge/cdexos/cdex_151.exe
%DIR Compression CD audio/code source
%FILE Compression CD audio/code source/codesource.txt
Voir ici : http://cvs.sourceforge.net/viewcvs.py/cdexos/cdex_xp/

%DIR Compression fichiers (zip)
%URL http://belnet.dl.sourceforge.net/sourceforge/sevenzip/7z313.exe
%DIR Compression fichiers (zip)/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/sevenzip/7z313.tar.bz2

%DIR Téléchargement Peer2peer
%URL http://www.emule-france.org/files/eMule0.42g-Installer.exe
%DIR Téléchargement Peer2peer/code source
%URL http://www.emule-france.org/files/eMule0.42g-Sources.zip

%DIR Dessin vectoriel
%URL http://belnet.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.38-1.win32.exe
%DIR Dessin vectoriel/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/inkscape/inkscape-0.38.1.tar.bz2

%DIR Éditeur audio
%URL http://unc.dl.sourceforge.net/sourceforge/audacity/audacity-win-1.2.1.exe
%DIR Editeur audio/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/audacity/audacity-src-1.2.1.tar.bz2

%DIR Web et Courriel
%DIR Web et Courriel/Suite internet complète
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/mozilla-win32-1.6-fr-FR-installer.exe
%DIR Web et Courriel/Navigateur seul
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/FirefoxSetup-fr-0.8.exe
%DIR Web et Courriel/Logiciel de Courriel seul
%URL http://belnet.dl.sourceforge.net/sourceforge/frenchmozilla/ThunderbirdSetup-0.7.1-fr.exe
%DIR Web et Courriel/code source
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/mozilla/releases/mozilla1.6/src/mozilla-source-1.6.tar.bz2
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/firefox/releases/0.8/firefox-source-0.8.tar.bz2
%URL http://ftp.eu.mozilla.org/pub/mozilla.org/thunderbird/releases/0.7/thunderbird-0.7-source.tar.bz2

%DIR Filtrage pubs internet
%URL http://belnet.dl.sourceforge.net/sourceforge/ijbswa/privoxy_setup_3_0_3-2.exe
%DIR Filtrage pubs internet/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/ijbswa/privoxy-3.0.3-2-stable.src.tar.gz
%FILE Filtrage pubs internet/à lire.txt
Pour utiliser privoxy :
dans Mozilla : Edition -> préférences -> avancé -> proxies -> configuration manuelle :
HTTP proxy = localhost
HTTP Port = 8118

%DIR Lecteur audio
%URL http://belnet.dl.sourceforge.net/sourceforge/zinf/zinf-setup-2.2.1.exe
%DIR Lecteur audio/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/zinf/zinf-2.2.1.tar.gz

%DIR Messagerie instantanée
%URL http://belnet.dl.sourceforge.net/sourceforge/gaim/gaim-0.79.exe
%DIR Messagerie instantanée/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/gaim/gaim-0.79.tar.bz2

%DIR Lecteur Vidéo et DVD
%URL http://download.videolan.org/pub/videolan/vlc/0.7.2/win32/vlc-0.7.2-win32.exe
%DIR Lecteur Vidéo et DVD/code source
%URL http://download.videolan.org/pub/videolan/vlc/0.7.2/vlc-0.7.2.tar.bz2

%DIR Divertissement/Univers en 3D
%URL http://belnet.dl.sourceforge.net/sourceforge/celestia/celestia-win32-1.3.1-1.exe
%DIR Divertissement/Univers en 3D/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/celestia/celestia-1.3.1.tar.gz

%DIR Divertissement/Billard 3D
%URL http://belnet.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75-Setup.exe
%DIR Divertissement/Billard 3D/code source
%URL http://belnet.dl.sourceforge.net/sourceforge/billardgl/BillardGL-1.75.tar.gz


%#######################FICHIER TEXTES######################
%FILE Dans ce CD.txt
Ce CD ne contient que des LOGICIELS LIBRES.
Ces logiciels sont distribués sous une licence qui vous autorise à en faire ce que vous voulez :

installer, utiliser, copier, étudier, distribuer, modifier, adapter, traduire et même vendre.

La seule restriction est que si vous distribuez des versions modifiées de ces logiciels, vous avez l'obligation de fournir le code de vos modifications (veuillez lire leurs licences pour plus de précisions.). C'est ce qui garantit que le logiciel restera toujours libre, et que vous pourrez toujours l'utiliser gratuitement.

En apprenant à utiliser ces logiciels vous ne perdez pas de temps car vous avez l'assurance qu'ils ne vont pas disparaître du jour au lendemain. Ils sont perennes et votre apprentissage l'est aussi !
