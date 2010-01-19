#!/bin/sh

clear

instdir=`kpsexpand '$TEXMFLOCAL'`

if [ "`whoami`" != "root" ]
  then
  cat <<EOF
Sie sind nicht root.
Vermutlich haben Sie keine Schreibrechte im Verzeichnis "$instdir".
Schreiben Sie "local" um trotzdem zu versuchen, dorthin zu installieren,
"home" um zu versuchen, in Ihr TeX-Benutzerverzeichnis zu installieren,
irgend etwas anderes umd die Installation abzubrechen.
EOF
  read reply

  if ( [ ! -z "$reply" ] && [ "$reply" == "home" ] )
    then
    instdir="`kpsexpand '$TEXMFHOME'`"
  else if ( [ -z "$reply" ] || [ "$reply" != "local" ] )
    then
    cat <<EOF
Installation abgebrochen.
EOF
    exit 0
  fi
  fi

fi
mkdir -p "$instdir"
if ( [ -z "$instdir" ] || [ ! -d "$instdir" ] || [ ! -w "$instdir" ] )
  then
  cat <<EOF
Installation nicht moeglich: Installationsverzeichnis "$instdir" nicht
vorhanden oder nicht beschreibbar
EOF
  exit 1
fi

if ( [ ! -r Univers_ps.zip ] || [ ! -r DIN_Bd_PS.zip ] )
  then
  cat <<EOF
Bitte rufen Sie dieses Script von dem Verzeichnis aus auf, in dem sich die 
Dateien Univers_ps.zip und DIN_Bd_PS.zip befinden. Stellen Sie auch sicher, 
dass Sie Leserechte fuer diese Dateien haben!
EOF
  exit 1
fi

workdir=`pwd`
tempdir=$workdir/`mktemp -d tmp`
mkdir $tempdir/source
echo $tempdir
cd $tempdir/source
logfile="`mktemp -t X`"
echo ""
echo "Entpacke ZIP-Dateien"
unzip $workdir/Univers_ps.zip >> $logfile
unzip $workdir/DIN_Bd_PS.zip >> $logfile
chmod -R u+w $tempdir/source 2>&1 > /dev/null
for afm in *.afm
  do
  mv $afm ttt
  sed -e "s/Italic/Oblique/g" ttt > $afm
done
rm ttt

echo ""
echo "Bereite Installation der Schriften vor:"
# Tabelle mit Namen und Eigenschaften der Schriften
cat > $tempdir/namedatabase << EOF
#dinb/DINBd___/DIN-Bold/b/n
#aunb/uvceb___/UniversCE-Bold/b/n
#aunl/uvcel___/UniversCE-Light/l/n
#aunro/uvceo___/UniversCE-Oblique/r/sl
#aunbo/uvxbo___/UniversCE-BoldOblique/b/sl
#aunlo/uvxlo___/UniversCE-LightOblique/l/sl
#aunr/uvce____/UniversCE/r/n
#aubro/uvczo___/Univers-BlackOblique/c/sl
#aubr/uvcz____/Univers-Black/c/n
EOF

cd $tempdir

# fontinst-scripte vorbereiten
for family in aub aun din
  do
  cat > fi$family.tex <<EOF
\\input fontinst.sty
\\installfonts
\\installfamily{8r}{$family}{}
\\installfamily{OT1}{$family}{}
\\installfamily{T1}{$family}{}
EOF
done

# einzelne Schriften umbenennen, in fontinst-script und in map eintragen
for font in dinb aunb aunl aunro aunbo aunlo aunr aubro aubr
  do
  srcname=`grep ^#$font\/ $tempdir/namedatabase | cut -d/ -f2`
  family=`echo $font |head -c 3`
  mv source/$srcname.afm $font\8a.afm
  mv source/$srcname.pfb $font\8a.pfb
  longname=`grep ^#$font\/ "$tempdir/namedatabase" | cut -d/ -f3`
  echo $longname
  weight=`grep ^#$font\/ "$tempdir/namedatabase" | cut -d/ -f4`
  style=`grep ^#$font\/ "$tempdir/namedatabase" | cut -d/ -f5`
  cat >> fi$family.tex <<EOF
