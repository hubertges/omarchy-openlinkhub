# omarchy-openlinkhub 󰌢 󱐋

> **Oficjalny dodatek do paska zadań Omarchy (Hyprland / Quickshell) zintegrowany z API OpenLinkHub (Corsair iCUE Link, Commander Pro, RM850i, Dominator Titanium, Hydro AIO itp.).**

![Omarchy OpenLinkHub](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)
![OpenLinkHub](https://img.shields.io/badge/OpenLinkHub-0.9.1+-success)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🇵🇱 Opis w języku polskim

**`omarchy-openlinkhub`** to w pełni zintegrowana wtyczka status baru dla dystrybucji **Omarchy** (opartej na Hyprland i Quickshell). Umożliwia ciągłe monitorowanie kluczowych parametrów chłodzenia cieczą, zasilacza i podzespołów bezpośrednio na pasku zadań oraz błyskawiczne sterowanie oświetleniem RGB i profilami wentylatorów z poziomu eleganckiego wysuwanego panelu.

### 🌟 Główne Funkcje

1. **Wybieralny status na pasku zadań (Bar Metric)**:
   - 󰌢 **Temperatura cieczy (Coolant / AIO)** – np. `󰌢 38.5°`
   - 󱐋 **Pobór mocy zasilacza (PSU Watts)** – np. `󱐋 182W`
   - 󰍛 **Temperatura procesora (CPU Temp)** – np. `󰍛 53°`
   - 󰢮 **Temperatura karty graficznej (GPU Temp)** – np. `󰢮 52°`
   - 󰘚 **Temperatura pamięci RAM (Dominator Titanium)** – np. `󰘚 47°`
   - 󰈐 **Obroty pompy AIO (Pump RPM)** – np. `󰈐 1850`
   - 󰠝 **Maksymalne obroty wentylatorów (Fan RPM)** – np. `󰠝 965`
   - 󰏈 **Temperatura VRM zasilacza (PSU VRM)** – np. `󰏈 44.5°`
   - *Szybkie przełączanie:* **Kliknięcie prawym przyciskiem myszy** na ikonie paska natychmiast przełącza kolejny tryb wyświetlania!

2. **Wybór predefiniowanych trybów oświetlenia RGB**:
   - Dostępne presety: **Wave (Fala)**, **Rainbow (Tęcza)**, **Spiral Rainbow (Spirala)**, **Color Pulse (Puls)**, **Static (Jednolity)**, **Water Color (Akwarela)**, **Storm (Burza)**, **Rotator**, **Spinner**, **Migotanie (Flickering)**, **Color Warp**, **Deszcz (Rain)**, **Wizjer (Visor)** oraz **Wyłączone (Off)**.
   - Obsługa trybu **RGB Cluster** (synchronizacja wszystkich urządzeń) oraz indywidualnych kontrolerów.
   - Płynny suwak regulacji jasności podświetlenia (0% – 100%).

3. **Wybór predefiniowanych profili wentylatorów**:
   - Dostępne profile: **Quiet (Cichy)**, **Balanced (Zrównoważony)**, **Performance (Wydajny)**, **Extreme (Maksymalny)**.
   - Jedno kliknięcie (lub klawisze numeryczne `1`-`4` w panelu) aplikuje profil prędkości do wszystkich kontrolerów (iCUE LINK System Hub, Commander Pro itp.).

4. **Bogaty panel szczegółów sprzętu (Hardware Overview)**:
   - **Chłodzenie cieczą**: bieżąca temperatura cieczy, obroty pompy i status AIO.
   - **Zasilacz (PSU)**: sumaryczna moc (W), pomiary linii 12V (W, V, A), 5V, 3.3V oraz temperatury VRM i zasilacza.
   - **Temperatury podzespołów**: CPU, GPU, RAM oraz sondy temperatur.
   - **Wentylatory**: lista wszystkich podłączonych wentylatorów z obrotami RPM i przypisanymi profilami.

5. **Sterowanie i nawigacja klawiaturą**:
   - `Left Click`: Otwórz / zamknij panel.
   - `Right Click`: Przełącz wyświetlany status na pasku.
   - `Middle Click` / `R`: Odśwież dane z OpenLinkHub.
   - `1`, `2`, `3`, `4`: Szybki wybór profilu wentylatorów (Quiet, Balanced, Performance, Extreme).
   - `Esc`: Zamknij panel.
   - `Tab`: Nawigacja między panelami paska.

6. **Narzędzie CLI (`openlinkhub-ctl`)**:
   - Samodzielny skrypt CLI do integracji z terminalem, skrótami Hyprland lub skryptami automatyzacji.

---

## 🇬🇧 English Description

**`omarchy-openlinkhub`** is a native Omarchy status bar widget and control popout for systems running **OpenLinkHub** (supporting Corsair iCUE Link Hubs, Commander Pro, RMi series power supplies, Dominator Titanium memory, Hydro series AIO coolers, etc.).

---

## 📦 Instalacja (Installation)

### 1. Klonowanie i instalacja automatyczna

```bash
cd ~/Projects/omarchy-openlinkhub
./install.sh
```

Skrypt:
1. Kopiuje dodatek do `~/.config/omarchy/plugins/hubi.openlinkhub`
2. Przeprowadza walidację manifestu przez `omarchy plugin validate`
3. Dodaje widget do konfiguracji paska `~/.config/omarchy/shell.json`
4. Odświeża wtyczki w działającym środowisku `omarchy-shell`

### 2. Ręczna instalacja w Omarchy

Jeśli wolisz dodać dodatek manualnie:
```bash
# Skopiuj pliki do katalogu wtyczek
mkdir -p ~/.config/omarchy/plugins/hubi.openlinkhub
cp -r manifest.json BarWidget.qml OpenLinkHubModel.js bin ~/.config/omarchy/plugins/hubi.openlinkhub/

# Zwaliduj strukturę dodatku
omarchy plugin validate ~/.config/omarchy/plugins/hubi.openlinkhub/

# Dodaj do paska zadań (sekcja right)
omarchy bar put hubi.openlinkhub --section right
```

---

## ⚙️ Konfiguracja w `~/.config/omarchy/shell.json`

Możesz skonfigurować domyślny status wyświetlany na pasku oraz adres API w pliku `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "hubi.openlinkhub",
          "displayMetric": "liquid_temp",
          "apiUrl": "http://localhost:27003",
          "pollInterval": 2000
        }
      ]
    }
  }
}
```

### Opcje konfiguracji:

| Opcja | Typ | Domyślna wartość | Opis |
|---|---|---|---|
| `displayMetric` | string | `"liquid_temp"` | Domyślny status na pasku: `liquid_temp`, `psu_power`, `cpu_temp`, `gpu_temp`, `ram_temp`, `pump_rpm`, `fan_rpm`, `psu_vrm_temp` |
| `apiUrl` | string | `"http://localhost:27003"` | Adres URL lokalnej instancji OpenLinkHub API |
| `pollInterval` | number | `2000` | Interwał odpytywania API w milisekundach (domyślnie 2s) |

---

## 💻 Użycie CLI (`openlinkhub-ctl`)

Narzędzie `openlinkhub-ctl` pozwala na sterowanie i odczyt parametrów z poziomu terminala lub skrótów klawiszowych Hyprland:

```bash
# Pełny raport o stanie sprzętu
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl status

# Pobranie pojedynczej wartości (np. do skryptów)
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get liquid      # np. 38.5
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get psu         # np. 182
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get pump        # np. 1850

# Zmiana profilu wentylatorów (Quiet / Balanced / Performance / Extreme)
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl fan Quiet
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl fan Performance

# Zmiana trybu podświetlenia RGB (wave, rainbow, static, storm, off itp.)
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl rgb wave
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl rgb rainbow

# Zmiana jasności RGB (0 - 100)
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl brightness 50

# Zmiana wyświetlanej metryki na pasku zadań Omarchy
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl metric psu_power
```

---

## 🧪 Testy

Projekt zawiera zautomatyzowane testy integracyjne i walidacyjne:

```bash
# Walidacja manifestu wtyczki Omarchy
./tests/test_manifest.sh

# Testy komunikacji z API OpenLinkHub
python3 ./tests/test_api.py
```

---

## 📄 Licencja

Projekt udostępniony na licencji **MIT** — szczegóły w pliku [LICENSE](LICENSE).
Copyright (c) 2026 Hubert Ges.
