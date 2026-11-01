# No Man’s Sky Trainer für macOS

Separates Projekt aus `mactrainertemplate`, GPL-3.0-only. Die ursprüngliche Vorlage wird nicht verändert.

[![Build and Release](https://github.com/darkuser89/No-Man-s-Sky-Mac-trainer/actions/workflows/build-release.yml/badge.svg)](https://github.com/darkuser89/No-Man-s-Sky-Mac-trainer/actions/workflows/build-release.yml)

[App herunterladen](https://github.com/darkuser89/No-Man-s-Sky-Mac-trainer/releases/latest) · [Alle Builds und Vorab-Releases](https://github.com/darkuser89/No-Man-s-Sky-Mac-trainer/releases)

Apple Silicon, macOS 14 oder neuer. Die ZIP enthält die App einschließlich Icon, Overlay und GPL-Lizenz; `SHA256SUMS` enthält die Download-Prüfsumme. Die App ist ad-hoc signiert und nicht Apple-notarisiert.

Der native Adapter ist auf die Steam-arm64-UUID `2E807BC6-A953-3F93-B723-42A2FB9E39CB` begrenzt. Eine Universal-App wird anhand ihrer arm64-Slice geprüft. Ein anderes Spielupdate wird abgelehnt. Die im Bundle angegebene Versionsnummer lautet 4.70; sie ist keine Kompatibilitätszusage für alle 4.70-Installationen.

## Verwenden

1. Steam geöffnet lassen und den Trainer öffnen. Die Spiele-App wird über ihre Bundle-ID gesucht; bei Bedarf über „Spiele-App wählen“ auswählen.
2. Das Spiel mit „Spiel mit Trainer starten“ öffnen und einen Spielstand laden. Einzelspieler und Netzwerk sind nutzbare Kontexte; der Netzwerkstatus sperrt keine Cheats und löscht keine Auswahl. Der Trainer ändert keine Netzwerkeinstellung selbst.
3. Das Overlay startet verborgen. Mit ⌘ + ^ öffnen; die Maus wird dabei automatisch für das Overlay freigegeben. Esc beziehungsweise erneutes ⌘ + ^ schließt es. Einen separaten Maus-Hotkey oder sichtbaren Modus ohne Maus gibt es nicht.
4. ⇧F9 schaltet alle kontinuierlichen Funktionen aus. Bereits gewährte Währungen werden dadurch nicht entfernt. Währungsaktionen können vom Spiel gespeichert werden.

## Funktionen und Tasten

Der Katalog umfasst die 27 Funktionen des Referenzbildes sowie die drei schon vorhandenen Extras Sprintfaktor, Naniten +100 und Quecksilber hinzufügen. Die native Anbindung und der tatsächliche Wirkungsnachweis sind getrennt zu bewerten.

Im Spiel bestätigt wurden kleine Währungsgaben, die drei Währungsbestände, Stapelauffüllen, Werkzeugenergie, Werkzeughitze, materialfreies Herstellen einschließlich Rücknahme und Gefahrenschutz. Für Jetpack und Scanner liegen nur Teilprüfungen vor. Atlas-Kosten wurden nativ geändert, zurückgelesen und zurückgenommen; das Öffnen von Türen wurde nicht bestätigt. Für fehlende bzw. beschädigte Ausrüstung, Kampf, Alien-Dialoge und genaue Geschwindigkeitsvergleiche fehlen vollständige Wirkungsnachweise. Es gibt keine 27/27-Wirkungszusage.

| Taste | Funktion | Native Anbindung |
| --- | --- | --- |
| F1 | Kein Gesundheitsschaden | TakeNoDamage |
| F2 | Unbegrenzte Ausdauer | InfiniteStamina |
| F3 | Lebenserhaltung ohne Verbrauch | UseEnergy |
| F4 | Sprintfaktor, Extra | SprintMultiplier, 0,25–4 |
| F5 | Units hinzufügen | AwardUnits, einmalig |
| F6 | Naniten +100, Extra | AwardNanites, einmalig |
| F7 | Gefahrenschutz ohne Verbrauch | UseHazardProtection |
| F8 | Alien-Sprache lesbar | DoAlienLanguage |
| F9 | Quecksilber hinzufügen, Extra | AwardSpecials, einmalig |
| ⌥F1 | Unbegrenzter Schild | GetMaximumShield, eigener Schild |
| ⌥F2 | Jetpack ohne Verbrauch | GetJetpackTankSize, eigener Tank |
| ⌥F3 | Multi-Tool ohne Überhitzen | aktueller Laser-Wärmewert |
| ⌥F4 | Kein Nachladen | GetClipSize / GetAmmo / SetAmmo |
| ⌥F5 | Unbegrenzte Granaten | native Technologie-Inventar-Edits |
| ⌥F6 | Unbegrenzte Gegenstände | native Stapelgrenzen / SetInventoryElement |
| ⌥F7 | Herstellen ohne Material | DifficultySettings::IsCraftingFree |
| ⌥F8 | Extremer Schaden | SuperKillGuns |
| ⌥F9 | Raumschiff-Gesundheit | GetMaximumShipHealth |
| ⌥F10 | Raumschiff-Schild | native Schild-Technologie aufladen |
| ⌥F11 | Raumschiff ohne Überhitzen | LaserOverheatTime / ProjectileOverheatTime |
| ⌥F12 | Unbegrenzte Units | AwardUnits bis Mindestbestand 999.999.999 |
| ⇧F1 | Spielgeschwindigkeit | lokale cTkClock, 0,25–4 |
| ⇧F2 | Schlösser ohne Atlas-Pass | ACCESS1/2/3-Produktanforderungen im nativen Kostentisch |
| ⇧F3 | Unbegrenzte Naniten | AwardNanites bis Mindestbestand 999.999.999 |
| ⇧F4 | Unbegrenztes Quecksilber | AwardSpecials bis Mindestbestand 999.999.999 |
| ⇧F5 | Startschubdüsen-Energie | native Technologie aufladen |
| ⇧F6 | Impulsantriebs-Energie | native Technologie aufladen |
| ⇧F7 | Hyperantriebs-Energie | native Technologie aufladen |
| ⇧F8 | Scanner sofort bereit | nativer Scanner-Ladefortschritt |
| ⇧F10 | Multi-Tool-Energie | native aktive Technologie aufladen |

⇧F9 bleibt ausschließlich „alles aus“. Zahlenwerte lassen sich im Overlay ändern. Das Overlay startet mit jeder Sitzung verborgen und öffnet mit ⌘ + ^ samt Maus. Die entfernten Launcher-Schalter für Demo, Nur-Lesen und Overlay-Öffnen bleiben entfernt; es gibt keine Netzwerksperre.

Aufladen setzt vorhandene intakte Technik voraus. Granaten und Projektilmunition werden nur bei passender Ausrüstung angewendet; der Trainer erzeugt oder repariert diese Ausrüstung nicht. Herstellung benötigt weiterhin bekannte Rezepte. Bei Atlas werden keine Pässe ins Inventar geschrieben. Kosten werden vor jedem Zugriff erneut über ihre native ID aufgelöst und beim Ausschalten nur bei passendem Besitzer und unveränderten eigenen Werten zurückgenommen.

Auffüllen von Gegenständen, Energie, Schilden und Währungen kann im Spiel gespeichert werden. Ausschalten beendet das weitere Auffüllen; bereits gewährte Mengen werden nicht abgezogen. Globale Schalter, Zeitskala, Herstellung und eigene Atlas-Kostenänderungen werden zurückgenommen. Grün bedeutet erfolgreiche native Rückleseprüfung; das ist kein vollständiger Ingame-Wirkungsnachweis.

Die CLI-Demo verändert ausschließlich ein simuliertes Modell und belegt keine Spielwirkung.

## Bauen

Xcode mit macOS-26+-SDK, Apple Silicon; Zielsystem macOS 14 oder neuer.

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh run
```

Der stabile Buildordner liegt standardmäßig unter `~/Documents/Codex/Builds/NoMansSkyTrainer`, außerhalb des Codes. Das Skript führt native Regressionstests, die vorhandenen Overlay-Tests und den Projekterzeugungstest aus. Es ersetzt nur die eigene aktuelle App. `run` öffnet den Launcher, nicht automatisch das Spiel. Ad-hoc-Signierung ist keine Notarisierung.

## Automatische Builds und Releases

GitHub Actions baut mit Xcode auf `macos-26` (arm64), führt die enthaltenen Tests aus und prüft die Signaturen. Das Spiel selbst ist auf GitHub nicht vorhanden; CI ist kein zusätzlicher Ingame-Test.

- Jeder Push auf `main` veröffentlicht nach erfolgreichem Build automatisch ein Vorab-Release `build-<Laufnummer>` mit App-ZIP und SHA-256-Prüfsumme.
- Ein Tag `v<Version>` veröffentlicht ein reguläres Release. Der Tag muss exakt zur Version in `Resources/TrainerConfig.json` passen, beispielsweise `v0.2.0`.
- Pull Requests bauen und testen ohne Veröffentlichung. Der Workflow kann außerdem manuell gestartet werden.
- Es werden keine Apple-Zertifikate oder persönlichen Tokens benötigt. Nur der Release-Job erhält Schreibrechte über den eingebauten `GITHUB_TOKEN`. Fehlgeschlagene Builds werden nicht veröffentlicht.

Lokal erzeugt `./script/package_release.sh` nach einem erfolgreichen Build das geprüfte ZIP unter `Release` im separaten Buildordner. `MT_TRAINER_BUILD_DIR` kann für beide Skripte denselben anderen Buildordner außerhalb des Codes festlegen.

## Adapter

`Sources/NMSAdapter.m` enthält die Spiele-Anbindung. Sie prüft die UUID vor Engine-Zugriffen, löst skalare Felder über die nativen Klassenmetadaten auf und arbeitet nach dem tatsächlichen `MetalKitApplication -update` auf dessen Thread. Die Originalmethode wird zuerst ausgeführt; Spielcode-Seiten werden nicht gepatcht. Globale Schalter und Faktoren erhalten einen einmaligen Ursprungswert und werden nur zurückgenommen, solange der aktuelle Wert noch dem eigenen zuletzt geschriebenen Wert entspricht.

Die Währungsfunktionen arbeiten auf dem in der Application-Allokation eingebetteten PlayerState. APPVIEW, aktuelle Save-UID und die nativen Sitzungen werden vor einer Aktion neu geprüft. Es gibt keine Speicher-Suche, keine fremden Spieladressen, keine Save-Dateibearbeitung und keine Neusignierung des Originalspiels.

## Herkunft

Die wiederverwendbaren Overlay-/Hotkey-Bausteine stammen aus [darkuser89/Dead-Island-2-MAS-Steam-Trainer](https://github.com/darkuser89/Dead-Island-2-MAS-Steam-Trainer). Anpassung für No Man’s Sky: 31.10.2026. GPL-3.0-only, siehe [LICENSE](LICENSE).