\\transformfont{$font$!8r}{\\reencodefont{8r}{\\fromafm{$font$!8a}}}
\\installrawfont{$font$!8r}{$font$!8r,8r}{8r}{8r}{$family}{$weight}{$style}{}
\\installfont{$font$!7t}{$font$!8r,latin}{OT1}{OT1}{$family}{$weight}{$style}{}
\\installfont{$font$!8t}{$font$!8r,latin}{T1}{T1}{$family}{$weight}{$style}{}
EOF
  
  cat >> $family.map <<EOF
$font$!8r $longname "TeXBase1Encoding ReEncodeFont" <8r.enc <$font$!8a.pfb
EOF
  
done

# fontinst-dateien abschliessen und ausfuehren
echo ""
echo -n "Erzeuge Schriftinfos"
for family in aub aun din
  do
  cat >> fi$family.tex <<EOF
\\endinstallfonts
\\bye
EOF
  echo -n "..."
  latex fi$family.tex 2>&1 >> "$logfile"
done
echo ""

# TeX font metrics und virtual fonts erzeugen
echo ""
echo "Wandle Schriftinfos um"
for f in *.pl
  do
  pltotf $f 2>&1 >> "$logfile"
done
for f in *.vpl
  do
  vptovf $f 2>&1 >> "$logfile"
done

# Sicherstellen dass alle Verzeichnisse existieren
mkdir -p "$instdir/tex/latex/tudfonts" "$instdir/fonts/tfm/tudfonts" "$instdir/fonts/vf/tudfonts" "$instdir/fonts/type1/tudfonts" "$instdir/fonts/afm/tudfonts" "$instdir/fonts/map/dvips/tudfonts"

echo ""
echo "Kopiere Schriften"
(
cp *.fd $instdir/tex/latex/tudfonts/
cp *.tfm $instdir/fonts/tfm/tudfonts/
cp *.vf $instdir/fonts/vf/tudfonts/
cp *.pfb $instdir/fonts/type1/tudfonts/
cp *.afm $instdir/fonts/afm/tudfonts/
cp *.map $instdir/fonts/map/dvips/tudfonts/
) 2>&1 >> "$logfile"

echo ""
echo "Aktualisiere TeX-Dateilisten"
mktexlsr 2>&1 >> "$logfile"

echo ""
echo "Veroeffentliche Schriftinfos fuer dvips & Co"
cd $workdir
updmap --disable aub.map
updmap --disable aun.map
updmap --disable din.map
updmap --enable Map aub.map
updmap --enable Map aun.map
updmap --enable Map din.map
updmap --syncwithtrees
success="true"
tempfile="`mktemp -t sX`"
updmap --listmaps 2>&1 > "$tempfile"
if ( [ `grep -c "^Map aun\.map$" "$tempfile"` != 1 ] || [ `grep -c "^Map aub\.map$" "$tempfile"` != 1 ] || [ `grep -c "^Map din\.map$" "$tempfile"` != 1 ] )
  then
  cat <<EOF
Die Map-Dateien konnten leider nicht automatisch aktiviert werden.
Bitte rufen Sie 'updmap --edit' auf und stellen Sie sicher, dass jede
der folgenden 3 Zeilen *genau ein mal* vorhanden ist:

Map aun.map
Map aub.map
Map din.map

Falls Sie eine Debian-basierte Distribution verwenden, aktivieren Sie 
diese drei Maps auf die in der manpage zu update-updmap beschriebenen
Weise.

Anschliessend sollten Sie 'updmap' laufen lassen, gefolgt von 'mktexlsr'
oder 'texhash'. Danach stehen Ihnen die Schriften zur Verfuegung.
EOF
  echo -e "\007"
else
  echo ""
  echo "Aktualisiere TeX-Dateilisten"
  mktexlsr
fi
 
# aufraeumen
rm $tempfile
rm -r $tempdir 2>&1 >> "$logfile"
echo "Ein Protokoll finden Sie in \"$logfile\"."